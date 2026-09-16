# Checklist — workflow 01

Ordem pensada para você nunca ficar travado esperando outra coisa: cada etapa é
testável sozinha, e as mais chatas ficam por último, quando o resto já funciona.

**Onde eu parei:** etapa 1

---

## Etapa 0 — já está pronto ✅

- [x] n8n + PostgreSQL rodando em Docker
- [x] Repositório com estrutura e convenções
- [x] `workflow.json` desenhado, 18 nós
- [x] DDL da tabela de log
- [x] Script que cria o database do Notion
- [x] README com decisões técnicas

Nada disso foi executado ainda. É desenho, não fluxo funcionando.

---

## Etapa 1 — Postgres (15 min)

A mais fácil, e destrava o teste do nó 3.

- [ ] Copiar o SQL para dentro do container:
      `docker cp workflows/01-triagem-chamados/sql/001-log-triagem.sql n8n-postgres:/tmp/001-log-triagem.sql`
- [ ] Executar:
      `docker exec n8n-postgres psql -U n8n -d n8n -f /tmp/001-log-triagem.sql`
- [ ] Conferir que existe:
      `docker exec n8n-postgres psql -U n8n -d n8n -c "\d portfolio.log_triagem"`
- [ ] No n8n, criar a credencial Postgres — host `postgres`, porta `5432`, base `n8n`,
      usuário e senha do `.env`
- [ ] Botão **Test connection** verde

> Host é `postgres`, não `localhost`. De dentro do container do n8n, `localhost` é o
> próprio n8n. `postgres` é o nome do serviço no compose, e o Docker resolve como DNS.

---

## Etapa 2 — Notion (30 min)

- [ ] Criar uma página no Notion para o projeto (ex.: `Portfólio n8n`)
- [ ] Criar a integração em `notion.so/my-integrations` → **New integration** →
      workspace pessoal → copiar o *Internal Integration Secret*
- [ ] **Conectar a integração na página:** abra a página → `⋯` → **Connections** →
      **Connect to** → sua integração
- [ ] Preencher no `.env`: `NOTION_TOKEN` e `NOTION_PARENT_PAGE_ID` (pode colar a URL inteira)
- [ ] Criar o database:
      `node workflows/01-triagem-chamados/scripts/notion-database.mjs`
- [ ] Copiar o ID que o script imprimiu para `NOTION_DATABASE_CHAMADOS` no `.env`
- [ ] Conferir:
      `node workflows/01-triagem-chamados/scripts/notion-database.mjs --conferir`
- [ ] Recriar o container para o n8n enxergar a variável:
      `docker compose -f infra/docker-compose.yml up -d --force-recreate n8n`
- [ ] No Notion, criar a visão **Revisão manual**, filtrando `Categoria = Revisão manual`
- [ ] No n8n, criar a credencial Notion com o mesmo token

> O passo de **Connections** é o que mais gente esquece. Sem ele a API responde
> `object_not_found` com o ID perfeitamente correto, porque para a integração aquela
> página literalmente não existe. A permissão desce para as páginas-filhas, então
> conectar na página-mãe basta.

---

## Etapa 3 — OpenAI (10 min)

- [ ] Confirmar que `OPENAI_API_KEY` no `.env` tem crédito na conta
- [ ] Criar a credencial OpenAI no n8n
- [ ] Conferir o modelo do nó `Modelo OpenAI` — `gpt-4o-mini` é o padrão barato;
      troque se quiser

---

## Etapa 4 — Gmail (45 min a 2h, é a chata)

- [ ] Criar as labels `Chamados` e `Chamado processado`
- [ ] Criar um filtro no Gmail jogando os e-mails de suporte para `Chamados`
- [ ] Google Cloud Console → novo projeto → habilitar a **Gmail API**
- [ ] OAuth consent screen → External → adicionar seu e-mail como usuário de teste
- [ ] **Publicar o app em `In production`** e aceitar o aviso de app não verificado
- [ ] Criar credencial OAuth 2.0 tipo *Web application*
- [ ] Colar em *Authorized redirect URIs* a URL que o n8n mostra na tela da credencial
- [ ] Conectar a credencial Gmail no n8n
- [ ] Descobrir o ID da label: nó Gmail → **Label → Get Many** → executar → copiar o ID de
      `Chamado processado`
- [ ] Preencher `GMAIL_LABEL_PROCESSADO` no `.env` e recriar o container

> **Não pule o "In production".** Em modo *Testing*, o Google emite refresh token que
> **expira em 7 dias**. O fluxo funciona hoje, você posta, e na semana seguinte ele para
> sozinho sem erro óbvio.

---

## Etapa 5 — importar e testar nó a nó (30 min)

- [ ] **Workflows → Import from File** → `workflow.json`
- [ ] Ligar as quatro credenciais nos nós que pedirem
- [ ] Mandar um e-mail de teste para si mesmo e aplicar a label `Chamados`
- [ ] Rodar **Test step** no nó 1 e **olhar a saída real**
- [ ] Ajustar as expressões do nó 2 para os nomes de campo que apareceram de verdade
      (hoje tem fallback: `$json.subject || $json.Subject || ...`)
- [ ] Test step nos nós 3 e 4
- [ ] Test step no nó 6 — conferir o JSON que o LLM devolveu
- [ ] Test step até a página aparecer no Notion

> Um nó por vez, de cima para baixo. Rodar o fluxo inteiro e ver "erro" não diz onde.

---

## Etapa 6 — os quatro testes (30 min)

Os e-mails prontos para copiar estão no [README](README.md), seção *Como testar*.

- [ ] **Caso 1** — e-mail claro de rede → página em `Rede`, urgência Alta, automático
- [ ] **Caso 2** — e-mail vago → página em `Revisão manual`
- [ ] **Caso 3** — tirar a label `Chamado processado` do e-mail do caso 1 → deve parar em
      `Ignorar duplicado`, **sem** criar segunda página
- [ ] **Caso 4** — desligar a credencial OpenAI → `Revisão manual` com o erro no `Triagem`
- [ ] Conferir a tabela:
      `docker exec n8n-postgres psql -U n8n -d n8n -c "SELECT processado_em, categoria, urgencia, confianca, destino FROM portfolio.log_triagem ORDER BY processado_em DESC;"`

Os casos 3 e 4 são os que valem em entrevista. Todo mundo mostra o caminho feliz.

---

## Etapa 7 — fechar o workflow (1h)

- [ ] GIF do e-mail virando página, em `assets/`
- [ ] Print do canvas com os dois caminhos, em `assets/`
- [ ] Preencher no README: **Tempo de construção**, **Resultado**
- [ ] Passar as anotações de construção do Obsidian para *O que não funcionou* —
      **tudo** que quebrou nas etapas 2, 4 e 5. É o conteúdo que o post 1 prometeu, e
      é a única seção que não dá para escrever depois, de memória
- [ ] Status do README: 🚧 → ✅
- [ ] Revisar o export: nenhum ID, e-mail ou token dentro de nó
- [ ] Ativar o workflow (toggle **Active**)
- [ ] Merge de `feat/01-triagem-chamados` na `main`

---

## Etapa 8 — post 2 no LinkedIn

Só depois da etapa 7 inteira. Os gates:

- [ ] Roda de ponta a ponta com e-mail real
- [ ] Casos 3 e 4 passando
- [ ] GIF no repositório
- [ ] Pelo menos uma falha real documentada

Ângulo escolhido: **a IA classifica, mas não decide sozinha** — abaixo de 0,7 vai para
revisão humana. Fecha com pergunta específica: *onde você colocaria esse limite?*

- [ ] Rascunho escrito
- [ ] Postado

---

## Onde isso provavelmente vai quebrar

Guardado aqui porque previsão que você anotou antes vale mais que desculpa depois.

| Etapa | O que | Sintoma |
|---|---|---|
| 2 | Integração não conectada na página | `object_not_found` com ID certo |
| 4 | OAuth em modo Testing | Funciona 7 dias, depois para sozinho |
| 4 | Redirect URI diferente de um caractere | `redirect_uri_mismatch` |
| 5 | Campos do Gmail com nome diferente | `assunto` vem vazio ou `(sem assunto)` |
| 5 | `$env` vazio dentro do nó | Esqueceu de recriar o container |
