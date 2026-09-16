-- Tabela de log da triagem de chamados (workflow 01).
--
-- Fica em um schema separado (`portfolio`) dentro do mesmo banco do n8n para não
-- se misturar com as tabelas internas do produto, que são recriadas a cada upgrade.
--
-- Executar uma vez:
--   docker exec -i n8n-postgres psql -U n8n -d n8n < 001-log-triagem.sql

CREATE SCHEMA IF NOT EXISTS portfolio;

CREATE TABLE IF NOT EXISTS portfolio.log_triagem (
    id              BIGSERIAL   PRIMARY KEY,
    mensagem_id     TEXT        NOT NULL,
    thread_id       TEXT,
    remetente       TEXT,
    assunto         TEXT,
    categoria       TEXT        NOT NULL,
    urgencia        TEXT,
    resumo          TEXT,
    confianca       NUMERIC(4,3),
    destino         TEXT        NOT NULL,
    motivo          TEXT,
    notion_page_id  TEXT,
    notion_page_url TEXT,
    processado_em   TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- Esta constraint é a garantia real de idempotência: mesmo que a label do
    -- Gmail falhe ao ser aplicada, o mesmo e-mail não vira duas páginas.
    CONSTRAINT log_triagem_mensagem_id_unico UNIQUE (mensagem_id)
);

CREATE INDEX IF NOT EXISTS log_triagem_categoria_idx
    ON portfolio.log_triagem (categoria);

CREATE INDEX IF NOT EXISTS log_triagem_processado_em_idx
    ON portfolio.log_triagem (processado_em DESC);
