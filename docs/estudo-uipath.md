# Estudo — UiPath para os workflows 06 e 07

Para quem já trabalha com n8n, Power Automate, APIs e Python, e está começando no UiPath.
Os conceitos vêm comparados com o que você já conhece.

## As peças do UiPath

| Peça | O que é | Comparando com o que você já conhece |
|---|---|---|
| **Studio** | Onde você desenha o robô (arquivos `.xaml`) | O editor de workflows do n8n |
| **Robot** | Quem executa o robô numa máquina Windows | O "motor" que roda o fluxo — mas clicando na tela, como uma pessoa |
| **Orchestrator** | Painel central na nuvem: publica, agenda, dispara e monitora robôs, guarda filas e configurações | O n8n self-hosted inteiro (execuções, credenciais, agendamentos) — só que para robôs |

A diferença de fundo: n8n conversa com **APIs**; RPA opera **telas** (clica, digita, lê), para
sistemas que não têm API. Os dois se completam — é exatamente o que o workflow 07 mostra.

## Os conceitos que você pediu

### Queue (fila)

Uma lista de itens de trabalho guardada no Orchestrator. Cada item tem dados (ex.: código do
fornecedor e CEP) e um **status** que o Orchestrator controla: *New*, *In Progress*,
*Successful*, *Failed*, *Retried*...

Por que existe: se um robô processa 80 linhas de uma planilha e cai na 47ª, sem fila você não
sabe o que já foi feito. Com fila, cada item tem seu status gravado fora do robô; outro robô
continua do 48º, e dois robôs podem dividir a mesma fila.

> Parecido com a tabela de log + trava de idempotência que usamos nos workflows de n8n
> (`wa_message_id` único no workflow 05) — só que pronta, com tela e com novas tentativas.

O campo **Reference** de cada item, com "referência única" ligada na fila, impede item
duplicado: rodar o Dispatcher duas vezes com a mesma planilha não cria itens repetidos.

### Dispatcher e Performer

O jeito padrão de usar fila: **dois processos**.

- **Dispatcher**: só lê a origem (planilha, e-mail, sistema) e põe um item na fila para cada
  registro. Rápido e simples.
- **Performer**: pega um item por vez da fila, faz o trabalho pesado na tela e marca o status.

### REFramework (Robotic Enterprise Framework)

Um **modelo de projeto pronto** (template) que a UiPath oferece no Studio para o Performer. É
uma *máquina de estados* com quatro estados:

1. **Init** — lê configurações (`Config.xlsx` e Assets) e abre as aplicações.
2. **Get Transaction Data** — pega o próximo item da fila. Fila vazia → vai para o fim.
3. **Process** — faz o trabalho com aquele item. Aqui está quase todo o seu código.
4. **End Process** — fecha as aplicações.

O que ele já resolve sozinho: marcar o status de cada item, logar, **tentar de novo** quando
dá erro de sistema e **reiniciar as aplicações** antes de tentar. Você escreve basicamente o
estado *Process* e os passos de abrir/fechar aplicações.

> Pense no REFramework como um esqueleto de workflow de n8n que já viesse com Error Trigger,
> laço sobre os itens, log e novas tentativas configurados — e você só preenche o miolo.

### Business Exception × System Exception

A distinção mais importante do RPA, e a pergunta mais comum em entrevista.

| | Business Exception | System Exception |
|---|---|---|
| **Causa** | O **dado** está errado ou fora da regra | O **ambiente** falhou |
| **Exemplos** | CEP inexistente; CPF inválido; valor acima do limite de aprovação | Site fora do ar; tela não carregou; elemento não apareceu a tempo |
| **Tentar de novo resolve?** | **Não** — o CEP vai continuar inexistente | **Talvez** — o site pode voltar |
| **O que o REFramework faz** | Marca o item como falha de negócio e segue para o próximo | Reinicia as aplicações e devolve o item para nova tentativa, até o limite configurado |
| **Quem resolve** | Uma pessoa da área (corrigir o dado) | Normalmente ninguém — ou TI, se persistir |

Você lança uma Business Exception de propósito, com a atividade *Throw* e o tipo
`BusinessRuleException`, quando detecta um dado inválido. System Exception é qualquer outro
erro que acontece sozinho.

> No workflow 05 deste portfólio, o equivalente seria: JSON ilegível da IA (problema "de
> sistema", tentar de novo pode resolver) × cliente fora da lista de atendimento (regra de
> negócio, tentar de novo não muda nada).

### Asset

Uma **configuração guardada no Orchestrator**, que o robô lê na hora de rodar: um texto, um
número, um booleano ou uma **credencial** (usuário + senha, criptografados). Exemplos: URL do
site, e-mail para alertas, login do sistema.

Por que existe: mudar a URL ou trocar uma senha sem republicar o robô, e nunca deixar senha
dentro do `.xaml`.

> É a **credencial do n8n** (para segredos) somada a uma configuração editável fora do
> fluxo — a mesma regra das convenções deste repositório: segredo nunca dentro do nó.

### Trigger (no Orchestrator)

O que faz um processo rodar **sozinho**. Dois tipos principais:

- **Time Trigger** — por horário (ex.: Dispatcher toda segunda às 8h). = *Schedule Trigger*
  do n8n.
- **Queue Trigger** — quando chegam itens novos numa fila, o Orchestrator dispara o
  Performer automaticamente, e pode subir mais de um robô se a fila crescer.

E existe o terceiro jeito, sem trigger: chamar a **API** do Orchestrator — que é o workflow 07.

## Plano intensivo: 2 semanas (10 dias úteis, 2–3 h por dia)

Estratégia: **aprender construindo** o 06 e o 07, não fazer a trilha completa da Academy
(~33 h). Cada dia tem um objetivo concreto que termina com algo rodando; o curso entra só
como referência do tópico do dia. Ficam de fora por enquanto: Integration Service, Object
Repository, testes automatizados, controle de versão e a certificação.

Antes do dia 1 (~30 min): criar a conta gratuita no **UiPath Automation Cloud** (plano
Community) e instalar o **UiPath Studio**.

### Semana 1 — Studio, Orchestrator e o Dispatcher

| Dia | Objetivo do dia (mão na massa) | Referência na Academy |
|---|---|---|
| **1** | Primeiro robô: ler uma planilha e mostrar cada linha no log. Entender variáveis, `For Each Row` e `If`. | Primeiros cursos do *Automation Developer Associate Training* (Studio, variáveis, controle de fluxo) |
| **2** | Automação de tela: abrir o site de consulta de CEP, digitar um CEP e ler o resultado. Entender **seletores** (como o robô acha um botão na tela). | Curso de automação de interface e seletores, do mesmo plano |
| **3** | Juntar 1 + 2: para cada linha da planilha, consultar o CEP. Envolver em `Try Catch` e lançar uma **Business Exception** de propósito quando o CEP não existe. Log em cada passo. | Cursos de tratamento de erros e logging |
| **4** | Orchestrator: publicar o robô, rodar como **job** pela nuvem e trocar a URL do site por um **Asset**. | *Orchestrator Overview for Automation Developers* |
| **5** | **Dispatcher do 06**: criar a **Queue** com referência única e o processo que lê a planilha e adiciona os itens. Rodar duas vezes e ver que não duplica. | *Working with Orchestrator Resources as an Automation Developer* (filas e transações) |

### Semana 2 — REFramework, Performer e a ponte com o n8n

| Dia | Objetivo do dia (mão na massa) | Referência na Academy |
|---|---|---|
| **6** | Abrir o template **REFramework**, entender os 4 estados rodando-o contra a fila do dia 5 só com log, sem alterar o *Process*. | *Introduction to Robotic Enterprise Framework* (focar em estados e exceções) |
| **7** | **Performer do 06**: colocar a consulta de CEP do dia 3 dentro do estado *Process*; Business × System Exception de verdade. | *Building a REFramework Project with Orchestrator Queues* |
| **8** | Testar o 06 com CEPs válidos, inexistentes e malformados; derrubar a internet no meio para ver a System Exception e a nova tentativa. Configurar um **Queue Trigger**. Prints. | — |
| **9** | API: criar a **External Application**, instalar o Python e rodar `orchestrator_api.py` (`--token`, `--pastas`, `--listar`, `--disparar`). | Documentação de External Applications |
| **10** | **Workflow 07 no n8n**: os mesmos passos do script como nós HTTP Request, polling com limite e log no Postgres. Prints e README. | — |

Se um dia atrasar, o corte é: o Queue Trigger do dia 8 e o log no Postgres do dia 10 podem
ficar para depois sem quebrar nada.

Para uma visão mais ampla depois do prazo, a trilha completa é o plano **Automation
Developer Associate Training**, que prepara para a certificação UiPath Automation Developer
Associate (UiADA).

### Cursos citados (links)

- [Automation Developer Associate Training](https://academy.uipath.com/learning-plans/automation-developer-associate-training-v202210) — plano de estudo base (há versões 2023.10 e 2024.10; prefira a mais recente)
- [Working with Orchestrator Resources as an Automation Developer](https://academy.uipath.com/courses/working-with-orchestrator-resources-as-an-automation-developer-v2024-10)
- [Introduction to Robotic Enterprise Framework](https://academy.uipath.com/courses/introduction-to-robotic-enterprise-framework)
- [Building a REFramework Project with Orchestrator Queues](https://academy.uipath.com/courses/build-a-reframework-project-with-orchestrator-queues-)
- [Autenticação com External Application (documentação)](https://docs.uipath.com/orchestrator/automation-cloud/latest/user-guide/authenticating-with-an-external-application)

## Perguntas que caem em entrevista

- **Business × System Exception:** ver a tabela acima — a resposta curta é "dado errado ×
  ambiente falhou; só o segundo merece nova tentativa".
- **Por que usar fila em vez de ler a planilha direto?** Estado de cada item fora do robô,
  retomada depois de falha, paralelismo entre robôs, histórico no Orchestrator.
- **O que você colocaria em Asset e o que em Config.xlsx?** Asset: o que muda por ambiente ou
  é segredo (URL, credencial). Config: parâmetros do processo (nomes de fila, tentativas,
  textos).
- **Quando RPA e quando API?** API sempre que existir — é mais rápida e não quebra quando a
  tela muda. RPA para sistemas sem API.
