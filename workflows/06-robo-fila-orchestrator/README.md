# 06 — Robô de consulta com fila no Orchestrator (Dispatcher/Performer)

**Status:** 🔜 Planejado
**Tempo de construção:** —
**Integrações:** UiPath Studio · UiPath Orchestrator (Automation Cloud, plano Community) ·
Excel · navegador (consulta de CEP)
**Competências demonstradas:** modelo Dispatcher/Performer, Queues no Orchestrator,
REFramework, tratamento de Business Exception × System Exception, Assets

## O problema

O cadastro de fornecedores recebe toda semana uma planilha com dezenas de novos fornecedores,
cada um com um CEP. Alguém do administrativo abre um site de consulta de CEP, digita um por
um, copia logradouro, bairro e cidade para a planilha e marca os CEPs que não existem para
devolver ao comprador. Com 80 linhas por semana e cerca de 1 minuto por linha, são quase
**1h30 semanais** de digitação — e um CEP copiado errado só aparece quando a nota fiscal volta.

O trabalho é repetitivo, baseado em tela e com regras claras: o caso clássico de RPA. Mas
fazer tudo num robô só tem dois problemas. Se o robô cair na linha 47, as 46 anteriores
ficam sem registro do que já foi feito. E não há como dividir o volume entre dois robôs.

## A solução

Dois processos separados, ligados por uma **Queue** do Orchestrator. O **Dispatcher** só lê a
planilha e põe cada fornecedor na fila. O **Performer** (construído sobre o REFramework) pega
um item por vez, consulta o CEP e marca o item como sucesso, *Business Exception* (CEP
inexistente: problema do dado, não adianta repetir) ou *System Exception* (site fora do ar:
problema do ambiente, vale tentar de novo).

```mermaid
flowchart TD
    subgraph Dispatcher
        A[Ler planilha de fornecedores] --> B[Para cada linha]
        B --> C[Add Queue Item<br/>Reference = código do fornecedor]
    end

    C --> Q[(Queue no Orchestrator<br/>CadastroFornecedores)]

    subgraph Performer · REFramework
        I[Init<br/>ler Assets, abrir navegador] --> G[Get Transaction Data<br/>pegar próximo item da fila]
        G -->|fila vazia| E[End Process<br/>fechar navegador]
        G -->|item| P[Process<br/>consultar CEP, gravar resultado]
        P -->|ok| S[Successful]
        P -->|CEP inexistente ou inválido| BE[Business Exception<br/>sem nova tentativa]
        P -->|site fora, tela não carregou| SE[System Exception<br/>reinicia apps e tenta de novo]
        S --> G
        BE --> G
        SE --> I
    end

    Q --> G
```

## Os nós, em ordem

*A preencher durante a construção: workflows do Dispatcher e do Performer (`.xaml`), estados
do REFramework alterados e o arquivo `Config.xlsx`.*

## Decisões técnicas

- **Por que Dispatcher e Performer separados, e não um robô só:** a fila guarda o estado de
  cada item no Orchestrator. Se o Performer cair, os itens já processados ficam marcados e o
  próximo robô continua de onde parou; e dois Performers podem consumir a mesma fila em
  paralelo.
- **Por que `Reference` = código do fornecedor:** com a opção de referência única na Queue,
  rodar o Dispatcher duas vezes com a mesma planilha não duplica itens — a mesma ideia de
  idempotência dos workflows de n8n deste portfólio.
- **Por que REFramework no Performer:** ele já traz pronto o ciclo de vida de uma transação
  (pegar item, processar, marcar status, tentar de novo em erro de sistema, reiniciar
  aplicações). Escrever isso do zero seria reinventar e errar.
- **Por que consulta de CEP:** site público, sem login e sem CAPTCHA, com os dois tipos de
  erro acontecendo naturalmente (CEP que não existe × site lento ou fora do ar).

## Tratamento de erro

| Situação | Tipo | O que o robô faz |
|---|---|---|
| CEP com formato inválido ou inexistente | Business Exception | Marca o item como falha de negócio, sem nova tentativa |
| Site não carrega, elemento não aparece no tempo | System Exception | Fecha e reabre o navegador; o item volta para a fila até o limite de tentativas |
| Fila vazia | — | Encerra normalmente |

## Como testar

*A preencher: planilha de exemplo com CEPs válidos, inexistentes e malformados.*

## Resultado

*A preencher.*

## Próximos passos

- [ ] Disparar o Performer pelo n8n (workflow 07).
- [ ] Gravar o resultado também no Postgres do portfólio.
