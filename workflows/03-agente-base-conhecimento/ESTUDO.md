# Estudo — como o RAG deste workflow funciona

Roteiro para entender o workflow 03 por dentro, mexendo nele. Cerca de 20 minutos.

## A ideia em uma frase

**RAG = buscar os trechos certos pelo significado + mandar a IA responder só com eles + citar
de onde veio.** (*Retrieval-Augmented Generation*: geração aumentada por busca.)

Sem isso, um modelo como o ChatGPT não conhece os procedimentos da *sua* empresa e inventa
uma resposta plausível — o pior cenário para um procedimento interno.

## As duas fases

**Indexação (03a), uma vez e quando um documento muda**

1. Lê os `.md` da pasta `base-conhecimento/`.
2. Divide cada documento em trechos de ~800 caracteres (5 documentos → 12 trechos). A IA
   não precisa do documento inteiro, só do pedaço que responde.
3. Transforma cada trecho num **embedding**: uma lista de 1.536 números que representa o
   *significado* do texto.
4. Guarda trecho + embedding no Postgres (`kb_chunks`, com pgvector).

**Consulta (03b), a cada pergunta**

1. A pergunta também vira um embedding.
2. O Postgres acha os 4 trechos cujos embeddings estão mais próximos do da pergunta.
3. A IA recebe a pergunta + esses 4 trechos e a ordem: responda só com isto, cite a fonte.

## O que é "próximo"

Textos com significado parecido têm embeddings parecidos, **mesmo com palavras diferentes**.
"Quanto tempo leva pra liberar o ERP?" acha o trecho "ERP (financeiro e estoque) |
Controladoria | 3 dias úteis" sem que a pergunta tenha "Controladoria" nem "dias úteis".
Uma busca por palavra-chave falharia.

Resultado real desta base (distância menor = mais parecido):

| Pergunta | 1º trecho | Distância | Leitura |
|---|---|---|---|
| quanto tempo leva pra liberar o ERP? | tabela de aprovações (acesso-a-sistemas.md) | **0,403** | Destaca-se dos outros (0,55+): a base responde |
| qual o horário do refeitório? | equipamentos.md | 0,664 | Todos entre 0,66 e 0,69, nenhum se destaca: a base não cobre |

Detalhe importante do segundo caso: a busca **sempre** devolve 4 trechos — os "menos piores".
Quem decide se eles servem é a IA, guiada pelo prompt ("senão, diga *Não encontrei*").
Sem essa regra, ela forçaria uma resposta com trechos de equipamentos e chamados.

## Exercícios

- [ ] **1. Veja a busca por dentro.** Da raiz do repositório:
      ```bash
      node workflows/03-agente-base-conhecimento/scripts/demo-busca.mjs "minha senha bloqueou"
      ```
      No Windows, se o `docker` não estiver no PATH, defina antes `DOCKER_BIN` com o caminho
      do `docker.exe`. Teste a mesma pergunta escrita de jeitos diferentes: o 1º trecho muda?
- [ ] **2. Ensine algo novo à base.** Crie `base-conhecimento/refeitorio.md` dizendo que o
      refeitório abre das 11h às 14h. No n8n, abra o **03a** e clique em **Execute workflow**.
      Pergunte no chat de novo: agora ele responde, com a fonte. Apague o arquivo, rode o 03a
      outra vez — ele "esquece". Rode o script do exercício 1 antes e depois e compare as
      distâncias.
- [ ] **3. Olhe os nós depois de uma execução.** No 03a, clique em *Dividir em trechos* e veja
      os 12 trechos. No 03b, depois de uma pergunta, clique em *Buscar na base de
      conhecimento* e veja os 4 trechos que a IA recebeu.
- [ ] **4. Quebre de propósito.** No prompt do *Agente de TI*, apague o parágrafo "Quando a
      base não cobre a pergunta" e pergunte sobre o refeitório. Veja a IA forçar uma resposta.
      Depois desfaça.

## Perguntas que caem em entrevista

- **Por que dividir em trechos?** O modelo responde melhor com o pedaço certo do que com o
  documento inteiro, e o custo por pergunta cai.
- **O que acontece se a resposta cair entre dois trechos?** Por isso há sobreposição (120
  caracteres) entre trechos vizinhos.
- **Como evitar que a IA invente?** Prompt que só permite responder com os trechos, frase fixa
  para "não encontrei", citação obrigatória e temperatura 0.
- **Como saber o que falta documentar?** O log marca `respondeu_da_base = false` em cada
  pergunta recusada.
