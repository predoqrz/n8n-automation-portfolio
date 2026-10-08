# Checklist — workflow 05

Mesmo formato dos workflows 01 e 02: ordem pensada para nunca ficar travado esperando
outra coisa, e "O que já quebrou" alimentado na hora.

**Onde eu parei:** etapa 0 — infra preparada no repositório, esperando o Docker voltar

---

## Etapa 0 — preparado no repositório ✅

- [x] Serviço `evolution` acrescentado ao `infra/docker-compose.yml` (imagem, variáveis
      e endpoints confirmados na documentação oficial antes de escrever, não de memória)
- [x] Variáveis novas no `.env.example`: `EVOLUTION_API_KEY`, `MONDAY_API_TOKEN`,
      `MONDAY_BOARD_ID`
- [x] `scripts/monday-board.mjs` — cria e confere o board via API, mesmo padrão do
      `notion-database.mjs` do workflow 01
- [x] `sql/001-atendimento-mensagens.sql` — tabela de log e idempotência
- [x] README com o problema, a solução, o ponto de atenção sobre risco do WhatsApp
      não-oficial, e as decisões já tomadas

Nada disso rodou ainda. É infraestrutura escrita, não testada.

---

## Etapa 1 — Docker e Evolution API

- [ ] Abrir o Docker Desktop
- [ ] Gerar a chave: `openssl rand -hex 24` → colar em `EVOLUTION_API_KEY` no `.env`
- [ ] Criar o banco da Evolution (uma vez): `CREATE DATABASE evolution;`
- [ ] Subir o serviço: `docker compose -f infra/docker-compose.yml --env-file .env up -d evolution`
- [ ] Conferir: `curl http://localhost:8080` deve responder algo (não erro de conexão)

---

## Etapa 2 — parear o WhatsApp

- [ ] Criar a instância via API (`POST /instance/create`)
- [ ] Buscar o QR Code (`GET /instance/connect/{instance}`)
- [ ] Escanear com o WhatsApp do celular (**Aparelhos conectados** → **Conectar um
      aparelho**)
- [ ] Confirmar que a instância ficou com status `open`/conectado

> Fazer isso com o app do WhatsApp aberto no celular, wi-fi estável. O QR expira em
> segundos; se demorar para escanear, é só pedir um novo.

---

## Etapa 3 — Monday.com

- [ ] Criar conta (ou usar uma existente) e gerar o token de API
- [ ] Preencher `MONDAY_API_TOKEN` no `.env`
- [ ] `node workflows/05-atendimento-whatsapp-crm/scripts/monday-board.mjs`
- [ ] Colar o `MONDAY_BOARD_ID` que o script imprimir, no `.env`
- [ ] `node workflows/05-atendimento-whatsapp-crm/scripts/monday-board.mjs --conferir`

---

## Etapa 4 — configurar o webhook da Evolution → n8n

- [ ] `POST /webhook/set/{instance}` apontando para a URL do webhook do n8n
- [ ] Habilitar só o evento `MESSAGES_UPSERT`

---

## Etapa 5 — montar o workflow no n8n

- [ ] Desenhar os nós (será feito junto, como os workflows 01 e 02)
- [ ] Credenciais: OpenAI (existente), Postgres (existente), Monday.com API,
      cabeçalho `apikey` da Evolution nos nós HTTP Request

---

## Etapa 6 — testes

- [ ] Mensagem simples → resposta humanizada, com pausa de digitação
- [ ] Segunda mensagem do mesmo número → o agente lembra o que foi dito antes
- [ ] Lead novo → aparece no Monday, com telefone e `wa_id` preenchidos
- [ ] Mensagem repetida (reenvio de webhook) → não gera segunda resposta
- [ ] Mensagem de grupo → ignorada
- [ ] Situação que o agente não deveria resolver sozinho → vai para "Aguardando humano",
      sem resposta automática incorreta

---

## O que já quebrou

| Etapa | O que | Sintoma | Solução |
|---|---|---|---|
| 0 | — | — | — |
