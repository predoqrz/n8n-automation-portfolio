-- Tabela de log das checagens de disponibilidade (workflow 02).
--
-- Cada checagem vira uma linha, mesmo quando o serviço está de pé. É o histórico
-- completo que permite calcular % de disponibilidade depois, não só o log de quedas.
--
-- Executar uma vez:
--   docker cp workflows/02-monitor-disponibilidade/sql/001-disponibilidade-checks.sql n8n-postgres:/tmp/001-disponibilidade-checks.sql
--   docker exec n8n-postgres psql -U n8n -d n8n -f /tmp/001-disponibilidade-checks.sql

CREATE SCHEMA IF NOT EXISTS portfolio;

CREATE TABLE IF NOT EXISTS portfolio.disponibilidade_checks (
    id                BIGSERIAL   PRIMARY KEY,
    servico           TEXT        NOT NULL,
    url               TEXT        NOT NULL,
    ok                BOOLEAN     NOT NULL,
    status_http       INTEGER,
    tempo_resposta_ms INTEGER,
    motivo            TEXT,
    verificado_em     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Usado pela consulta "qual foi a última checagem deste serviço", que roda a cada
-- 5 minutos, e pela agregação do relatório diário. Sem esse índice, as duas
-- consultas fazem varredura completa da tabela conforme ela cresce.
CREATE INDEX IF NOT EXISTS disponibilidade_checks_servico_verificado_idx
    ON portfolio.disponibilidade_checks (servico, verificado_em DESC);
