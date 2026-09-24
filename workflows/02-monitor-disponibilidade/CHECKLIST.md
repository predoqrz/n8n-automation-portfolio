# Checklist — workflow 02

Mesmo formato do workflow 01: ordem pensada para nunca ficar travado esperando outra
coisa, e "O que já quebrou" alimentado na hora, não reconstruído de memória depois.

**Onde eu parei:** etapa 4 — caso 1 passou; próximo é o caso 2

---

## Etapa 0 — já está pronto ✅

- [x] `workflow.json` desenhado, 27 nós, validado três vezes antes de chegar aqui:
      estrutura (nenhuma conexão órfã), lógica dos 6 nós Code (testada com dados
      simulados, 8 cenários) e as duas queries SQL reais (testadas contra o Postgres
      numa transação desfeita)
- [x] Antes de escrever o arquivo, conferidas no próprio n8n as opções exatas dos nós
      novos (HTTP Request, Discord, Merge, Schedule Trigger) — para não repetir o erro
      do `$env` do workflow 01, desta vez a checagem veio antes, não depois
- [x] DDL da tabela de log
- [x] README com decisões técnicas
- [x] Tabela `portfolio.disponibilidade_checks` já criada e testada no seu Postgres

Nada disso rodou dentro do n8n ainda. É desenho e SQL testados por fora, não fluxo
executando de ponta a ponta.

---

## Etapa 1 — Postgres ✅

- [x] Tabela criada:
      `docker cp workflows/02-monitor-disponibilidade/sql/001-disponibilidade-checks.sql n8n-postgres:/tmp/001-disponibilidade-checks.sql`
      `docker exec n8n-postgres psql -U n8n -d n8n -f /tmp/001-disponibilidade-checks.sql`
- [x] Conferida: schema, índice e as duas consultas reais, numa transação com
      `ROLLBACK` — nenhum dado ficou na tabela
- [x] Credencial Postgres no n8n: já existe, é a mesma do workflow 01. Nada novo aqui.

---

## Etapa 2 — Discord ✅

- [x] Criar um servidor no Discord (ou usar um que já tenha)
- [x] Criar um canal, por exemplo `#monitor`
- [x] **Configurações do canal → Integrações → Webhooks → Novo Webhook**
- [x] Copiar a **URL do Webhook**
- [x] No n8n: **Credentials → Add credential → Discord Webhook** → colar a URL

> Webhook não precisa de bot, de app registrado no Discord Developer Portal, nem de
> processo de aprovação. É a opção mais simples das três que o n8n oferece para o
> Discord — Bot Token e OAuth2 são para quando o fluxo precisa *ler* mensagens do
> servidor, não é o caso aqui.

---

## Etapa 3 — importar e ligar credenciais ✅

- [x] **Workflows → Import from File** → `workflow.json`
- [x] Devem aparecer 27 nós
- [x] Ligar a credencial **Discord Webhook** nos dois nós Discord (`Enviar alerta no
      Discord`, `Enviar relatório diário`)
- [x] Ligar a credencial **Postgres account** (já existente) nos três nós Postgres
- [x] Ligar a credencial **Notion account** (já existente) em `Verificar API do Notion`
- [x] Ligar a credencial **OpenAI account** (já existente) em `Verificar API da OpenAI`
- [x] Os dois nós sem autenticação (`Verificar n8n (local)`, `Verificar GitHub`) não
      pedem credencial — confirme que o campo *Authentication* está em `None`

---

## Etapa 4 — os quatro testes (uns 20 min)

Os passos completos de cada caso estão no [README](README.md), seção *Como testar*.

- [x] **Caso 1** — primeira execução (`Execute workflow`) → os 4 serviços caem em
      *Sem alerta (primeira checagem)*, 4 linhas gravadas no banco, nada no Discord
      (execução 23, depois da correção dos ramos paralelos; log gravado antes da decisão)
- [ ] **Caso 2** — rodar de novo sem mudar nada → nenhum alerta (estado igual)
- [ ] **Caso 3** — quebrar a URL do GitHub de propósito → alerta 🔴; rodar de novo →
      sem segundo alerta; devolver a URL → alerta 🟢 de recuperação
- [ ] **Caso 4** — abrir os dois nós do ramo diário com `Execute step` e conferir o
      texto do resumo antes de confiar nele

> Assim como no workflow 01, rode com **Execute workflow**, não clicando em `Execute
> step` só no último nó — isso reaproveita saída antiga dos nós anteriores e o teste
> mostra o resultado de uma execução velha, não da atual.

---

## Etapa 5 — fechar o workflow

- [ ] Preencher no README: **Resultado**, depois de rodar alguns dias em produção
- [ ] Print do canvas com os dois ramos, em `assets/`
- [ ] Print do alerta e do relatório diário no Discord, em `assets/`
- [ ] Revisar o export: nenhum ID, e-mail, token ou webhook do Discord dentro de nó
- [ ] Ativar o workflow (toggle **Active**)
- [ ] Deixar rodar pelo menos 24h antes do merge, para o relatório diário disparar
      pelo menos uma vez de verdade
- [ ] Merge de `feat/02-monitor-disponibilidade` na `main` (manual, pelo Pedro)

---

## O que já quebrou

Registrado na hora, para a seção *O que não funcionou* do README — desta vez, a maior
parte aconteceu **durante a construção**, não durante os testes, porque a checagem no
n8n veio antes de escrever o arquivo.

| Etapa | O que | Sintoma | Solução |
|---|---|---|---|
| 0 | `\$` em vez de `$` dentro do código JavaScript dos nós Code, ao escrever o `workflow.json` | `SyntaxError: Bad escaped character in JSON` | `\$` não é um escape válido em JSON. Corrigido substituindo por `$` puro nos três pontos afetados |
| 0 | `sed -i 's/\\\$/$/g'` não encontrava o padrão, mesmo com o escaping "certo" | Comando rodava sem erro, mas o arquivo não mudava | Troquei por um script Node percorrendo caractere a caractere — mais lento de escrever, impossível de errar |
| 4 | Insert com mapeamento automático recebeu campos sem coluna (`ok_anterior`, `primeira_checagem`, `mudou_estado`) | `Column 'ok_anterior' does not exist in selected table` no caso 1 | Suposição minha não conferida no código do nó. Nó novo *Separar colunas da tabela* entrega só as 6 colunas |
| 4 | O insert devolve a linha gravada (`RETURNING *`), não o item | Achado ao investigar o erro acima: os IF depois do insert nunca veriam `mudou_estado`, e **nenhum alerta sairia**, sem erro | Log e alerta viraram ramos paralelos a partir de *Montar registro da checagem* |
| 3 | Na importação, o n8n exportou um workflow vazio por cima do `workflow.json` | Arquivo com `"name": "My workflow"` e 0 nós | *Import from File* e *Download* ficam no mesmo menu `⋯`. Arquivo restaurado com `git checkout` |
| 0 | HTTP Request não deixa trocar de credencial por item | Um único nó com lista de 4 serviços não funcionaria para os 2 que precisam de autenticação | Desenho mudou para 4 nós HTTP Request separados, cada um com sua própria autenticação fixa, unidos depois por um nó Merge |

## Onde isso provavelmente vai quebrar

| Etapa | O que | Sintoma |
|---|---|---|
| 2 | Webhook colado com espaço sobrando no início ou no fim | Discord responde erro de autenticação ao enviar a primeira mensagem |
| 3 | Confundir qual credencial vai em qual nó Postgres/HTTP Request | Nó fica com contorno vermelho pedindo para selecionar credencial |
| 4 | Testar o caso 3 sem salvar a URL quebrada antes de rodar | Nenhuma queda é detectada, porque o nó ainda aponta para a URL antiga |
