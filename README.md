# Banco de Dados Demográfico Europeu

## Sobre o projeto

Este projeto consiste no desenvolvimento de um banco de dados relacional para armazenar, organizar e analisar dados demográficos de países europeus. A estrutura foi desenvolvida em PostgreSQL e integrada a scripts em R para extração, transformação, carga (ETL) e análise estatística dos dados.

O projeto utiliza dados do **Eurostat** para investigar a dinâmica demográfica ao longo do tempo, considerando aspectos como população, nascimentos, óbitos e migração.

## Objetivos

- Estruturar um banco de dados relacional para informações demográficas.
- Automatizar a coleta e o tratamento de dados por meio de scripts em R.
- Integrar dados de diferentes conjuntos disponibilizados pelo Eurostat.
- Calcular indicadores demográficos e produzir visualizações.
- Facilitar análises temporais e comparações entre países.

## Tecnologias utilizadas

- **PostgreSQL:** armazenamento e gerenciamento dos dados.
- **R:** processamento, integração e análise estatística.
- **DBI e RPostgres:** conexão entre R e PostgreSQL.
- **dplyr e stringr:** transformação e limpeza dos dados.
- **eurostat:** extração de dados demográficos europeus.
- **ggplot2 e patchwork:** criação e organização de gráficos.
- **countrycode:** padronização e identificação de países.

## Estrutura do banco de dados

O banco utiliza um modelo dimensional composto por tabelas de dimensão e tabelas de fatos.

### Tabelas de dimensão

| Tabela | Descrição |
|---|---|
| `dim_pais` | Identificação e classificação dos países. |
| `dim_tempo` | Anos e datas de referência. |
| `dim_sexo` | Categorias de sexo. |
| `dim_idade` | Idades e respectivas faixas etárias. |

### Tabelas de fatos

| Tabela | Descrição |
|---|---|
| `fato_populacao` | Registros populacionais por país, ano, sexo e idade. |
| `fato_nascimentos` | Registros de nascimentos por país, ano, sexo e idade materna. |
| `fato_obitos` | Registros de óbitos por país, ano, sexo e idade. |
| `fato_migracao` | Registros de imigração e emigração. |
| `log_carga_dados` | Registro de informações sobre cargas de dados. |

O esquema utiliza chaves primárias, chaves estrangeiras, restrições de integridade e índices para organizar os registros e apoiar as consultas.

## Processo de ETL

O processo de ETL é desenvolvido em R e contempla:

1. **Extração:** obtenção de dados demográficos do Eurostat.
2. **Limpeza:** tratamento de valores ausentes, idades e variáveis.
3. **Padronização:** harmonização dos códigos geográficos e das categorias demográficas.
4. **Transformação:** associação dos registros às dimensões de país, tempo, sexo e idade.
5. **Carga:** inserção dos dados tratados nas tabelas de fatos do PostgreSQL.

## Indicadores e análises

Os scripts de análise permitem investigar:

- Evolução da população e crescimento populacional.
- Estrutura etária e razão de dependência.
- Taxa bruta de mortalidade.
- Taxa de fecundidade.
- Imigração, emigração e saldo migratório.
- Tábua de vida, sobrevivência e esperança de vida.
- Pirâmide etária.
- Diagrama de Lexis para análise de óbitos por idade e ano.

Os resultados são apresentados por meio de tabelas, gráficos e um dashboard desenvolvido em R.

## Organização sugerida dos arquivos

```text
banco-demografico-europeu/
├── README.md
├── banco_de_dados.sql
├── scripts/
│   ├── 1_etl_demografia.R
│   └── 2_analise_demografia.R
```

Os nomes dos arquivos e diretórios devem ser ajustados conforme a organização efetiva do repositório.

## Como executar

1. Instale o PostgreSQL e o R.
2. Crie o banco de dados PostgreSQL.
3. Execute o script `banco_de_dados.sql` para criar as tabelas, os índices e os registros iniciais.
4. Instale os pacotes R utilizados pelo projeto.
5. Configure os parâmetros de conexão com o banco de dados nos scripts.
6. Execute o script de ETL para importar e processar os dados.
7. Execute o script de análise para gerar os indicadores e gráficos.

**Observação:** os scripts devem ser executados na ordem adequada. A análise depende de os dados terem sido carregados corretamente no banco.

## Fonte dos dados

**Eurostat — Statistical Office of the European Union**

Os dados são obtidos de conjuntos estatísticos relacionados à população, mortalidade, nascimentos e migração.

Portal: https://ec.europa.eu/eurostat

## Finalidade acadêmica

O projeto demonstra a aplicação integrada de modelagem de bancos de dados, SQL, programação em R, processos de ETL, análise estatística e visualização de dados em um problema de demografia.

Desenvolvido como projeto de estudo e análise de dados.
