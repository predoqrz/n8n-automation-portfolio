# Checklist — workflow 01

Ordem pensada para você nunca ficar travado esperando outra coisa: cada etapa é
testável sozinha, e as mais chatas ficam por último, quando o resto já funciona.

**Onde eu parei:** etapa 7 — README e export prontos; faltam assets, ativação e merge

---

## Etapa 0 — já está pronto ✅

- [x] n8n + PostgreSQL rodando em Docker
- [x] Repositório com estrutura e convenções
- [x] `workflow.json` desenhado, 18 nós
- [x] DDL da tabela de log
- [x] Script que cria o database do Notion
- [x] README com decisões técnicas

O fluxo em si ainda não rodou: até aqui é desenho, não automação funcionando.

---

## Etapa 1 — Postgres ✅

A mais fácil, e destrava o teste do nó 3.

- [x] Copiar o SQL para dentro do container:
      `docker cp workflows/01-triagem-chamados/sql/001-log-triagem.sql n8n-postgres:/tmp/001-log-triagem.sql`
- [x] Executar:
      `docker exec n8n-postgres psql -U n8n -d n8n -f /tmp/001-log-triagem.sql`
- [x] Conferir que existe:
      `docker exec n8n-postgres psql -U n8n -d n8n -c "\d portfolio.log_triagem"`
- [x] No n8n, criar a credencial Postgres — host `postgres`, porta `5432`, base `n8n`,
      usuário e senha do `.env`
- [x] Botão **Test connection** verde

> Host é `postgres`, não `localhost`. De dentro do container do n8n, `localhost` é o
> próprio n8n. `postgres` é o nome do serviço no compose, e o Docker resolve como DNS.

---

## Etapa 2 — Notion ✅

- [x] Criar uma página no Notion para o projeto (ex.: `Portfólio n8n`)
- [x] Criar a conexão em **Developer tools → Connections → New connection** (o Notion
      renomeou *integration* para *connection*) → copiar o token
- [x] **Conectar a integração na página:** abra a página → `⋯` → **Connections** →
      **Connect to** → sua integração
- [x] Preencher no `.env`: `NOTION_TOKEN` e `NOTION_PARENT_PAGE_ID` (pode colar a URL inteira)
- [x] Criar o database:
      `node workflows/01-triagem-chamados/scripts/notion-database.mjs`
- [x] Copiar o ID que o script imprimiu para `NOTION_DATABASE_CHAMADOS` no `.env`
- [x] Conferir:
      `node workflows/01-triagem-chamados/scripts/notion-database.mjs --conferir`
- [x] Recriar o container para o n8n enxergar a variável:
      `docker compose -f infra/docker-compose.yml --env-file .env up -d --force-recreate n8n`
- [x] No Notion, criar a visão **Revisão manual**, filtrando `Categoria = Revisão manual`
- [x] No n8n, criar a credencial Notion com o mesmo token

> O passo de **Connections** é o que mais gente esquece. Sem ele a API responde
> `object_not_found` com o ID perfeitamente correto, porque para a integração aquela
> página literalmente não existe. A permissão desce para as páginas-filhas, então
> conectar na página-mãe basta.

---

## Etapa 3 — OpenAI ✅

- [x] Confirmar que `OPENAI_API_KEY` no `.env` tem crédito na conta
- [x] Criar a credencial OpenAI no n8n
- [x] Conferir o modelo do nó `Modelo OpenAI` — `gpt-4o-mini` é o padrão barato;
      troque se quiser

---

## Etapa 4 — Gmail ✅ (falta só o filtro automático, depois dos testes)

- [x] Criar as labels `Chamados` e `Chamado processado`
- [ ] Criar um filtro no Gmail jogando os e-mails de suporte para `Chamados` (depois dos testes; nos testes a label é aplicada à mão)
- [x] Google Cloud Console → novo projeto → habilitar a **Gmail API**
- [x] OAuth consent screen → External → adicionar seu e-mail como usuário de teste
- [x] **Publicar o app em `In production`** e aceitar o aviso de app não verificado
      (o Google exigiu página inicial e política de privacidade no Branding; usados o
      repositório e `PRIVACY.md`)
- [x] Criar credencial OAuth 2.0 tipo *Web application*
- [x] Colar em *Authorized redirect URIs* a URL que o n8n mostra na tela da credencial
- [x] Conectar a credencial Gmail no n8n
- [x] Descobrir o ID da label: nó Gmail → **Label → Get Many** → executar → copiar o ID de
      `Chamado processado`
- [x] Descobrir o ID do marcador — hoje só serve de conferência: o marcador é escolhido no nó

> **Não pule o "In production".** Em modo *Testing*, o Google emite refresh token que
> **expira em 7 dias**. O fluxo funciona hoje, você posta, e na semana seguinte ele para
> sozinho sem erro óbvio.

---

## Etapa 5 — importar e testar nó a nó (30 min)

- [x] **Workflows → Import from File** → `workflow.json`
- [x] Ligar as quatro credenciais nos nós que pedirem
- [x] No nó *Criar página no Notion*: Database → **From list** → `Chamados`
- [x] No nó *Marcar e-mail como processado*: marcador `Chamado processado` na lista
- [x] Mandar um e-mail de teste para si mesmo e aplicar a label `Chamados`
- [x] Rodar **Test step** no nó 1 e **olhar a saída real**
- [x] Ajustar as expressões do nó 2 para os nomes de campo que apareceram de verdade
      (hoje tem fallback: `$json.subject || $json.Subject || ...`)
- [x] Test step nos nós 3 e 4
- [x] Test step no nó 6 — conferir o JSON que o LLM devolveu
      (Rede · Alta · 0.9, igual nas duas chamadas: `temperature: 0` estável)
- [x] Test step até a página aparecer no Notion — `[Alta] Wi-Fi do 3º andar caiu`, 9 propriedades
      e o corpo conferidos pela API
- [x] ~~Fixar (pin) a saída do nó do Notion antes de testar os nós seguintes~~ (quebrou o rastreio de itens; ver *O que já quebrou*)
- [x] Apagar a página de teste no Notion, tirar o pin e rodar *Marcar e-mail como processado* sem nó fixado
- [x] Test step em *Registrar triagem no Postgres* e *Marcar e-mail como processado* — ponta a ponta:
      1 página no Notion, 1 linha no log com o mesmo `notion_page_id`, marcador aplicado no Gmail
- [ ] **Desafixar (unpin) todos os nós antes de ativar o workflow**
- [x] Fechar a janela de duplicidade no repositório — opção B: buscar a página pelo *ID da
      mensagem* antes de criar. Junto, a checagem ignora `falha-notion` e o log virou upsert
- [x] Reimportar o `workflow.json` atualizado, ligar as credenciais (7 nós) e preencher o ID do
      database na URL da busca e no nó de criação; arquivar o workflow antigo
- [x] Rodar ponta a ponta de novo: seguiu por *Reaproveitar página existente*

> Um nó por vez, de cima para baixo. Rodar o fluxo inteiro e ver "erro" não diz onde.

---

## Etapa 6 — os cinco testes ✅

Os e-mails prontos para copiar estão no [README](README.md), seção *Como testar*.

- [x] **Caso 1** — e-mail claro de rede → página em `Rede`, urgência Alta, automático (execução 11)
- [x] **Caso 2** — e-mail vago → página em `Revisão manual`: a IA chutou `Sistemas` com
      confiança 0.6 e o limite de 0,7 segurou (execução 15)
- [x] **Caso 3** — tirar a label `Chamado processado` do e-mail do caso 1 → parou em
      `Ignorar duplicado` com `ja_processado = 1`, sem IA, sem busca e sem segunda página (execução 14)
- [x] **Caso 4** — IA indisponível (modelo inexistente) → `Revisão manual` com o erro da OpenAI
      em *Triagem*, confiança 0, página, log e marcador (execução 16)
- [x] **Desfazer o caso 4:** voltar *Modelo OpenAI* para **From list → gpt-4o-mini**
- [x] **Caso 5** — apagar a linha do log e tirar a label → reaproveitou a página, sem duplicar (execução 12)
- [ ] Conferir a tabela:
      `docker exec n8n-postgres psql -U n8n -d n8n -c "SELECT processado_em, categoria, urgencia, confianca, destino FROM portfolio.log_triagem ORDER BY processado_em DESC;"`

Os casos 3 e 4 são os que valem em entrevista. Todo mundo mostra o caminho feliz.

> Rode cada caso com **Execute workflow** (botão no rodapé do canvas), não com *Execute step*.
> O *Execute step* reaproveita a saída guardada dos nós anteriores que não mudaram, e o
> teste passa a mostrar o resultado de uma execução velha.

---

## Etapa 7 — fechar o workflow (1h)

- [ ] GIF do e-mail virando página, em `assets/`
- [ ] Print do canvas com os dois caminhos, em `assets/`
- [x] Preencher no README: **Tempo de construção**, **Resultado** (tempo é piso pelos commits; ajustar se quiser)
- [x] Passar as anotações de construção para *O que não funcionou* — feito a partir da tabela
      abaixo; conferir se o Obsidian tem algo que não está aqui —
      **tudo** que quebrou nas etapas 2, 4 e 5. É o conteúdo que o post 1 prometeu, e
      é a única seção que não dá para escrever depois, de memória
- [ ] Status do README: 🚧 → ✅
- [x] Revisar o export: nenhum ID, e-mail ou token dentro de nó — comparado com o workflow
      testado no n8n: diferenças só em IDs (marcadores), padrões omitidos e ordem de chaves
- [ ] Ativar o workflow (toggle **Active**)
- [x] Push da branch — o link da política de privacidade no Google aponta para ela
- [ ] Merge de `feat/01-triagem-chamados` na `main`
- [ ] Trocar o link da política no Branding do Google para `blob/main/PRIVACY.md`

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

## O que já quebrou

Registrado na hora, para a seção *O que não funcionou* do README.

| Etapa | O que | Sintoma | Solução |
|---|---|---|---|
| — | `<` de redirecionamento não existe no PowerShell | O comando falha antes de chegar no `psql` | `docker cp` + `psql -f`, que funciona nos três sistemas |
| 2 | Comando de recriar o container sem `--env-file .env` | O Compose procura o `.env` na pasta do `docker-compose.yml` (`infra/`), sobe o n8n com variáveis vazias e ele perde o banco | Sempre `docker compose -f infra/docker-compose.yml --env-file .env ...` — pego antes de rodar |
| 2 | Token do Notion visível num print compartilhado | Segredo exposto fora do `.env` | Decisão consciente de não regenerar; print apagado e nenhum print do `.env` vai para post. Regenerar se houver qualquer vazamento |
| 2 | `process.exit()` logo depois de `fetch` no Node/Windows | `Assertion failed ... async.c` e código de saída de erro com o resultado certo | Lançar erro e usar `process.exitCode` |
| 2 | Tela do Notion mudou | *My integrations* virou *Developer tools → Connections* | Documentação atualizada |
| 4 | URI de retorno colada em *Origens JavaScript autorizadas* | `Origem inválida: não é permitido que URIs de origem contenham um caminho` | Apagar e colar em *URIs de redirecionamento autorizados*, a seção de baixo |
| 4 | Google exige página inicial e política de privacidade para publicar | Botão *Publicar app* desabilitado | Repositório público como página inicial e `PRIVACY.md` como política |
| 5 | `$env` bloqueado por padrão no n8n 2 (`N8N_BLOCK_ENV_ACCESS_IN_NODE`) | Editor mostra *not accessible via UI*; na execução daria *access to env vars denied*, e o nó do Notion não lista as propriedades | IDs do database e do marcador escolhidos direto nos nós; segredos continuam nas credenciais. Confirmado lendo o código do n8n 2.39.5 |
| 5 | Campo em modo expressão (`fx`) não deixa escolher *From list* | Opção cinza no seletor | Clicar em **Fixed** no título do campo antes de trocar o modo |
| 5 | Propriedades do Notion continuam com *Error fetching options* depois de trocar o database | Erro guardado em cache pelo editor; os valores salvos estavam certos | Salvar e recarregar a página (F5) |
| 5 | Fallback `$json.headers?.subject` no nó 2 | Os headers do Gmail vêm brutos: o assunto chega como `=?UTF-8?Q?Wi=2DFi_do_3=C2=BA_andar_caiu?=` | Removido; só campos conferidos na saída real (`subject`, `from.text`, `text`, `date`) |
| 5 | Nó *Validar classificação* lia `$json.categoria`, mas o Basic LLM Chain entrega a resposta em `$json.output` | LLM respondeu `Rede / Alta / 0.9` e o nó transformou em `Revisão manual / Baixa / 0`. Sem erro nenhum: **todo** chamado iria para revisão manual em silêncio | `const llm = $json.output ?? $json`. Testado com a saída real e com quatro respostas inválidas |
| 5 | Saída do Notion fixada (pin) para não duplicar página no teste | *Montar registro de log* recebeu `null` em tudo que vinha de `$('Chamado triado').item`; o Postgres recusou com `Column 'mensagem_id' is not nullable` | O `NOT NULL` impediu um log sem identificação. Confirmado: sem pin, todos os campos chegaram |
| 5 | Falha entre criar a página e gravar o log | Página no Notion, sem log e sem marcador: com o workflow ativo, o próximo ciclo criaria **uma segunda página** | Corrigido com a opção B: busca no Notion pelo *ID da mensagem* antes de criar |
| 5 | Checagem de duplicidade contava linhas `falha-notion` | Descoberto no desenho da opção B: um chamado que falhou no Notion nunca mais seria tentado, em silêncio | Checagem ignora `falha-notion`; log virou upsert. Provado numa transação com ROLLBACK |
| 6 | Caso 3 testado com *Execute step* no último nó | Passou por tudo com `ja_processado = 0`, como se o log estivesse vazio | Não era bug: o *Execute step* reaproveitou a saída guardada dos 14 nós anteriores (horários de início idênticos aos da execução 12) e só rodou o último. Testes de cenário usam **Execute workflow**, que roda tudo do zero |
| 1 | Docker Desktop instalado em `AppData\Local\Programs` (por usuário), não em `Program Files` | `docker` some do PATH de qualquer app aberto antes da instalação | Reabrir o app, ou acrescentar o diretório ao `$env:Path` da sessão |

## Onde isso provavelmente vai quebrar

Guardado aqui porque previsão que você anotou antes vale mais que desculpa depois.

| Etapa | O que | Sintoma |
|---|---|---|
| 2 | Integração não conectada na página | `object_not_found` com ID certo |
| 4 | OAuth em modo Testing | Funciona 7 dias, depois para sozinho |
| 4 | Redirect URI diferente de um caractere | `redirect_uri_mismatch` |
| 5 | Campos do Gmail com nome diferente | `assunto` vem vazio ou `(sem assunto)` |
