# 03 — Agente de IA sobre base de conhecimento interna

**Status:** 🚧 Em construção
**Integrações:** pasta local de documentos · PostgreSQL com pgvector · OpenAI (embeddings e chat) · chat do n8n
**Competências demonstradas:** RAG (busca por significado + geração), ingestão idempotente
de documentos, embeddings, banco vetorial, AI Agent com ferramenta, controle do que a IA
pode afirmar

## O problema

As mesmas perguntas de procedimento interno chegam ao suporte de TI toda semana: como pedir
acesso a tal sistema, quanto tempo demora, quem aprova, por que a VPN não conecta. A resposta
está documentada, mas ninguém acha o documento — então é mais rápido perguntar para uma
pessoa, que perde tempo repetindo a mesma resposta.

## A solução

Dois workflows. Um lê os documentos, divide em trechos, gera um vetor de significado para
cada trecho e grava no Postgres. O outro responde perguntas num chat: busca os trechos mais
parecidos com a pergunta e responde **só com o que está neles**, citando a fonte — ou diz
que não encontrou.

```mermaid
flowchart TD
    subgraph Indexação · 03a
        A[Manual ou a cada hora] --> B[Ler .md da pasta]
        B --> C[Extrair texto]
        C --> D{Hash mudou?}
        D -->|igual| N[Nada a fazer · sem custo]
        D -->|novo / alterado| E[Dividir em trechos]
        E --> F[Embeddings · OpenAI]
        F --> G[(kb_chunks · pgvector)]
        G --> H[(Recibo com o hash)]
        D -->|removido| X[Apagar trechos e recibo]
    end
    subgraph Consulta · 03b
        P[Pergunta no chat] --> Q[(Últimas 3 perguntas e respostas)]
        Q --> R[Agente de IA]
        R <--> S[Ferramenta: buscar na base]
        S <--> G
        R --> T[Resposta + Fonte]
        T --> L[(Log da conversa)]
    end
```

## Ponto de atenção

Agente que inventa procedimento interno é pior que não ter agente. Três defesas:

- **A resposta só pode vir da base.** O prompt proíbe completar com conhecimento geral; se os
  trechos não respondem, a resposta é a frase fixa *"Não encontrei isso na base de
  conhecimento."* — e ela é medida no log (`respondeu_da_base`), o que mostra o que falta
  documentar.
- **Toda resposta cita a fonte**, copiada de um campo pronto em cada trecho.
- **Temperatura 0.** Para procedimento, criatividade é defeito.

## Os nós, em ordem

### 03a · Indexar base de conhecimento

| # | Nó | Tipo | O que faz |
|---|----|------|-----------|
| 1 | Indexar agora / A cada hora | Manual + Schedule Trigger | Dois jeitos de disparar a mesma indexação. |
| 2 | Ler documentos | Read/Write Files from Disk | Lê `/files/base-conhecimento/*.md` (pasta do repositório montada só leitura). |
| 3 | Extrair texto | Extract from File | Binário → texto. |
| 4 | Preparar documentos | Code | Junta texto, nome do arquivo e título (primeira linha `#`). |
| 5 | Comparar com o índice | Postgres | Uma consulta: compara o hash de cada documento com o recibo, classifica em novo/alterado/igual/removido e já apaga os trechos do que mudou ou sumiu. |
| 6 | Separar o que mudou | Code | Só novo e alterado seguem — é o que torna a indexação idempotente e barata. |
| 7 | Algo para indexar? | IF | Nada mudou → fim, sem chamar a OpenAI. |
| 8 | Gravar trechos com embeddings | Postgres PGVector Store | Com *Carregar documento* (metadados: `fonte`, `titulo`, `citar_como`), *Dividir em trechos* (800 caracteres, 120 de sobreposição, por Markdown) e *Embeddings OpenAI* (`text-embedding-3-small`). |
| 9 | Registrar recibos | Postgres | Um recibo por documento: hash e quantos trechos virou. |

### 03b · Agente da base de conhecimento

| # | Nó | Tipo | O que faz |
|---|----|------|-----------|
| 1 | Chat da base de conhecimento | Chat Trigger | Chat público do n8n. |
| 2 | Carregar histórico da conversa | Postgres | Últimas 3 perguntas e respostas da sessão, para entender "e quanto tempo leva?". Sempre devolve uma linha. |
| 3 | Agente de TI | AI Agent | gpt-4o-mini, temperatura 0, com a ferramenta de busca. |
| 4 | Buscar na base de conhecimento | Postgres PGVector Store (como ferramenta) | Os 4 trechos mais parecidos com a pergunta, com os metadados. |
| 5 | Registrar pergunta e resposta | Postgres | Grava no log e devolve a resposta ao chat. |

## Decisões técnicas

- **Por que pgvector no Postgres que já existe, e não um banco vetorial dedicado:** nenhum
  serviço novo, custo zero, e a base continua inspecionável com SQL comum — dá para ver cada
  trecho, cada vetor e cada recibo.
- **Por que compilar o pgvector na imagem Alpine, e não usar a imagem oficial do pgvector:**
  a oficial é Debian. O banco existente foi criado no Alpine com collation `en_US.utf8`, que
  ordena texto de um jeito na musl (Alpine) e de outro na glibc (Debian). Trocar de base
  sobre o mesmo volume deixaria índices de texto inconsistentes sem erro nenhum. Ver
  `infra/postgres/Dockerfile`. A troca foi feita com backup antes e contagem de linhas
  conferida depois.
- **Por que idempotência por hash do conteúdo:** rodar a indexação de hora em hora sem mudar
  nada não pode gerar embedding (custo) nem duplicar trecho. Documento alterado é reindexado
  sozinho; documento apagado da pasta tem os trechos apagados do índice.
- **Por que a tabela de trechos é criada no SQL, e não pelo nó:** dimensão do vetor fixa
  (1536), o que permite o índice HNSW; e a indexação pode apagar trechos antigos antes do
  primeiro insert.
- **Por que trechos de 800 caracteres com 120 de sobreposição, divididos por Markdown:** os
  documentos são procedimentos curtos com seções e tabelas; a divisão por Markdown respeita
  os títulos, e 800 caracteres cabem uma seção inteira na maioria dos casos. A sobreposição
  evita perder uma regra que caia na fronteira entre dois trechos.
- **Por que a citação vem pronta em cada trecho (`citar_como`):** pedir ao modelo para montar
  "título (arquivo)" a partir de dois campos fez ele inventar nomes de arquivo em 2 de 3
  tentativas. Copiar um campo literalmente acertou 3 de 3.
- **Por que a memória vem do próprio log, e não do nó de memória do agente:** ver *O que não
  funcionou*.
- **Por que o chat do n8n, e não Telegram ou WhatsApp:** Telegram exige URL pública com
  HTTPS, e o n8n roda em `localhost`; o WhatsApp é do workflow 05. O chat do n8n funciona
  local, sem conta nova.

## O que não funcionou

A tabela completa está no [CHECKLIST](CHECKLIST.md). Os dois que mais ensinaram:

- **A memória do agente travava a conversa.** Na 3ª ou 4ª pergunta da mesma conversa, a
  chamada ao modelo ficava pendurada até o timeout — 30 s, depois 60 s, três tentativas. A
  mesma conversa, montada a partir da memória gravada e enviada **direto** à API da OpenAI,
  respondia em 1,7 s: o problema estava no caminho n8n/LangChain com um histórico cheio de
  chamadas de ferramenta (cada busca guardava ~4 KB de trechos). O modelo ainda passou a
  imitar um campo `id` que o histórico guardava. A memória passou a ser o próprio log: só as
  últimas 3 perguntas e respostas. Seis perguntas seguidas, ~3 s cada.
- **Citação inventada.** Ver *Decisões técnicas*.

## Tratamento de erro

| Falha | O que acontece |
|---|---|
| Documento novo, alterado ou apagado | Detectado pelo hash; só ele é reindexado ou removido. |
| Gravação dos trechos falha no meio | O recibo antigo fica com o hash antigo; a próxima execução vê o documento como "alterado" e refaz. Se corrige sozinho. |
| Pergunta fora da base | Resposta fixa "Não encontrei isso na base de conhecimento", registrada como `respondeu_da_base = false`. |
| Pergunta com dois assuntos | Uma busca por assunto (regra do prompt); testado em 3 rodadas. |
| OpenAI lenta | Timeout de 60 s com duas novas tentativas automáticas. |

## Pré-requisitos

1. Postgres com pgvector: `docker compose -f infra/docker-compose.yml --env-file .env build postgres` e `up -d postgres`.
2. Tabelas:
   ```bash
   docker cp workflows/03-agente-base-conhecimento/sql/001-base-conhecimento.sql n8n-postgres:/tmp/001-base-conhecimento.sql
   docker exec n8n-postgres psql -U n8n -d n8n -f /tmp/001-base-conhecimento.sql
   ```
3. Importar `workflow-indexacao.json` e `workflow-agente.json`, ligar as credenciais OpenAI e
   Postgres, rodar a indexação uma vez e ativar o agente.

## Como testar

Com a indexação rodada, abra o chat público do workflow 03b e pergunte:

| Pergunta | Esperado |
|---|---|
| Quanto tempo demora para liberar acesso ao ERP? | 3 dias úteis após a Controladoria · Fonte: acesso-a-sistemas.md |
| Perdi o notebook e o celular com o Authenticator. O que eu faço? | Boletim + chamado de Segurança + reset do MFA · duas fontes |
| Qual é o horário do refeitório? | "Não encontrei isso na base de conhecimento." |
| Como peço acesso ao CRM? → E quanto tempo leva? | A segunda é entendida pelo contexto: 2 dias úteis |

Para a indexação: rode duas vezes sem mudar nada (a segunda para em *Nada mudou*); edite um
`.md` (só ele é reindexado); tire um `.md` da pasta (os trechos dele somem).

## Resultado

*A preencher com os prints.* Até aqui: 5 documentos, 12 trechos; indexação idempotente
provada (igual, alterado, removido); 45 perguntas de teste, 41 respondidas pela base e 4
corretamente recusadas por estarem fora dela.

## Próximos passos

- [ ] Consultar esta mesma base a partir do atendimento do WhatsApp (workflow 05).
- [ ] Relatório semanal das perguntas sem resposta (`respondeu_da_base = false`).
- [ ] Error Workflow global.
