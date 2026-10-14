# Checklist — workflow 05

Mesmo formato dos workflows 01 e 02: ordem pensada para nunca ficar travado esperando
outra coisa, e "O que já quebrou" alimentado na hora.

**Onde eu parei:** concluído (13/10/2026) — fluxo completo de ponta a ponta, prints em `assets/`,
README fechado. Falta só o merge na `main` (manual, pelo Pedro)

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

## Etapa 3 — Monday.com ✅

- [x] Token de API gerado
- [x] `MONDAY_API_TOKEN` no `.env`
- [x] Board criado pelo script (7 colunas)
- [x] `MONDAY_BOARD_ID` no `.env`
- [x] `--conferir`: 7 de 7 colunas certas; formato das colunas testado direto na API
- [x] Credencial criada pela CLI; 4 nós do CRM ligados

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
- [x] Monday ligado

---

## Etapa 6 — testes

- [x] Mensagem simples → resposta pelo WhatsApp (conversa "Você", modo de teste)
- [x] Segunda mensagem do mesmo número → o agente lembra o que foi dito antes
- [x] Mensagem de grupo, mídia, mensagem antiga → ignoradas, sem gravar nada
- [x] Webhook sem segredo → 403
- [x] Lead novo → criado no Monday e atualizado a cada mensagem
- [ ] Mensagem repetida (reenvio de webhook) → não gera segunda resposta (provado no SQL;
      falta provar ponta a ponta)
- [x] Pedido de orçamento qualificado → "Aguardando humano" no Monday, e a mensagem seguinte não recebe resposta da IA
- [x] Prompt: uma pergunta por mensagem, só qualifica com os 4 dados, nome do lead é o da pessoa — 4 cenários simulados

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
| 3 | Script do board rodado duas vezes por erro de comando; ID `ultima_mensagem` recusado pelo Monday; cor `grey` inexistente | Três boards incompletos na conta | Boards arquivados (reversível); ID trocado por `mensagem_recente`; cor conferida na lista oficial da API (`american_gray`); o script agora arquiva sozinho o board se falhar no meio |
| 6 | Mensagem chegou durante a republicação do workflow | `Active version not found` — mensagem perdida, lead não criado | Janela de segundos a cada republicação. Limite conhecido, não bug |
| 6 | "Não salvar execuções" não apagava na hora | 45 execuções "running" com o corpo do webhook (mensagens, inclusive de grupos) | Lido no código do n8n: com a limpeza automática ligada, ele só marca para apagar no próximo ciclo. `EXECUTIONS_DATA_PRUNE=false` faz apagar na hora; provado com 0 execuções no banco depois de chamadas reais e simuladas |
| 6 | Parser estruturado do agente + modo JSON do modelo | Resposta certa recusada: às vezes o invólucro vinha vazio (o agente alternava entre texto e chamada de ferramenta), às vezes "Não qualificado" (um status) no campo de intenção | Parser do agente removido. O modelo continua obrigado a JSON, e o nó *Preparar resposta* valida: campo fora da lista vira valor seguro, JSON ilegível vira passagem para humano. Testado em 4 casos fora do n8n e reproduzido com mensagem simulada |
| 6 | Prompt com regras soltas (gpt-4o-mini) | Três ou quatro perguntas na mesma mensagem; lead qualificado sem o nome da pessoa; nome da empresa gravado como nome; emoji sem o cliente usar | Roteiro em ordem (nome, empresa, tamanho, necessidade), campo `dados_coletados` na saída para o modelo acompanhar o que já sabe, exemplo de conversa e temperatura 0,2. Validado com simulador próprio (número fictício, nada chega no WhatsApp) em 4 cenários |
| 6 | Lead excluído no Monday pela interface | Workflow verde, mas o lead parou de ser atualizado: o Monday (GraphQL) responde erro com HTTP 200 (*Cannot change column value for inactive items*), e o nó HTTP trata como sucesso | Depois de atualizar, o workflow confere `errors` na resposta: se o item sumiu, recria o lead e guarda o ID novo; se a criação falhar, o nó *Conferir criação no Monday* para a execução com erro explícito. Reproduzido com o item excluído de verdade |
