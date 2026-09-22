# Portfólio de Automação com n8n

Coleção de workflows de automação construídos em n8n self-hosted, cada um resolvendo um
problema real de operação de TI. O objetivo do repositório é documentar não só o fluxo
pronto, mas a decisão por trás de cada nó: por que aquele gatilho, como o erro é tratado,
o que acontece quando a API de destino cai.

**Autor:** Pedro Perim de Queiroz
**Stack:** n8n · Docker · PostgreSQL · Python · APIs REST · LLMs

---

## Workflows

| # | Workflow | Problema que resolve | Status |
|---|----------|---------------------|--------|
| 01 | [Triagem automática de chamados](workflows/01-triagem-chamados) | Chamados chegam por e-mail sem categoria e sem prioridade, e alguém precisa ler um por um | 🔜 Planejado |
| 02 | [Monitor de disponibilidade](workflows/02-monitor-disponibilidade) | Queda de serviço só é descoberta quando o usuário reclama | 🔜 Planejado |
| 03 | [Agente de IA sobre base de conhecimento](workflows/03-agente-base-conhecimento) | Mesmas dúvidas de procedimento interno chegam ao suporte toda semana | 🔜 Planejado |
| 04 | [Onboarding e offboarding](workflows/04-onboarding-offboarding) | Criação e revogação de acessos é manual, lenta e esquece etapas | 🔜 Planejado |

Legenda de status: 🔜 Planejado · 🚧 Em construção · ✅ Concluído

---

## Como rodar

O ambiente inteiro sobe em Docker. Instruções completas em [`infra/README.md`](infra/README.md).

```bash
cp .env.example .env    # preencha as variáveis
docker compose -f infra/docker-compose.yml --env-file .env up -d
```

O n8n fica disponível em `http://localhost:5678`.

Para importar um workflow: no n8n, menu **⋯ → Import from File**, e selecione o
`workflow.json` da pasta correspondente.

---

## Estrutura do repositório

```
├── infra/                  # docker-compose, variáveis, instruções de ambiente
├── docs/                   # convenções, glossário, decisões de arquitetura
└── workflows/
    └── NN-nome-do-fluxo/
        ├── README.md       # problema, solução, nós, como testar
        ├── workflow.json   # export do n8n (sem credenciais)
        └── assets/         # prints e GIFs do fluxo rodando
```

---

## Segurança

Nenhuma credencial, token ou endpoint interno real entra neste repositório. Os exports
de workflow são sanitizados antes do commit — veja [`docs/convencoes.md`](docs/convencoes.md).
