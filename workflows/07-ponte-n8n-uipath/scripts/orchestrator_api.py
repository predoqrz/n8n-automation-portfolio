#!/usr/bin/env python3
"""
Referência para o workflow 07: as mesmas chamadas que os nós HTTP Request do n8n vão fazer,
uma de cada vez, para você ver e testar cada passo isolado antes de montar o fluxo.

Só usa a biblioteca padrão do Python (nenhum `pip install`).

Uso, da raiz do repositório:
    python workflows/07-ponte-n8n-uipath/scripts/orchestrator_api.py --token      # só autentica
    python workflows/07-ponte-n8n-uipath/scripts/orchestrator_api.py --pastas     # lista pastas e IDs
    python workflows/07-ponte-n8n-uipath/scripts/orchestrator_api.py --listar     # processos da pasta
    python workflows/07-ponte-n8n-uipath/scripts/orchestrator_api.py --disparar "NomeDoProcesso"

Lê do .env na raiz do repositório:
    UIPATH_ORG            nome da organização (o que aparece em cloud.uipath.com/<org>/...)
    UIPATH_TENANT         nome do tenant (normalmente DefaultTenant)
    UIPATH_CLIENT_ID      App ID da External Application
    UIPATH_CLIENT_SECRET  App Secret da External Application
    UIPATH_FOLDER_ID      ID numérico da pasta onde o processo está publicado (ver --pastas)

AINDA NÃO TESTADO contra uma conta real: escrito a partir da documentação da UiPath
(fontes no README). Cada passo imprime a resposta crua quando dá erro, para facilitar
o ajuste.
"""

import argparse
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[3]
BASE_CLOUD = "https://cloud.uipath.com"

# Scopes de aplicação pedidos ao token:
#   OR.Execution      -> listar processos (Releases)
#   OR.Jobs           -> disparar e consultar jobs
#   OR.Folders.Read   -> listar pastas (só para descobrir o UIPATH_FOLDER_ID)
# Cuidado: marcar os três níveis de um mesmo recurso (ex.: OR.Jobs, OR.Jobs.Read e
# OR.Jobs.Write) na External Application costuma dar "invalid_scope". Os scopes pedidos
# aqui precisam estar marcados lá, na aba "Application scopes".
SCOPES = "OR.Execution OR.Jobs OR.Folders.Read"

# Estados em que um job ainda não terminou.
EM_ANDAMENTO = {"Pending", "Running", "Stopping", "Terminating", "Resumed", "Suspended"}


class FalhaAmigavel(Exception):
    """Erro com mensagem pronta para o usuário, sem stack trace."""


def ler_env() -> dict:
    caminho = RAIZ / ".env"
    if not caminho.exists():
        raise FalhaAmigavel("Não achei o .env na raiz do repositório. Copie o .env.example e preencha.")
    env = {}
    for linha in caminho.read_text(encoding="utf-8").splitlines():
        if "=" in linha and not linha.lstrip().startswith("#"):
            chave, valor = linha.split("=", 1)
            env[chave.strip()] = valor.strip().strip("'\"")
    faltando = [k for k in ("UIPATH_ORG", "UIPATH_TENANT", "UIPATH_CLIENT_ID", "UIPATH_CLIENT_SECRET") if not env.get(k)]
    if faltando:
        raise FalhaAmigavel("Faltam no .env: " + ", ".join(faltando))
    return env


def http(metodo: str, url: str, *, cabecalhos: dict | None = None, corpo: bytes | None = None) -> dict:
    """Faz a requisição e devolve o JSON. Em erro HTTP, mostra o corpo da resposta."""
    req = urllib.request.Request(url, data=corpo, method=metodo, headers=cabecalhos or {})
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            texto = resp.read().decode("utf-8")
            return json.loads(texto) if texto else {}
    except urllib.error.HTTPError as e:
        detalhe = e.read().decode("utf-8", errors="replace")[:500]
        raise FalhaAmigavel(f"{metodo} {url}\n    HTTP {e.code}: {detalhe}") from None


# --------------------------------------------------------------------------- passo 1
def obter_token(env: dict) -> str:
    """
    OAuth 2.0 client credentials. No n8n: HTTP Request POST, corpo "Form URL Encoded".
    O token volta em access_token e vai no cabeçalho Authorization: Bearer <token>.
    """
    url = f"{BASE_CLOUD}/{env['UIPATH_ORG']}/identity_/connect/token"
    corpo = urllib.parse.urlencode({
        "grant_type": "client_credentials",
        "client_id": env["UIPATH_CLIENT_ID"],
        "client_secret": env["UIPATH_CLIENT_SECRET"],
        "scope": SCOPES,
    }).encode()
    resp = http("POST", url, cabecalhos={"Content-Type": "application/x-www-form-urlencoded"}, corpo=corpo)
    if "access_token" not in resp:
        raise FalhaAmigavel(f"O Orchestrator não devolveu token: {resp}")
    print(f"  ✓ token obtido (expira em {resp.get('expires_in', '?')} s)")
    return resp["access_token"]


def url_orchestrator(env: dict, caminho: str) -> str:
    return f"{BASE_CLOUD}/{env['UIPATH_ORG']}/{env['UIPATH_TENANT']}/orchestrator_/{caminho}"


def cabecalhos_api(token: str, env: dict, com_pasta: bool = True) -> dict:
    """
    X-UIPATH-OrganizationUnitId diz em qual pasta (folder) a chamada acontece. Processos e
    jobs moram dentro de pastas; sem esse cabeçalho, a API não sabe onde procurar.
    """
    h = {"Authorization": f"Bearer {token}", "Accept": "application/json"}
    if com_pasta:
        if not env.get("UIPATH_FOLDER_ID"):
            raise FalhaAmigavel("Falta UIPATH_FOLDER_ID no .env. Rode com --pastas para descobrir o ID.")
        h["X-UIPATH-OrganizationUnitId"] = env["UIPATH_FOLDER_ID"]
    return h


# --------------------------------------------------------------------------- auxiliar
def listar_pastas(token: str, env: dict) -> None:
    resp = http("GET", url_orchestrator(env, "odata/Folders"), cabecalhos=cabecalhos_api(token, env, com_pasta=False))
    print("\n  Pastas (use o Id como UIPATH_FOLDER_ID):")
    for p in resp.get("value", []):
        print(f"    Id {p['Id']:>8}  ·  {p.get('FullyQualifiedName') or p.get('DisplayName')}")


# --------------------------------------------------------------------------- passo 2
def listar_processos(token: str, env: dict) -> list:
    """No Orchestrator, um processo publicado numa pasta se chama Release na API."""
    resp = http("GET", url_orchestrator(env, "odata/Releases"), cabecalhos=cabecalhos_api(token, env))
    processos = resp.get("value", [])
    print(f"\n  {len(processos)} processo(s) na pasta {env['UIPATH_FOLDER_ID']}:")
    for p in processos:
        print(f"    {p['Name']:<40} versão {p.get('ProcessVersion', '?'):<10} key {p['Key']}")
    return processos


# --------------------------------------------------------------------------- passo 3
def disparar_job(token: str, env: dict, nome: str) -> int:
    """
    Procura o processo pelo nome (a Key muda se ele for republicado; o nome não) e dispara.
    ModernJobsCount = estratégia para pastas modernas: "rode N vez(es)", e o Orchestrator
    escolhe o robô disponível.
    """
    filtro = urllib.parse.quote(f"Name eq '{nome}'")
    resp = http("GET", url_orchestrator(env, f"odata/Releases?$filter={filtro}"), cabecalhos=cabecalhos_api(token, env))
    if not resp.get("value"):
        raise FalhaAmigavel(f'Processo "{nome}" não encontrado na pasta {env["UIPATH_FOLDER_ID"]}. Rode --listar.')
    release_key = resp["value"][0]["Key"]

    corpo = json.dumps({"startInfo": {"ReleaseKey": release_key, "Strategy": "ModernJobsCount", "JobsCount": 1}}).encode()
    h = cabecalhos_api(token, env) | {"Content-Type": "application/json"}
    resp = http("POST", url_orchestrator(env, "odata/Jobs/UiPath.Server.Configuration.OData.StartJobs"), cabecalhos=h, corpo=corpo)
    job_id = resp["value"][0]["Id"]
    print(f"  ✓ job {job_id} criado para \"{nome}\" (estado inicial: {resp['value'][0].get('State')})")
    return job_id


# --------------------------------------------------------------------------- passo 4
def acompanhar_job(token: str, env: dict, job_id: int, intervalo_s: int = 10, tentativas: int = 30) -> str:
    """
    Polling: pergunta o estado do job a cada `intervalo_s` segundos, até ele terminar ou
    estourar o limite. No n8n vira um laço: Wait → HTTP Request → IF → volta para o Wait.
    O limite existe para o fluxo nunca ficar preso esperando um job que travou.
    """
    url = url_orchestrator(env, f"odata/Jobs({job_id})")
    for n in range(1, tentativas + 1):
        job = http("GET", url, cabecalhos=cabecalhos_api(token, env))
        estado = job.get("State")
        print(f"    [{n:>2}/{tentativas}] {estado}")
        if estado not in EM_ANDAMENTO:
            if estado != "Successful":
                print(f"    motivo: {job.get('Info', '(sem detalhe)')}")
            return estado
        time.sleep(intervalo_s)
    return "SemResposta"


def main() -> None:
    parser = argparse.ArgumentParser(description="Referência da API do UiPath Orchestrator para o workflow 07.")
    g = parser.add_mutually_exclusive_group(required=True)
    g.add_argument("--token", action="store_true", help="só testa a autenticação")
    g.add_argument("--pastas", action="store_true", help="lista as pastas e seus IDs")
    g.add_argument("--listar", action="store_true", help="lista os processos da pasta")
    g.add_argument("--disparar", metavar="PROCESSO", help="dispara o processo e acompanha até terminar")
    args = parser.parse_args()

    env = ler_env()
    token = obter_token(env)
    if args.pastas:
        listar_pastas(token, env)
    elif args.listar:
        listar_processos(token, env)
    elif args.disparar:
        job_id = disparar_job(token, env, args.disparar)
        print(f"\n  Resultado final: {acompanhar_job(token, env, job_id)}")


if __name__ == "__main__":
    try:
        main()
    except FalhaAmigavel as e:
        print(f"\n  ✗ {e}\n", file=sys.stderr)
        sys.exit(1)
