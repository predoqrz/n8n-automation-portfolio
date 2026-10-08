-- Log de mensagens processadas do atendimento (workflow 05).
--
-- Existe por duas razões. Primeira: webhooks podem reentregar o mesmo evento —
-- se a Evolution API não receber confirmação a tempo, ela tenta de novo, e sem
-- essa tabela o workflow responderia duas vezes à mesma mensagem. Segunda: é o
-- histórico que permite auditar o que a IA respondeu, fora do Monday.
--
-- Executar uma vez:
--   docker cp workflows/05-atendimento-whatsapp-crm/sql/001-atendimento-mensagens.sql n8n-postgres:/tmp/001-atendimento-mensagens.sql
--   docker exec n8n-postgres psql -U n8n -d n8n -f /tmp/001-atendimento-mensagens.sql

CREATE SCHEMA IF NOT EXISTS portfolio;

CREATE TABLE IF NOT EXISTS portfolio.atendimento_mensagens (
    id              BIGSERIAL   PRIMARY KEY,
    wa_message_id   TEXT        NOT NULL,
    wa_id           TEXT        NOT NULL,
    nome_contato    TEXT,
    texto_recebido  TEXT,
    intencao        TEXT,
    texto_resposta  TEXT,
    monday_item_id  TEXT,
    encaminhado     BOOLEAN     NOT NULL DEFAULT false,
    processado_em   TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- A garantia real de idempotência: mesmo que o webhook reentregue o evento,
    -- a segunda tentativa esbarra aqui em vez de gerar uma segunda resposta.
    CONSTRAINT atendimento_mensagens_wa_message_id_unico UNIQUE (wa_message_id)
);

CREATE INDEX IF NOT EXISTS atendimento_mensagens_wa_id_idx
    ON portfolio.atendimento_mensagens (wa_id, processado_em DESC);
