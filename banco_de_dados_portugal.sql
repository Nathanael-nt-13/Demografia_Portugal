CREATE TABLE dim_pais (
    id_pais SERIAL PRIMARY KEY,
    codigo_geo VARCHAR(10) UNIQUE NOT NULL,
    nome TEXT,
    regiao TEXT,
    valido_de DATE,
    valido_ate DATE
);

CREATE TABLE dim_tempo (
    id_tempo SERIAL PRIMARY KEY,
    ano INT UNIQUE NOT NULL,
    data_referencia DATE
);

CREATE TABLE dim_sexo (
    id_sexo SERIAL PRIMARY KEY,
    codigo_sexo VARCHAR(5) UNIQUE NOT NULL,
    descricao TEXT
);

CREATE TABLE dim_idade (
    id_idade SERIAL PRIMARY KEY,
    idade INT,
    faixa_etaria VARCHAR(20),
    limite_inferior INT,
    limite_superior INT,

    CONSTRAINT chk_faixa_idade CHECK (
        (idade IS NOT NULL AND limite_inferior = idade AND limite_superior = idade)
        OR (limite_inferior <= limite_superior)
    )
);

CREATE TABLE fato_populacao (
    id_pais INT NOT NULL REFERENCES dim_pais(id_pais),
    id_tempo INT NOT NULL REFERENCES dim_tempo(id_tempo),
    id_sexo INT NOT NULL REFERENCES dim_sexo(id_sexo),
    id_idade INT NOT NULL REFERENCES dim_idade(id_idade),

    populacao BIGINT NOT NULL CHECK (populacao >= 0),
    fonte TEXT,
    data_carga TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (id_pais, id_tempo, id_sexo, id_idade)
);

CREATE TABLE fato_nascimentos (
    id_pais INT NOT NULL REFERENCES dim_pais(id_pais),
    id_tempo INT NOT NULL REFERENCES dim_tempo(id_tempo),
    id_sexo INT NOT NULL REFERENCES dim_sexo(id_sexo),
    id_idade_mae INT NOT NULL REFERENCES dim_idade(id_idade),

    nascimentos BIGINT NOT NULL CHECK (nascimentos >= 0),
    fonte TEXT,
    data_carga TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (id_pais, id_tempo, id_sexo, id_idade_mae)
);

CREATE TABLE fato_obitos (
    id_pais INT NOT NULL REFERENCES dim_pais(id_pais),
    id_tempo INT NOT NULL REFERENCES dim_tempo(id_tempo),
    id_sexo INT NOT NULL REFERENCES dim_sexo(id_sexo),
    id_idade INT NOT NULL REFERENCES dim_idade(id_idade),

    obitos BIGINT NOT NULL CHECK (obitos >= 0),
    fonte TEXT,
    data_carga TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (id_pais, id_tempo, id_sexo, id_idade)
);

CREATE TABLE fato_migracao (
    id_pais INT NOT NULL REFERENCES dim_pais(id_pais),
    id_tempo INT NOT NULL REFERENCES dim_tempo(id_tempo),
    tipo_fluxo VARCHAR(10) CHECK (tipo_fluxo IN ('entrada','saida')),
    id_sexo INT NOT NULL REFERENCES dim_sexo(id_sexo),
    id_idade INT NOT NULL REFERENCES dim_idade(id_idade),

    migrantes BIGINT NOT NULL CHECK (migrantes >= 0),
    fonte TEXT,
    data_carga TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (id_pais, id_tempo, tipo_fluxo, id_sexo, id_idade)
);

CREATE INDEX idx_populacao_pais_tempo ON fato_populacao(id_pais, id_tempo);
CREATE INDEX idx_nascimentos_pais_tempo ON fato_nascimentos(id_pais, id_tempo);
CREATE INDEX idx_obitos_pais_tempo ON fato_obitos(id_pais, id_tempo);
CREATE INDEX idx_migracao_pais_tempo ON fato_migracao(id_pais, id_tempo);

CREATE INDEX idx_populacao_idade ON fato_populacao(id_idade);
CREATE INDEX idx_obitos_idade ON fato_obitos(id_idade);
CREATE INDEX idx_nascimentos_idade_mae ON fato_nascimentos(id_idade_mae);

CREATE TABLE log_carga_dados (
    id_carga SERIAL PRIMARY KEY,
    nome_tabela TEXT,
    fonte TEXT,
    linhas_inseridas INT,
    linhas_falha INT,
    data_carga TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(10) CHECK (status IN ('SUCESSO','PARCIAL','FALHA'))
);

INSERT INTO dim_sexo (codigo_sexo, descricao) VALUES
('M', 'Masculino'),
('F', 'Feminino'),
('T', 'Total');

INSERT INTO dim_tempo (ano, data_referencia)
SELECT y, make_date(y,1,1)
FROM generate_series(2000, 2025) AS y;

INSERT INTO dim_idade (idade, limite_inferior, limite_superior)
SELECT i, i, i
FROM generate_series(0, 100) AS i;

ALTER TABLE dim_pais
ADD CONSTRAINT chk_codigo_geo CHECK (char_length(codigo_geo) <= 5);

-- redundante com PK, mas mantido se quiser reforçar regra explícita
ALTER TABLE fato_populacao
ADD CONSTRAINT unq_populacao UNIQUE (id_pais, id_tempo, id_sexo, id_idade);
