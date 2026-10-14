-- Contatos que o atendimento pode responder (workflow 05).
--
-- Existe porque o número conectado é o WhatsApp pessoal do autor. Sem esta
-- lista, qualquer mensagem de família ou amigo receberia resposta da IA. O
-- workflow só atende quem estiver aqui com `ativo = true` — e uma mensagem de
-- quem não está na lista não é gravada em lugar nenhum.
--
-- A coluna `humano_desde` é a passagem para humano: quando o agente decide que
-- não deve continuar sozinho, ela é preenchida e o workflow para de responder
-- àquele contato até alguém limpá-la.
--
-- Executar uma vez:
--   docker cp workflows/05-atendimento-whatsapp-crm/sql/002-atendimento-contatos.sql n8n-postgres:/tmp/002-atendimento-contatos.sql
--   docker exec n8n-postgres psql -U n8n -d n8n -f /tmp/002-atendimento-contatos.sql
--
-- Liberar um número (formato internacional, só dígitos, ex.: 5511999998888):
--   INSERT INTO portfolio.atendimento_contatos (wa_id, nome) VALUES ('5511999998888', 'Teste');
--
-- Devolver um contato ao atendimento automático depois que o humano resolver:
--   UPDATE portfolio.atendimento_contatos SET humano_desde = NULL WHERE wa_id = '5511999998888';

CREATE SCHEMA IF NOT EXISTS portfolio;

CREATE TABLE IF NOT EXISTS portfolio.atendimento_contatos (
    wa_id           TEXT        PRIMARY KEY,
    nome            TEXT,
    ativo           BOOLEAN     NOT NULL DEFAULT true,
    humano_desde    TIMESTAMPTZ,
    monday_item_id  TEXT,
    criado_em       TIMESTAMPTZ NOT NULL DEFAULT now()
);
