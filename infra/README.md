# Ambiente local

Sobe o n8n self-hosted com PostgreSQL como banco de persistência. É a mesma arquitetura
usada em produção na maioria das empresas que rodam n8n, e por isso é a que vale aprender.

## Pré-requisitos

- Docker e Docker Compose instalados
- Porta 5678 livre

## Subindo

1. Copie o arquivo de variáveis e preencha:

   ```bash
   cp .env.example .env
   ```

2. Gere a chave de criptografia e cole em `N8N_ENCRYPTION_KEY`:

   ```bash
   openssl rand -base64 32
   ```

   Guarde essa chave em lugar seguro. Ela criptografa todas as credenciais salvas dentro
   do n8n. Perdeu a chave, perdeu as credenciais.

3. Suba os containers:

   ```bash
   docker compose -f infra/docker-compose.yml --env-file .env up -d
   ```

4. Acesse `http://localhost:5678` e crie a conta de owner na primeira execução.

## Comandos úteis

```bash
docker compose -f infra/docker-compose.yml logs -f n8n   # acompanhar logs
docker compose -f infra/docker-compose.yml restart n8n   # reiniciar
docker compose -f infra/docker-compose.yml down          # parar (mantém os volumes)
docker compose -f infra/docker-compose.yml pull          # atualizar imagem
```

## Webhooks acessíveis de fora

Workflows com gatilho de webhook (como o 01) precisam de uma URL pública para receber
chamadas de serviços externos. Para desenvolvimento, use um túnel:

```bash
ngrok http 5678
```

Depois ajuste `WEBHOOK_URL` no `.env` com a URL gerada e reinicie o container.
