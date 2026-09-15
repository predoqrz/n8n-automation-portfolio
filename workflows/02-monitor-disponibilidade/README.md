# 02 — Monitor de disponibilidade com relatório diário

**Status:** 🔜 Planejado
**Integrações:** HTTP Request · PostgreSQL · Slack ou Teams · e-mail
**Competências demonstradas:** Schedule Trigger, loop sobre lista, persistência em banco,
agregação de dados, alerta com controle de ruído

## O problema

Quando um serviço cai, a descoberta costuma vir pelo usuário reclamando. Entre a queda e
o aviso passam minutos ou horas, e ninguém tem histórico para responder à pergunta
"quanto esse serviço ficou fora no mês passado?".

## A solução

Verificação periódica de uma lista de endpoints, alerta imediato na mudança de estado e
resumo consolidado no início do dia.

```mermaid
flowchart TD
    A[Schedule · a cada 5 min] --> B[Carregar lista de serviços]
    B --> C[Testar cada endpoint]
    C --> D[Gravar resultado no Postgres]
    D --> E{Mudou de estado?}
    E -->|caiu| F[Alerta imediato]
    E -->|voltou| G[Aviso de recuperação]
    E -->|sem mudança| H[Fim]
    I[Schedule · 08:00] --> J[Consultar últimas 24h]
    J --> K[Montar resumo]
    K --> L[Enviar relatório]
```

## Ponto de atenção

Alertar a cada verificação enquanto o serviço está fora gera spam e faz o time ignorar o
canal. O alerta deve disparar na **transição** de estado, não no estado. Isso exige
comparar o resultado atual com o último registro no banco.

## A preencher durante a construção

- [ ] Schema da tabela de checks
- [ ] Query de agregação do relatório
- [ ] Decisões técnicas
- [ ] Print do relatório gerado
