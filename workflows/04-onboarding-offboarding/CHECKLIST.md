# Checklist — workflow 04

**Onde eu parei:** os três workflows funcionando e testados ponta a ponta (26/10/2026). Faltam os
prints em `assets/` e o merge na `main` (manual, pelo Pedro)

---

## Etapa 0 — banco ✅

- [x] Diretório simulado (`dir_*`) e controle do processo (`rh_*`)
- [x] "API" simulada em funções SQL, com falha quando o sistema está indisponível
- [x] Funções de retomada (`rh_etapa_feita`, `rh_registrar_etapa`) e de compensação
      (`rh_reverter_admissao`), testadas numa transação desfeita

## Etapa 1 — workflows ✅

- [x] 04a · Solicitação (16 nós), 04b · Admissão (10), 04c · Desligamento (12)
- [x] Versões dos nós conferidas nas definições do n8n antes de escrever

## Etapa 2 — testes ✅

- [x] Admissão completa
- [x] Mesmo formulário duas vezes → uma solicitação só
- [x] Admissão com sistema fora do ar → rollback de tudo o que foi concedido
- [x] Reenvio depois da falha → conclui
- [x] Desligamento aprovado pelo link assinado → tudo revogado e conta arquivada
- [x] Desligamento recusado → nada muda
- [x] Desligamento com sistema fora do ar → interrompido; reenvio retoma sem nova aprovação
- [x] Desligamento de conta inexistente → recusado com motivo
- [x] Regressão depois das correções: zero execuções com erro

## Etapa 3 — fechar

- [ ] Prints em `assets/`: formulário, mensagem de aprovação no Discord, formulário de
      aprovação, canvas dos três workflows
- [ ] README: Resultado com os prints
- [ ] Merge na `main` (manual, pelo Pedro)

---

## O que já quebrou

| Etapa | O que | Sintoma | Solução |
|---|---|---|---|
| 1 | Sub-workflow de desligamento recebia só o resultado da decisão | Sem nome e login para executar | O registro da decisão devolve os dados do colaborador |
| 2 | Item da saída de erro não carrega os dados de entrada | Rollback com motivo vazio (`texto \|\| NULL` vira NULL no SQL) | Sistema que falhou buscado pelo item de origem: `$('Um sistema por vez').item` |
| 2 | Testador montava a URL de aprovação sem a assinatura | HTTP 401 | Não era bug: o n8n assina a URL de retomada. Testador passou a usar a URL enviada ao gestor |
| 2 | Testador enviava o valor do campo *radio* como texto puro, e o `curl -F` tirava as aspas | `"Aprovar" is not valid JSON`, HTTP 500 | O navegador envia JSON; testador com `--form-string` |
| 2 | Conclusão limpava o campo `motivo` para apagar falhas antigas | O motivo da aprovação do gestor sumia | Colunas separadas: `motivo` (decisão) e `erro` (falha técnica) |
| 2 | Pedido de desligamento de conta inexistente | Ficava como `recebida`, parecendo pendente | Nó *Registrar descarte*: fica `recusada`, com o motivo |
