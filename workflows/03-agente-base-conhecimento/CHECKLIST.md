# Checklist — workflow 03

**Onde eu parei:** concluído (22/10/2026). Falta só o merge na `main` (manual, pelo Pedro).
Estudo pendente: exercícios em [ESTUDO.md](ESTUDO.md)

---

## Etapa 0 — ambiente ✅

- [x] pgvector 0.8.7 compilado na imagem Postgres Alpine (`infra/postgres/Dockerfile`)
- [x] Backup completo antes da troca; contagens conferidas depois (4 workflows, 8 credenciais,
      1.416 checagens, 45 mensagens, 5 triagens — idênticas)
- [x] Pasta da base montada só leitura no n8n; `N8N_RESTRICT_FILE_ACCESS_TO=/files`

## Etapa 1 — base de conhecimento ✅

- [x] 5 documentos fictícios com números verificáveis (prazos, quantidades, aprovadores)
- [x] `sql/001-base-conhecimento.sql`: trechos com índice HNSW, recibos, log de conversas

## Etapa 2 — indexação (03a) ✅

- [x] 5 documentos → 12 trechos, metadados `fonte`, `titulo`, `citar_como`
- [x] Rodar de novo sem mudar nada → "Nada mudou", sem chamar a OpenAI
- [x] Documento alterado → só ele reindexado
- [x] Documento removido → trechos e recibo apagados
- [x] Restaurado → detectado e reindexado

## Etapa 3 — agente (03b) ✅

- [x] Pergunta na base → resposta certa + fonte
- [x] Pergunta com dois assuntos → os dois documentos (3 de 3 rodadas)
- [x] Fora da base (refeitório, férias) → "Não encontrei isso na base de conhecimento"
- [x] Saudação → resposta curta, sem busca
- [x] Pergunta de acompanhamento → entendida pelo contexto
- [x] 6 perguntas seguidas na mesma conversa, ~3 s cada

## Etapa 4 — fechar

- [x] Prints em `assets/` (chat, canvas da indexação, canvas do agente)
- [x] README: Resultado com os prints
- [ ] Merge na `main` (manual, pelo Pedro)

---

## O que já quebrou

| Etapa | O que | Sintoma | Solução |
|---|---|---|---|
| 0 | Imagem oficial do pgvector é Debian; o banco foi criado no Alpine | Risco de índices de texto inconsistentes (collation musl × glibc), sem erro visível | pgvector compilado na mesma imagem Alpine |
| 0 | n8n 2 só lê arquivos de `~/.n8n-files` | Pego antes de rodar, lendo a configuração do n8n | `N8N_RESTRICT_FILE_ACCESS_TO=/files` |
| 2 | `n8n execute` dentro do container | *Task Broker's port 5679 is already in use* | O CLI sobe um segundo n8n; rodar com `N8N_RUNNERS_BROKER_PORT` diferente |
| 3 | Timeout da OpenAI em 30 s | 3 perguntas seguidas com "Error in workflow" | Timeout para 60 s — mas não era a causa (ver abaixo) |
| 3 | Citação montada pelo modelo | "(blob)" no lugar do arquivo; depois, nomes de arquivo inventados a partir do título | Campo `citar_como` pronto em cada trecho; o modelo só copia. 3 de 3 |
| 3 | Memória do agente (nó Postgres Chat Memory) | A partir da 3ª/4ª pergunta da mesma conversa, a chamada ao modelo travava até o timeout. A mesma conversa direto na API da OpenAI respondia em 1,7 s | Memória feita com o próprio log (últimas 3 perguntas e respostas, sem os trechos de cada busca) |
| 3 | Pergunta com dois assuntos, depois da troca da memória | Respondeu só um dos assuntos (uma busca só) | Regra no prompt: uma busca por assunto. 3 de 3 |
