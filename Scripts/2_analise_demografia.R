# ==============================================================================
# 1. PACOTES E CONEXÃO
# ==============================================================================
library(DBI)
library(RPostgres)
library(eurostat)
library(dplyr)
library(stringr)
library(countrycode)

clean_eurostat_cache()

con <- dbConnect(
  RPostgres::Postgres(),
  dbname   = "PROJETO_BANCO_DEMOGRAFIA_V4",
  host     = "localhost",
  port     = 5432,
  user     = "postgres",
  password = "########"
)

# ==============================================================================
# 2. LIMPEZA DAS TABELAS FATO
# ==============================================================================
dbExecute(con, "
TRUNCATE TABLE 
fato_populacao, fato_nascimentos, fato_obitos, fato_migracao 
RESTART IDENTITY CASCADE;
")

# ==============================================================================
# 3. EXTRAÇÃO
# ==============================================================================
pop   <- get_eurostat("demo_pjan", time_format = "num")
death <- get_eurostat("demo_magec", time_format = "num")
birth <- get_eurostat("demo_fasec", time_format = "num")
raw_imig <- get_eurostat("migr_imm1ctz", time_format = "num")
raw_emig <- get_eurostat("migr_emi1ctz", time_format = "num")

filter_country <- function(df) df %>% filter(nchar(geo) == 2)

pop   <- filter_country(pop)
death <- filter_country(death)
birth <- filter_country(birth)
raw_imig <- filter_country(raw_imig)
raw_emig <- filter_country(raw_emig)

# ==============================================================================
# 4. PADRONIZAÇÃO GEO
# ==============================================================================
fix_geo <- function(df) {
  df %>%
    mutate(
      geo = case_when(
        geo == "UK" ~ "GB",
        geo == "EL" ~ "GR",
        TRUE ~ geo
      )
    )
}

pop   <- fix_geo(pop)
death <- fix_geo(death)
birth <- fix_geo(birth)
raw_imig <- fix_geo(raw_imig)
raw_emig <- fix_geo(raw_emig)

# ==============================================================================
# 5. LIMPEZA
# ==============================================================================
clean_data <- function(df) {
  col_time  <- if ("TIME_PERIOD" %in% names(df)) "TIME_PERIOD" else "time"
  col_value <- if ("OBS_VALUE" %in% names(df)) "OBS_VALUE" else "values"
  
  df %>%
    rename(year = !!sym(col_time), value = !!sym(col_value)) %>%
    mutate(
      age = case_when(
        age == "Y_OPEN" ~ 100,
        age == "Y_LT1" ~ 0,
        str_detect(age, "^Y[0-9]+$") ~ as.numeric(str_remove(age, "Y")),
        str_detect(age, "Y_GE") ~ as.numeric(str_extract(age, "[0-9]+")),
        TRUE ~ NA_real_
      ),
      sex = ifelse(sex %in% c("M","F","T"), sex, "T")
    ) %>%
    filter(!is.na(value), !is.na(age))
}

pop_clean   <- clean_data(pop)
death_clean <- clean_data(death)
birth_clean <- clean_data(birth)

# ==============================================================================
# 6. DIMENSÃO PAÍS
# ==============================================================================
countries <- bind_rows(
  pop_clean %>% select(geo),
  death_clean %>% select(geo),
  birth_clean %>% select(geo),
  raw_imig %>% select(geo),
  raw_emig %>% select(geo)
) %>%
  distinct() %>%
  mutate(
    nome   = countrycode(geo, "iso2c", "country.name"),
    regiao = countrycode(geo, "iso2c", "region")
  ) %>%
  mutate(
    nome   = ifelse(is.na(nome), geo, nome),
    regiao = ifelse(is.na(regiao), "Desconhecido", regiao)
  )

dbWriteTable(con, "tmp_pais", countries, overwrite = TRUE)

dbExecute(con, "
UPDATE dim_pais d
SET nome = t.nome, regiao = t.regiao
FROM tmp_pais t
WHERE d.codigo_geo = t.geo;
")

dbExecute(con, "
INSERT INTO dim_pais (codigo_geo, nome, regiao)
SELECT t.geo, t.nome, t.regiao
FROM tmp_pais t
LEFT JOIN dim_pais d ON d.codigo_geo = t.geo
WHERE d.codigo_geo IS NULL;
")

dbExecute(con, "DROP TABLE tmp_pais;")

# ==============================================================================
# 7. DIMENSÃO IDADE
# ==============================================================================
ages <- bind_rows(
  pop_clean %>% select(age),
  death_clean %>% select(age),
  birth_clean %>% select(age)
) %>%
  distinct() %>%
  mutate(
    limite_inferior = age,
    limite_superior = age,
    faixa_etaria = case_when(
      age <= 14 ~ "0-14",
      age <= 24 ~ "15-24",
      age <= 64 ~ "25-64",
      TRUE ~ "65+"
    )
  )

dbWriteTable(con, "tmp_idade", ages, overwrite = TRUE)

dbExecute(con, "
UPDATE dim_idade d
SET 
  faixa_etaria = t.faixa_etaria,
  limite_inferior = t.limite_inferior,
  limite_superior = t.limite_superior
FROM tmp_idade t
WHERE d.idade = t.age;
")

dbExecute(con, "
INSERT INTO dim_idade (idade, faixa_etaria, limite_inferior, limite_superior)
SELECT t.age, t.faixa_etaria, t.limite_inferior, t.limite_superior
FROM tmp_idade t
LEFT JOIN dim_idade d ON d.idade = t.age
WHERE d.idade IS NULL;
")

dbExecute(con, "DROP TABLE tmp_idade;")

# ==============================================================================
# 8. DIMENSÃO TEMPO
# ==============================================================================
time_all <- bind_rows(
  pop_clean %>% select(year),
  death_clean %>% select(year),
  birth_clean %>% select(year)
) %>%
  mutate(year = as.numeric(year)) %>%
  filter(!is.na(year)) %>%
  distinct()

dim_tempo_db <- dbReadTable(con, "dim_tempo")

time_new <- time_all %>%
  anti_join(dim_tempo_db, by = c("year" = "ano")) %>%
  mutate(
    ano = as.integer(year),
    data_referencia = as.Date(sprintf("%d-01-01", ano))
  ) %>%
  select(ano, data_referencia)

if (nrow(time_new) > 0) {
  dbWriteTable(con, "dim_tempo", time_new, append = TRUE)
}

# ==============================================================================
# 9. RELOAD DIMENSÕES
# ==============================================================================
dim_pais  <- dbReadTable(con, "dim_pais")
dim_tempo <- dbReadTable(con, "dim_tempo")
dim_sexo  <- dbReadTable(con, "dim_sexo")
dim_idade <- dbReadTable(con, "dim_idade")

safe_join <- function(df, dim, by) {
  df %>% inner_join(dim, by = by)
}

# ==============================================================================
# 10. POPULAÇÃO
# ==============================================================================
pop_final <- pop_clean %>%
  group_by(geo, year, sex, age) %>%
  summarise(value = sum(value), .groups = "drop") %>%
  safe_join(dim_pais, c("geo" = "codigo_geo")) %>%
  safe_join(dim_tempo, c("year" = "ano")) %>%
  safe_join(dim_sexo, c("sex" = "codigo_sexo")) %>%
  safe_join(dim_idade, c("age" = "idade")) %>%
  transmute(id_pais, id_tempo, id_sexo, id_idade, populacao = value)

dbWriteTable(con, "fato_populacao", pop_final, append = TRUE)

# ==============================================================================
# 11. ÓBITOS
# ==============================================================================
death_final <- death_clean %>%
  group_by(geo, year, sex, age) %>%
  summarise(value = sum(value), .groups = "drop") %>%
  safe_join(dim_pais, c("geo" = "codigo_geo")) %>%
  safe_join(dim_tempo, c("year" = "ano")) %>%
  safe_join(dim_sexo, c("sex" = "codigo_sexo")) %>%
  safe_join(dim_idade, c("age" = "idade")) %>%
  transmute(id_pais, id_tempo, id_sexo, id_idade, obitos = value)

dbWriteTable(con, "fato_obitos", death_final, append = TRUE)

# ==============================================================================
# 12. NASCIMENTOS
# ==============================================================================
birth_final <- birth_clean %>%
  group_by(geo, year, sex, age) %>%
  summarise(value = sum(value), .groups = "drop") %>%
  safe_join(dim_pais, c("geo" = "codigo_geo")) %>%
  safe_join(dim_tempo, c("year" = "ano")) %>%
  safe_join(dim_sexo, c("sex" = "codigo_sexo")) %>%
  safe_join(dim_idade, c("age" = "idade")) %>%
  transmute(
    id_pais, id_tempo, id_sexo,
    id_idade_mae = id_idade,
    nascimentos = value
  )

dbWriteTable(con, "fato_nascimentos", birth_final, append = TRUE)

# ==============================================================================
# 13. MIGRAÇÃO CORRIGIDA (CONSOLIDAÇÃO FINAL)
# ==============================================================================

process_migr <- function(df, tipo) {
  col_ctz <- intersect(names(df), c("citizen", "ctz"))[1]
  col_t   <- if ("TIME_PERIOD" %in% names(df)) "TIME_PERIOD" else "time"
  col_v   <- if ("OBS_VALUE" %in% names(df)) "OBS_VALUE" else "values"
  
  df_filtered <- df %>%
    filter(age == "TOTAL", sex == "T")
  
  if (!is.na(col_ctz)) {
    df_filtered <- df_filtered %>% filter(!!sym(col_ctz) == "TOTAL")
  }
  
  if ("csq" %in% names(df)) {
    df_filtered <- df_filtered %>% filter(csq == "TOTAL")
  }
  
  df_filtered %>%
    rename(year = !!sym(col_t), value = !!sym(col_v)) %>%
    mutate(tipo_fluxo = tipo) %>%
    group_by(geo, year, tipo_fluxo, sex) %>%
    summarise(value = first(value), .groups = "drop") 
}

# 1. Extrair e Unir
imig <- process_migr(raw_imig, "entrada")
emig <- process_migr(raw_emig, "saida")

# 2. LIMPEZA DE ANOS E NAs (IMPORTANTE: Fazer antes do join)
migration_combined <- bind_rows(imig, emig) %>% 
  filter(!is.na(value), year < 2024) 

# 3. Transformar IDs e Preparar para o Banco
migration_final <- migration_combined %>%
  safe_join(dim_pais, c("geo" = "codigo_geo")) %>%
  safe_join(dim_tempo, c("year" = "ano")) %>%
  safe_join(dim_sexo, c("sex" = "codigo_sexo")) %>%
  mutate(id_idade = 1) %>% # ID correspondente ao grão total no seu banco
  select(id_pais, id_tempo, tipo_fluxo, id_sexo, id_idade, migrantes = value)

# 4. Inserir no Banco
dbWriteTable(con, "fato_migracao", migration_final, append = TRUE)

# ==================================================================  ============
# FINAL
# ==============================================================================
cat("\n===== DIMENSÕES =====\n")
print(head(dbReadTable(con, "dim_pais")))
print(head(dbReadTable(con, "dim_tempo")))
print(head(dbReadTable(con, "dim_sexo")))
print(head(dbReadTable(con, "dim_idade")))

cat("\n===== FATOS =====\n")
print(head(dbReadTable(con, "fato_populacao")))
print(head(dbReadTable(con, "fato_nascimentos")))
print(head(dbReadTable(con, "fato_obitos")))
print(head(dbReadTable(con, "fato_migracao")))

dbDisconnect(con)

cat("\nETL FINALIZADO COM SUCESSO 🚀\n")
