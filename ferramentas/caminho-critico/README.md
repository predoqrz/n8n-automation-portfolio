# Caminho crítico

Calcula a duração mínima de um projeto a partir de uma lista de tarefas com
dependências, e aponta quais delas não podem atrasar.

Script em Python puro, sem dependências externas.

## O problema

Todo cronograma tem a mesma armadilha: somar a duração de todas as tarefas e
achar que aquilo é o prazo. Não é. Tarefas que rodam em paralelo contam uma vez
só, e o prazo real é definido pela sequência mais longa que atravessa o projeto
do começo ao fim.

Essa sequência é o caminho crítico. As tarefas que estão nela não têm folga: se
qualquer uma atrasar um dia, o projeto inteiro atrasa um dia. As que estão fora
dela têm uma margem, e saber de quanto é essa margem muda a forma de priorizar
quando algo dá errado no meio da execução.

Calcular isso na mão em quatro tarefas é fácil. Em quarenta, com dependências
cruzadas, ninguém acerta de cabeça.

## Como usar

```bash
python caminho_critico.py --exemplo          # roda o caso de demonstração
python caminho_critico.py tarefas.json
python caminho_critico.py tarefas.csv
```

### Saída

```
   id    tarefa               dur  inicio    fim  folga
-------------------------------------------------------
>> A     Desligar a maquina     2       0      2      0
   B     Trocar a peca          3       2      5      1
>> C     Pintar a estrutura     4       2      6      0
>> D     Testar e religar       1       6      7      0
-------------------------------------------------------

Duracao minima do projeto: 7 dias
Caminho critico: A -> C -> D

Tarefas com folga (podem atrasar sem mexer no prazo final):
  B: 1 dias
```

O `>>` marca as tarefas sem folga. B e C rodam ao mesmo tempo, então vale a mais
longa das duas: 2 + 4 + 1 = 7, e não 2 + 3 + 4 + 1 = 10.

## Formato de entrada

JSON:

```json
[
  {"id": "A", "nome": "Desligar a máquina", "duracao": 2, "depende_de": []},
  {"id": "B", "nome": "Trocar a peça",      "duracao": 3, "depende_de": ["A"]},
  {"id": "C", "nome": "Pintar a estrutura", "duracao": 4, "depende_de": ["A"]},
  {"id": "D", "nome": "Testar e religar",   "duracao": 1, "depende_de": ["B", "C"]}
]
```

CSV, com dependências separadas por ponto e vírgula:

```csv
id,nome,duracao,depende_de
A,Desligar a máquina,2,
B,Trocar a peça,3,A
C,Pintar a estrutura,4,A
D,Testar e religar,1,B;C
```

Os campos `id` e `duracao` são obrigatórios. O `nome` é opcional e vira o próprio
id quando fica em branco. A unidade da duração é livre: se você informar horas, o
resultado sai em horas.

## Como funciona

Duas passagens sobre as tarefas, depois de ordená-las por dependência
(ordenação topológica pelo algoritmo de Kahn).

Na ida, cada tarefa começa assim que a última predecessora dela termina. Isso dá
o início e o fim mais cedo possíveis de cada uma, e o maior fim encontrado é a
duração do projeto.

Na volta, partindo do fim, calcula-se o quanto cada tarefa poderia atrasar sem
empurrar nada à frente. A diferença entre o início mais tarde e o início mais
cedo é a folga. Folga zero significa caminho crítico.

## Tratamento de erro

O script recusa a entrada e explica o motivo em vez de devolver número errado:

| Situação | Mensagem |
|---|---|
| Dependência que não existe na lista | `Tarefa B depende de 'Z', que nao existe na lista.` |
| Dependência circular | `Dependencia circular entre as tarefas: B, C.` |
| Tarefa que depende de si mesma | `Tarefa A depende de si mesma.` |
| Duração não numérica | `Tarefa A: duracao 'tres' nao e um numero.` |
| Duração negativa | `Tarefa A: duracao negativa (-2).` |
| Id repetido | `Id repetido: A.` |
| CSV sem as colunas obrigatórias | `CSV sem as colunas obrigatorias: duracao.` |

Em qualquer um desses casos a saída vai para `stderr` e o código de retorno é 1,
o que permite usar o script dentro de um pipeline sem que uma entrada quebrada
passe despercebida.

## Detalhe sobre caminhos empatados

Quando dois caminhos têm exatamente a mesma duração, os dois são críticos. O
script imprime uma das cadeias e lista as demais tarefas sem folga logo abaixo,
em vez de escolher uma e esconder a outra.
