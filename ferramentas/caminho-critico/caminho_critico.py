#!/usr/bin/env python3
"""
Calcula o caminho crítico (CPM) de uma lista de tarefas com dependências.

Responde três perguntas que aparecem em qualquer cronograma:
  - em quantos dias, no mínimo, o projeto termina;
  - quais tarefas, se atrasarem um dia, atrasam o projeto inteiro;
  - quanta folga cada uma das outras tem.

Uso:
    python caminho_critico.py tarefas.json
    python caminho_critico.py tarefas.csv
    python caminho_critico.py --exemplo

Formato JSON:
    [
      {"id": "A", "nome": "Desligar a maquina", "duracao": 2, "depende_de": []},
      {"id": "B", "nome": "Trocar a peca",      "duracao": 3, "depende_de": ["A"]}
    ]

Formato CSV (cabecalho obrigatorio, dependencias separadas por ponto e virgula):
    id,nome,duracao,depende_de
    A,Desligar a maquina,2,
    B,Trocar a peca,3,A
    D,Testar e religar,1,B;C

Sem dependencias externas. Python 3.8 ou superior.
"""

from __future__ import annotations

import csv
import json
import sys
from dataclasses import dataclass, field
from pathlib import Path


class ErroDeEntrada(Exception):
    """Problema nos dados informados, nao no calculo."""


@dataclass
class Tarefa:
    id: str
    nome: str
    duracao: float
    depende_de: list[str] = field(default_factory=list)

    # preenchidos pelo calculo
    inicio_cedo: float = 0.0
    fim_cedo: float = 0.0
    inicio_tarde: float = 0.0
    fim_tarde: float = 0.0

    @property
    def folga(self) -> float:
        return round(self.inicio_tarde - self.inicio_cedo, 6)

    @property
    def critica(self) -> bool:
        return abs(self.folga) < 1e-9


# --------------------------------------------------------------------------
# Leitura e validacao
# --------------------------------------------------------------------------

def ler_json(caminho: Path) -> list[Tarefa]:
    try:
        bruto = json.loads(caminho.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        raise ErroDeEntrada(f"JSON invalido em {caminho}: {e}") from e
    if not isinstance(bruto, list):
        raise ErroDeEntrada("O JSON precisa ser uma lista de tarefas.")
    return [_monta_tarefa(item, i) for i, item in enumerate(bruto, 1)]


def ler_csv(caminho: Path) -> list[Tarefa]:
    with caminho.open(encoding="utf-8-sig", newline="") as f:
        leitor = csv.DictReader(f)
        if leitor.fieldnames is None:
            raise ErroDeEntrada("CSV vazio ou sem cabecalho.")
        faltando = {"id", "duracao"} - {c.strip().lower() for c in leitor.fieldnames}
        if faltando:
            raise ErroDeEntrada(
                f"CSV sem as colunas obrigatorias: {', '.join(sorted(faltando))}."
            )
        linhas = []
        for i, linha in enumerate(leitor, 2):  # linha 1 e o cabecalho
            normalizada = {(k or "").strip().lower(): (v or "").strip()
                           for k, v in linha.items()}
            deps = normalizada.get("depende_de", "")
            normalizada["depende_de"] = [d.strip() for d in deps.split(";") if d.strip()]
            linhas.append(_monta_tarefa(normalizada, i))
    return linhas


def _monta_tarefa(item: dict, posicao: int) -> Tarefa:
    if not isinstance(item, dict):
        raise ErroDeEntrada(f"Item {posicao} nao e um objeto de tarefa.")

    tid = str(item.get("id", "")).strip()
    if not tid:
        raise ErroDeEntrada(f"Item {posicao} esta sem id.")

    try:
        duracao = float(item.get("duracao", 0))
    except (TypeError, ValueError):
        raise ErroDeEntrada(
            f"Tarefa {tid}: duracao '{item.get('duracao')}' nao e um numero."
        ) from None
    if duracao < 0:
        raise ErroDeEntrada(f"Tarefa {tid}: duracao negativa ({duracao}).")

    deps = item.get("depende_de") or []
    if isinstance(deps, str):
        deps = [d.strip() for d in deps.split(";") if d.strip()]
    deps = [str(d).strip() for d in deps if str(d).strip()]

    nome = str(item.get("nome", "") or tid).strip()
    return Tarefa(id=tid, nome=nome, duracao=duracao, depende_de=deps)


def validar(tarefas: list[Tarefa]) -> dict[str, Tarefa]:
    if not tarefas:
        raise ErroDeEntrada("Nenhuma tarefa informada.")

    porid: dict[str, Tarefa] = {}
    for t in tarefas:
        if t.id in porid:
            raise ErroDeEntrada(f"Id repetido: {t.id}.")
        porid[t.id] = t

    for t in tarefas:
        if t.id in t.depende_de:
            raise ErroDeEntrada(f"Tarefa {t.id} depende de si mesma.")
        for d in t.depende_de:
            if d not in porid:
                raise ErroDeEntrada(
                    f"Tarefa {t.id} depende de '{d}', que nao existe na lista."
                )
    return porid


def ordem_topologica(tarefas: list[Tarefa], porid: dict[str, Tarefa]) -> list[Tarefa]:
    """Kahn. Levanta erro se houver ciclo, apontando as tarefas envolvidas."""
    restantes = {t.id: len(t.depende_de) for t in tarefas}
    sucessores: dict[str, list[str]] = {t.id: [] for t in tarefas}
    for t in tarefas:
        for d in t.depende_de:
            sucessores[d].append(t.id)

    fila = [tid for tid, n in restantes.items() if n == 0]
    if not fila:
        raise ErroDeEntrada(
            "Toda tarefa depende de alguma outra. Ha um ciclo e nenhuma pode comecar."
        )

    ordem: list[Tarefa] = []
    while fila:
        tid = fila.pop(0)
        ordem.append(porid[tid])
        for s in sucessores[tid]:
            restantes[s] -= 1
            if restantes[s] == 0:
                fila.append(s)

    if len(ordem) < len(tarefas):
        presas = sorted(tid for tid, n in restantes.items() if n > 0)
        raise ErroDeEntrada(
            "Dependencia circular entre as tarefas: " + ", ".join(presas) + "."
        )
    return ordem


# --------------------------------------------------------------------------
# Calculo
# --------------------------------------------------------------------------

def calcular(tarefas: list[Tarefa]) -> dict:
    porid = validar(tarefas)
    ordem = ordem_topologica(tarefas, porid)

    # Ida: a tarefa comeca assim que a ultima predecessora termina.
    for t in ordem:
        t.inicio_cedo = max((porid[d].fim_cedo for d in t.depende_de), default=0.0)
        t.fim_cedo = t.inicio_cedo + t.duracao

    duracao_total = max(t.fim_cedo for t in ordem)

    sucessores: dict[str, list[str]] = {t.id: [] for t in tarefas}
    for t in tarefas:
        for d in t.depende_de:
            sucessores[d].append(t.id)

    # Volta: o quanto cada tarefa pode atrasar sem empurrar o fim do projeto.
    for t in reversed(ordem):
        t.fim_tarde = min(
            (porid[s].inicio_tarde for s in sucessores[t.id]), default=duracao_total
        )
        t.inicio_tarde = t.fim_tarde - t.duracao

    criticas = [t for t in ordem if t.critica]
    return {
        "duracao_total": duracao_total,
        "tarefas": ordem,
        "criticas": criticas,
        "caminho": _uma_cadeia_critica(criticas, porid),
        "sucessores": sucessores,
    }


def _uma_cadeia_critica(criticas: list[Tarefa], porid: dict[str, Tarefa]) -> list[str]:
    """Uma cadeia critica do inicio ao fim. Pode haver outras de mesma duracao."""
    if not criticas:
        return []
    ids_criticos = {t.id for t in criticas}
    atual = next(
        (t for t in criticas if not (ids_criticos & set(t.depende_de))), criticas[0]
    )
    cadeia = [atual.id]
    while True:
        seguinte = next(
            (
                t
                for t in criticas
                if atual.id in t.depende_de
                and abs(t.inicio_cedo - atual.fim_cedo) < 1e-9
            ),
            None,
        )
        if seguinte is None:
            return cadeia
        cadeia.append(seguinte.id)
        atual = seguinte


# --------------------------------------------------------------------------
# Saida
# --------------------------------------------------------------------------

def _fmt(v: float) -> str:
    return str(int(v)) if float(v).is_integer() else f"{v:.2f}"


def imprimir(r: dict, unidade: str = "dias") -> None:
    tarefas = r["tarefas"]
    larg_nome = max(12, min(34, max(len(t.nome) for t in tarefas)))

    cab = f"{'':2} {'id':<5} {'tarefa':<{larg_nome}} {'dur':>5} {'inicio':>7} {'fim':>6} {'folga':>6}"
    print()
    print(cab)
    print("-" * len(cab))
    for t in tarefas:
        marca = ">>" if t.critica else "  "
        print(
            f"{marca} {t.id:<5} {t.nome[:larg_nome]:<{larg_nome}} "
            f"{_fmt(t.duracao):>5} {_fmt(t.inicio_cedo):>7} {_fmt(t.fim_cedo):>6} "
            f"{_fmt(t.folga):>6}"
        )
    print("-" * len(cab))
    print(f"\nDuracao minima do projeto: {_fmt(r['duracao_total'])} {unidade}")

    if r["caminho"]:
        print("Caminho critico: " + " -> ".join(r["caminho"]))

    nomes_criticos = {t.id for t in r["criticas"]}
    if len(nomes_criticos) > len(r["caminho"]):
        extras = sorted(nomes_criticos - set(r["caminho"]))
        print("Outras tarefas sem folga: " + ", ".join(extras))

    folgadas = [t for t in tarefas if not t.critica]
    if folgadas:
        print("\nTarefas com folga (podem atrasar sem mexer no prazo final):")
        for t in sorted(folgadas, key=lambda x: -x.folga):
            print(f"  {t.id}: {_fmt(t.folga)} {unidade}")
    else:
        print("\nNenhuma tarefa tem folga. Qualquer atraso empurra o projeto.")
    print()


EXEMPLO = [
    {"id": "A", "nome": "Desligar a maquina", "duracao": 2, "depende_de": []},
    {"id": "B", "nome": "Trocar a peca", "duracao": 3, "depende_de": ["A"]},
    {"id": "C", "nome": "Pintar a estrutura", "duracao": 4, "depende_de": ["A"]},
    {"id": "D", "nome": "Testar e religar", "duracao": 1, "depende_de": ["B", "C"]},
]


def main(argv: list[str]) -> int:
    if len(argv) != 2 or argv[1] in {"-h", "--help"}:
        print(__doc__)
        return 0 if len(argv) == 2 else 1

    arg = argv[1]
    try:
        if arg == "--exemplo":
            tarefas = [_monta_tarefa(i, n) for n, i in enumerate(EXEMPLO, 1)]
        else:
            caminho = Path(arg)
            if not caminho.exists():
                raise ErroDeEntrada(f"Arquivo nao encontrado: {caminho}")
            if caminho.suffix.lower() == ".json":
                tarefas = ler_json(caminho)
            elif caminho.suffix.lower() in {".csv", ".txt"}:
                tarefas = ler_csv(caminho)
            else:
                raise ErroDeEntrada(
                    f"Extensao '{caminho.suffix}' nao suportada. Use .json ou .csv."
                )
        resultado = calcular(tarefas)
    except ErroDeEntrada as e:
        print(f"Erro: {e}", file=sys.stderr)
        return 1

    imprimir(resultado)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
