-- Workflow 04 — onboarding e offboarding.
--
-- Executar uma vez:
--   docker cp workflows/04-onboarding-offboarding/sql/001-onboarding-offboarding.sql n8n-postgres:/tmp/001-onboarding-offboarding.sql
--   docker exec n8n-postgres psql -U n8n -d n8n -f /tmp/001-onboarding-offboarding.sql
--
-- Duas partes:
--   dir_*  O DIRETÓRIO SIMULADO. Num ambiente real, isto seria o Google Workspace / Entra ID
--          (contas) e cada sistema (acessos). Aqui é simulado para o portfólio ter custo zero;
--          o que o workflow demonstra é a orquestração em volta, não a API de um fornecedor.
--   rh_*   O CONTROLE DO PROCESSO: matriz de acessos, solicitações, aprovações e o log de
--          cada etapa — que é o que permite retomar um processo interrompido no meio.

CREATE SCHEMA IF NOT EXISTS portfolio;

-- ============================================================ diretório simulado

-- Sistemas que podem receber acesso. "disponivel = false" simula um sistema fora do ar,
-- para testar o rollback da admissão.
CREATE TABLE IF NOT EXISTS portfolio.dir_sistemas (
    codigo      TEXT    PRIMARY KEY,
    nome        TEXT    NOT NULL,
    disponivel  BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS portfolio.dir_contas (
    login             TEXT        PRIMARY KEY,
    nome              TEXT        NOT NULL,
    email_corporativo TEXT        NOT NULL UNIQUE,
    perfil            TEXT        NOT NULL,
    status            TEXT        NOT NULL DEFAULT 'ativa' CHECK (status IN ('ativa', 'arquivada')),
    criada_em         TIMESTAMPTZ NOT NULL DEFAULT now(),
    arquivada_em      TIMESTAMPTZ
);

-- Estado atual de cada acesso. revogado_em preenchido = acesso removido (o histórico fica).
CREATE TABLE IF NOT EXISTS portfolio.dir_acessos (
    login         TEXT        NOT NULL REFERENCES portfolio.dir_contas (login),
    sistema       TEXT        NOT NULL REFERENCES portfolio.dir_sistemas (codigo),
    concedido_em  TIMESTAMPTZ NOT NULL DEFAULT now(),
    revogado_em   TIMESTAMPTZ,
    PRIMARY KEY (login, sistema)
);

-- ============================================================ controle do processo

-- Matriz de acesso por perfil: o "quem recebe o quê" sai daqui, não de dentro do workflow.
-- Mudar a política de acesso = mudar linhas desta tabela, sem tocar no n8n.
CREATE TABLE IF NOT EXISTS portfolio.rh_matriz_acessos (
    perfil   TEXT NOT NULL,
    sistema  TEXT NOT NULL REFERENCES portfolio.dir_sistemas (codigo),
    PRIMARY KEY (perfil, sistema)
);

CREATE TABLE IF NOT EXISTS portfolio.rh_solicitacoes (
    id              BIGSERIAL   PRIMARY KEY,
    tipo            TEXT        NOT NULL CHECK (tipo IN ('admissao', 'desligamento')),
    nome            TEXT        NOT NULL,
    login           TEXT        NOT NULL,
    perfil          TEXT,
    gestor          TEXT        NOT NULL,
    data_efetiva    DATE        NOT NULL,
    status          TEXT        NOT NULL DEFAULT 'recebida' CHECK (status IN (
                        'recebida', 'aguardando_aprovacao', 'recusada',
                        'em_execucao', 'interrompida', 'concluida', 'falhou_revertida')),
    aprovado_por    TEXT,
    decidido_em     TIMESTAMPTZ,
    motivo          TEXT,         -- por que o gestor aprovou ou recusou
    erro            TEXT,         -- falha técnica da última tentativa (vazio quando concluiu)
    criada_em       TIMESTAMPTZ NOT NULL DEFAULT now(),
    atualizada_em   TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- Idempotência: o mesmo formulário enviado duas vezes não abre dois processos.
    CONSTRAINT rh_solicitacoes_unica UNIQUE (tipo, login, data_efetiva)
);

-- Uma linha por etapa executada. É a base da RETOMADA: antes de executar uma etapa, o
-- workflow confere se ela já está como 'concluida' para esta solicitação e, se estiver,
-- pula. Também é o log de auditoria — quem foi desligado, quando, e o que foi revogado.
CREATE TABLE IF NOT EXISTS portfolio.rh_etapas (
    solicitacao_id  BIGINT      NOT NULL REFERENCES portfolio.rh_solicitacoes (id),
    etapa           TEXT        NOT NULL,
    status          TEXT        NOT NULL CHECK (status IN ('concluida', 'falhou', 'revertida')),
    detalhe         TEXT,
    registrado_em   TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (solicitacao_id, etapa)
);

-- ============================================================ dados iniciais

INSERT INTO portfolio.dir_sistemas (codigo, nome) VALUES
    ('email',       'E-mail corporativo'),
    ('vpn',         'VPN'),
    ('erp',         'ERP (financeiro e estoque)'),
    ('crm',         'CRM (vendas)'),
    ('repositorio', 'Repositório de código'),
    ('pdv',         'Sistema de caixa (PDV)')
ON CONFLICT (codigo) DO NOTHING;

-- Os perfis são os mesmos do documento de equipamentos da base de conhecimento (workflow 03).
INSERT INTO portfolio.rh_matriz_acessos (perfil, sistema) VALUES
    ('Administrativo',          'email'),
    ('Administrativo',          'vpn'),
    ('Administrativo',          'erp'),
    ('Administrativo',          'crm'),
    ('Desenvolvimento e dados', 'email'),
    ('Desenvolvimento e dados', 'vpn'),
    ('Desenvolvimento e dados', 'repositorio'),
    ('Atendimento em loja',     'email'),
    ('Atendimento em loja',     'pdv')
ON CONFLICT DO NOTHING;

-- ============================================================ a "API" simulada
--
-- Cada função faz o papel de uma chamada à API de um sistema real (Google, ERP...). Como
-- uma API, ela conclui a ação ou falha com erro — e falha de verdade quando o sistema
-- está marcado como indisponível. É o que permite testar rollback e retomada.
-- Todas são idempotentes: chamar duas vezes não duplica nada nem dá erro.

CREATE OR REPLACE FUNCTION portfolio.dir_criar_conta(p_login TEXT, p_nome TEXT, p_perfil TEXT)
RETURNS TEXT LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO portfolio.dir_contas (login, nome, email_corporativo, perfil)
    VALUES (p_login, p_nome, p_login || '@grupoaurora.exemplo', p_perfil)
    ON CONFLICT (login) DO UPDATE
       SET status = 'ativa', arquivada_em = NULL, perfil = EXCLUDED.perfil;
    RETURN p_login || '@grupoaurora.exemplo';
END $$;

CREATE OR REPLACE FUNCTION portfolio.dir_conceder_acesso(p_login TEXT, p_sistema TEXT)
RETURNS TEXT LANGUAGE plpgsql AS $$
BEGIN
    IF NOT (SELECT disponivel FROM portfolio.dir_sistemas WHERE codigo = p_sistema) THEN
        RAISE EXCEPTION 'Sistema % indisponível (simulado): acesso de % não concedido', p_sistema, p_login;
    END IF;
    INSERT INTO portfolio.dir_acessos (login, sistema)
    VALUES (p_login, p_sistema)
    ON CONFLICT (login, sistema) DO UPDATE SET concedido_em = now(), revogado_em = NULL;
    RETURN 'concedido';
END $$;

CREATE OR REPLACE FUNCTION portfolio.dir_revogar_acesso(p_login TEXT, p_sistema TEXT)
RETURNS TEXT LANGUAGE plpgsql AS $$
BEGIN
    IF NOT (SELECT disponivel FROM portfolio.dir_sistemas WHERE codigo = p_sistema) THEN
        RAISE EXCEPTION 'Sistema % indisponível (simulado): acesso de % não revogado', p_sistema, p_login;
    END IF;
    UPDATE portfolio.dir_acessos SET revogado_em = now()
     WHERE login = p_login AND sistema = p_sistema AND revogado_em IS NULL;
    RETURN 'revogado';
END $$;

CREATE OR REPLACE FUNCTION portfolio.dir_arquivar_conta(p_login TEXT)
RETURNS TEXT LANGUAGE plpgsql AS $$
BEGIN
    UPDATE portfolio.dir_contas SET status = 'arquivada', arquivada_em = now()
     WHERE login = p_login AND status = 'ativa';
    RETURN 'arquivada';
END $$;

-- ============================================================ retomada e compensação

-- Tabela criada antes da coluna de erro? Acrescenta.
ALTER TABLE portfolio.rh_solicitacoes ADD COLUMN IF NOT EXISTS erro TEXT;

-- Já existe uma tabela criada sem o status 'interrompida'? Atualiza a regra.
ALTER TABLE portfolio.rh_solicitacoes DROP CONSTRAINT IF EXISTS rh_solicitacoes_status_check;
ALTER TABLE portfolio.rh_solicitacoes ADD CONSTRAINT rh_solicitacoes_status_check CHECK (status IN (
    'recebida', 'aguardando_aprovacao', 'recusada',
    'em_execucao', 'interrompida', 'concluida', 'falhou_revertida'));

-- "Esta etapa já foi concluída para esta solicitação?" — a base da retomada.
CREATE OR REPLACE FUNCTION portfolio.rh_etapa_feita(p_sol BIGINT, p_etapa TEXT)
RETURNS BOOLEAN LANGUAGE sql AS $$
    SELECT EXISTS (SELECT 1 FROM portfolio.rh_etapas
                    WHERE solicitacao_id = p_sol AND etapa = p_etapa AND status = 'concluida');
$$;

-- Grava a etapa no log e devolve o detalhe. É chamada com o RESULTADO da ação como
-- argumento: se a ação falhar, a função nunca roda e a etapa não fica marcada como feita.
CREATE OR REPLACE FUNCTION portfolio.rh_registrar_etapa(p_sol BIGINT, p_etapa TEXT, p_status TEXT, p_detalhe TEXT)
RETURNS TEXT LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO portfolio.rh_etapas (solicitacao_id, etapa, status, detalhe)
    VALUES (p_sol, p_etapa, p_status, p_detalhe)
    ON CONFLICT (solicitacao_id, etapa) DO UPDATE
       SET status = EXCLUDED.status, detalhe = EXCLUDED.detalhe, registrado_em = now();
    RETURN p_detalhe;
END $$;

-- COMPENSAÇÃO da admissão (rollback no estilo "saga"): desfaz, uma a uma, as etapas que
-- já tinham sido concluídas nesta solicitação — revoga os acessos concedidos e arquiva a
-- conta criada. APIs reais não têm transação entre sistemas; a reversão é feita por ações
-- contrárias, e cada uma fica registrada como 'revertida'.
CREATE OR REPLACE FUNCTION portfolio.rh_reverter_admissao(p_sol BIGINT, p_login TEXT, p_motivo TEXT)
RETURNS TEXT LANGUAGE plpgsql AS $$
DECLARE
    e RECORD;
    revertidos TEXT[] := '{}';
BEGIN
    FOR e IN SELECT etapa FROM portfolio.rh_etapas
              WHERE solicitacao_id = p_sol AND status = 'concluida' AND etapa LIKE 'acesso:%'
    LOOP
        PERFORM portfolio.dir_revogar_acesso(p_login, substr(e.etapa, 8));
        UPDATE portfolio.rh_etapas SET status = 'revertida', registrado_em = now()
         WHERE solicitacao_id = p_sol AND etapa = e.etapa;
        revertidos := revertidos || substr(e.etapa, 8);
    END LOOP;
    IF portfolio.rh_etapa_feita(p_sol, 'criar_conta') THEN
        PERFORM portfolio.dir_arquivar_conta(p_login);
        UPDATE portfolio.rh_etapas SET status = 'revertida', registrado_em = now()
         WHERE solicitacao_id = p_sol AND etapa = 'criar_conta';
        revertidos := revertidos || 'conta'::TEXT;
    END IF;
    UPDATE portfolio.rh_solicitacoes
       SET status = 'falhou_revertida', erro = p_motivo, atualizada_em = now()
     WHERE id = p_sol;
    RETURN coalesce(array_to_string(revertidos, ', '), '');
END $$;
