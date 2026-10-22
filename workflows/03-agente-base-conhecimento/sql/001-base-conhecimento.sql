-- Base de conhecimento do workflow 03 (RAG com pgvector).
--
-- Executar uma vez:
--   docker cp workflows/03-agente-base-conhecimento/sql/001-base-conhecimento.sql n8n-postgres:/tmp/001-base-conhecimento.sql
--   docker exec n8n-postgres psql -U n8n -d n8n -f /tmp/001-base-conhecimento.sql

CREATE EXTENSION IF NOT EXISTS vector;

-- Trechos (chunks) dos documentos, com o embedding de cada um.
--
-- Colunas no formato que o nó "Postgres PGVector Store" do n8n espera (id, text, metadata,
-- embedding). Fica no schema public porque o nó não aceita nome de tabela com schema.
-- Criada aqui, e não pelo próprio nó, por dois motivos: a dimensão do vetor fica fixa
-- (1536, a do text-embedding-3-small), o que permite o índice HNSW abaixo; e o workflow de
-- indexação pode apagar trechos antigos antes do primeiro insert sem a tabela não existir.
CREATE TABLE IF NOT EXISTS kb_chunks (
    id        UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    text      TEXT,
    metadata  JSONB,
    embedding VECTOR(1536)
);

-- Busca por similaridade (distância de cosseno, a mesma que o nó usa por padrão). Com
-- poucos documentos a busca sequencial já seria rápida; o índice existe para a base
-- crescer sem a consulta piorar.
CREATE INDEX IF NOT EXISTS kb_chunks_embedding_idx
    ON kb_chunks USING hnsw (embedding vector_cosine_ops);

-- Para apagar todos os trechos de um documento quando ele muda.
CREATE INDEX IF NOT EXISTS kb_chunks_fonte_idx
    ON kb_chunks ((metadata ->> 'fonte'));

CREATE SCHEMA IF NOT EXISTS portfolio;

-- Um "recibo" por documento indexado. O hash do conteúdo é o que torna a indexação
-- idempotente: rodar de novo sem mudar nada não gera embedding nenhum (nem custo).
CREATE TABLE IF NOT EXISTS portfolio.kb_documentos (
    arquivo      TEXT        PRIMARY KEY,
    titulo       TEXT,
    hash         TEXT        NOT NULL,
    trechos      INTEGER,
    indexado_em  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Log de cada pergunta e resposta do agente. "respondeu_da_base" = false quando o agente
-- disse que não encontrou: a lista dessas perguntas é exatamente o que falta documentar.
CREATE TABLE IF NOT EXISTS portfolio.kb_conversas (
    id                 BIGSERIAL   PRIMARY KEY,
    sessao             TEXT,
    pergunta           TEXT,
    resposta           TEXT,
    respondeu_da_base  BOOLEAN,
    registrado_em      TIMESTAMPTZ NOT NULL DEFAULT now()
);
