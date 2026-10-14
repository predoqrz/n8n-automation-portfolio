# Checklist — workflow 05

Mesmo formato dos workflows 01 e 02: ordem pensada para nunca ficar travado esperando
outra coisa, e "O que já quebrou" alimentado na hora.

**Onde eu parei:** etapa 5 — atendimento respondendo pelo WhatsApp de ponta a ponta (13/10/2026),
com memória da conversa. Falta o Monday: token de API, board e religar os 4 nós do CRM

---

## Etapa 0 — preparado no repositório ✅

- [x] Serviço `evolution` no `infra/docker-compose.yml` (imagem, variáveis e endpoints
      confirmados na documentação e no código-fonte da versão rodando, não de memória)
- [x] Variáveis no `.env.example`
- [x] `scripts/monday-board.mjs` — cria e confere o board via API
- [x] `sql/001-atendimento-mensagens.sql` — log e idempotência
- [x] `sql/002-atendimento-contatos.sql` — lista de atendimento e passagem para humano
- [x] README com o problema, a solução e o ponto de atenção sobre risco

---

## Etapa 1 — Docker e Evolution API ✅

- [x] Chave gerada e gravada no `.env` (sem passar pelo chat)
- [x] Banco `evolution` criado; Evolution API v2.3.7 no ar
- [x] Sem `apikey` responde 401, com `apikey` responde 200

---

## Etapa 2 — parear o WhatsApp ✅

- [x] Instância `atendimento` criada, QR escaneado, estado `open`
- [x] Número do dono na lista de atendimento (lido da própria Evolution, nunca no repositório)

---

## Etapa 3 — Monday.com

- [ ] Criar conta (ou usar uma existente) e gerar o token de API
- [ ] Preencher `MONDAY_API_TOKEN` no `.env`
- [ ] `node workflows/05-atendimento-whatsapp-crm/scripts/monday-board.mjs`
- [ ] Colar o `MONDAY_BOARD_ID` que o script imprimir, no `.env`
- [ ] `node workflows/05-atendimento-whatsapp-crm/scripts/monday-board.mjs --conferir`
- [ ] Credencial Monday.com no n8n e religar os 4 nós do CRM

---

## Etapa 4 — webhook da Evolution → n8n ✅

- [x] `POST /webhook/set/atendimento` → `http://n8n:5678/webhook/atendimento-whatsapp`,
      só `MESSAGES_UPSERT`
- [x] Cabeçalho secreto `x-webhook-secret`: sem ele ou com valor errado, o n8n responde 403

---

## Etapa 5 — montar o workflow no n8n

- [x] 20 nós, gerados por script (sem escape manual de JavaScript), estrutura validada
- [x] Versões dos nós conferidas nas definições dentro do próprio n8n antes de escrever
- [x] As 3 queries SQL testadas em 6 cenários, numa transação desfeita
- [x] Credenciais Evolution e Webhook criadas pela CLI, com os segredos lidos do `.env`
- [x] Privacidade: nada do WhatsApp pessoal fica guardado fora da tabela do workflow
- [ ] Monday ligado (depende da etapa 3)

---

## Etapa 6 — testes

- [x] Mensagem simples → resposta pelo WhatsApp (conversa "Você", modo de teste)
- [x] Segunda mensagem do mesmo número → o agente lembra o que foi dito antes
- [x] Mensagem de grupo, mídia, mensagem antiga → ignoradas, sem gravar nada
- [x] Webhook sem segredo → 403
- [ ] Lead novo → aparece no Monday, com telefone e `wa_id` preenchidos
- [ ] Mensagem repetida (reenvio de webhook) → não gera segunda resposta (provado no SQL;
      falta provar ponta a ponta)
- [ ] Pedido de orçamento qualificado → "Aguardando humano", e a IA para de responder
- [ ] Ajuste de prompt: uma pergunta por vez (na 2ª resposta ela fez duas)

---

## O que já quebrou

| Etapa | O que | Sintoma | Solução |
|---|---|---|---|
| 1 | Variáveis do workflow 05 só existiam no `.env.example`, não no `.env` | A gravação da chave não achou a linha; o comando seguinte subiu o container **sem chave** | Container parado na hora, variáveis acrescentadas, container recriado e 401/200 conferidos |
| 5 | Teste do SQL com `currval` depois de um `ON CONFLICT DO NOTHING` | Atualização em 0 linhas | Não era bug do workflow: o insert recusado também consome a sequência. Teste refeito com sequência fixa |
| 6 | Nós do Monday sem credencial | **Toda** execução falhava no início, até as que só deviam ignorar mensagem de grupo | O n8n confere as credenciais de todos os nós antes de rodar o primeiro. Nós do Monday desligados até o token existir |
| 6 | Agente com parser estruturado e sem ferramentas | Resposta boa, mas em texto puro: *Model output doesn't fit required format* | Modo JSON no modelo (`json_object`) + formato explícito no prompt |
| 6 | Privacidade: o número é pessoal | Evolution guardou 114 mil mensagens, 2.861 contatos e 898 conversas; o log do container e o histórico do n8n também tinham conteúdo de conversas pessoais | Armazenamento de mensagens desligado na Evolution, log do container desligado, workflow sem salvar execuções; tudo o que já existia, apagado |
| 6 | Execução salva para diagnóstico trazia o cabeçalho do webhook | O segredo passou pela conversa de diagnóstico | Segredo trocado; o antigo agora recebe 403 |
