# Convenções do repositório

Este projeto é construído em colaboração com mais de um assistente de IA. As convenções
abaixo existem para que o resultado fique coerente independentemente de quem escreveu
cada parte.

## Branches e commits

- Uma branch por workflow: `feat/01-triagem-chamados`
- Commits no padrão Conventional Commits:
  - `feat:` novo workflow ou nova capacidade
  - `fix:` correção de fluxo quebrado
  - `docs:` README, documentação
  - `chore:` infra, dependências, ajustes de repositório
- Merge na `main` somente com o README do workflow preenchido.

## Sanitizar o export antes do commit

O `workflow.json` exportado pelo n8n **não** carrega o valor das credenciais, mas carrega
IDs, nomes de credencial, URLs e qualquer coisa que você tenha digitado dentro de um nó.
Antes de commitar, revise e substitua:

| O que aparece no export | Substituir por |
|---|---|
| URL interna real | `https://api.exemplo.com` |
| E-mail corporativo | `usuario@exemplo.com` |
| Token ou chave escrita direto no nó | mover para uma credencial do n8n |
| ID de database, lista ou marcador da sua conta | `COLE_AQUI_O_ID_DE_...` |
| Nome de cliente ou empresa | nome genérico |

Nunca escreva segredo direto no nó. Segredo (token, senha, chave de API) mora numa
**credencial do n8n**, que fica criptografada.

Não conte com `{{$env.NOME}}` dentro dos nós: no n8n 2 esse acesso é bloqueado por padrão
(`N8N_BLOCK_ENV_ACCESS_IN_NODE`), por segurança. Identificadores que não são segredo, como o
ID de um database ou de um marcador, podem ficar no nó — e são trocados por um marcador
`COLE_AQUI_...` no export que vai para o repositório.

## Nomenclatura dos nós

Nó com nome padrão (`HTTP Request1`, `IF2`) torna o fluxo ilegível para quem revisa.
Renomeie descrevendo a ação:

- ✅ `Classificar chamado com LLM`
- ✅ `Criar ticket no service desk`
- ✅ `Notificar responsável no Slack`
- ❌ `HTTP Request3`

## Todo workflow precisa de

1. **Tratamento de erro.** No mínimo um Error Trigger ou um caminho de erro explícito.
   Fluxo que só tem o caminho feliz não demonstra maturidade.
2. **Idempotência onde couber.** Rodar duas vezes não pode criar dois tickets.
3. **Log do que aconteceu.** Gravar execução em banco, planilha ou canal de log.
4. **README preenchido** seguindo o template em `docs/template-workflow.md`.
5. **Print ou GIF** do fluxo rodando, em `assets/`.

## Documentar decisão, não só resultado

O que diferencia este portfólio de um tutorial copiado é o "por quê". Em cada README,
a seção de decisões técnicas deve responder coisas como: por que Schedule Trigger e não
webhook, por que gravar em Postgres e não em planilha, o que você tentou antes que não
funcionou.
