#!/usr/bin/env node
/**
 * Cria (ou confere) o database de chamados no Notion.
 *
 * Existe porque o nó do n8n referencia cada propriedade pelo NOME exato,
 * acento incluído. Criar "Urgencia" em vez de "Urgência" faz o fluxo falhar
 * numa mensagem que não diz qual é o problema. Script não erra acento.
 *
 * Uso:
 *   node notion-database.mjs            cria o database e imprime o ID
 *   node notion-database.mjs --conferir confere um database que já existe
 *
 * Lê do .env na raiz do repositório:
 *   NOTION_TOKEN              token da integração (só este script usa; o n8n
 *                             guarda o dele na tela de credenciais)
 *   NOTION_PARENT_PAGE_ID     página onde o database vai ser criado
 *   NOTION_DATABASE_CHAMADOS  preenchido depois de criar; usado pelo --conferir
 */

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

// A API do Notion versiona por header. Fixamos uma versão conhecida em vez de
// pegar a mais nova: versão nova do Notion muda o formato de resposta e
// quebraria este script sem aviso.
const NOTION_VERSION = '2022-06-28';
const NOME_DATABASE = 'Chamados';

const RAIZ = resolve(dirname(fileURLToPath(import.meta.url)), '../../..');

/** Estrutura do database. É a fonte da verdade — o README copia daqui. */
const PROPRIEDADES = {
  'Nome': { title: {} },
  'Categoria': {
    select: {
      options: [
        { name: 'Acesso', color: 'blue' },
        { name: 'Rede', color: 'purple' },
        { name: 'Equipamento', color: 'orange' },
        { name: 'Sistemas', color: 'green' },
        { name: 'Revisão manual', color: 'red' },
      ],
    },
  },
  'Urgência': {
    select: {
      options: [
        { name: 'Alta', color: 'red' },
        { name: 'Média', color: 'yellow' },
        { name: 'Baixa', color: 'gray' },
      ],
    },
  },
  'Status': {
    select: {
      options: [
        { name: 'Novo', color: 'blue' },
        { name: 'Em andamento', color: 'yellow' },
        { name: 'Resolvido', color: 'green' },
      ],
    },
  },
  'Confiança': { number: { format: 'number' } },
  'Remetente': { rich_text: {} },
  'Recebido em': { date: {} },
  'Resumo': { rich_text: {} },
  'Triagem': { rich_text: {} },
  'ID da mensagem': { rich_text: {} },
};

function lerEnv() {
  let bruto;
  try {
    bruto = readFileSync(resolve(RAIZ, '.env'), 'utf8');
  } catch {
    erro('Não achei o .env na raiz do repositório.', 'Copie o .env.example para .env e preencha.');
  }
  const env = {};
  for (const linha of bruto.split(/\r?\n/)) {
    const m = linha.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)$/);
    if (m) env[m[1]] = m[2].trim().replace(/^["']|["']$/g, '');
  }
  return env;
}

function erro(...linhas) {
  console.error('\n  ✗ ' + linhas.join('\n    ') + '\n');
  process.exit(1);
}

/** Aceita o ID com ou sem hífen, e também a URL inteira colada do navegador. */
function normalizarId(valor, rotulo) {
  const hex = (valor || '').replace(/-/g, '').match(/[0-9a-f]{32}/i);
  if (!hex) {
    erro(
      `${rotulo} não parece um ID do Notion: "${valor || '(vazio)'}"`,
      'São 32 caracteres hexadecimais. Na URL da página, é o trecho depois da',
      'última barra e antes do "?" — pode colar a URL inteira que eu extraio.',
    );
  }
  return hex[0].toLowerCase();
}

async function notion(token, metodo, caminho, corpo) {
  const resposta = await fetch(`https://api.notion.com/v1${caminho}`, {
    method: metodo,
    headers: {
      'Authorization': `Bearer ${token}`,
      'Notion-Version': NOTION_VERSION,
      'Content-Type': 'application/json',
    },
    body: corpo ? JSON.stringify(corpo) : undefined,
  });

  const dados = await resposta.json().catch(() => ({}));
  if (resposta.ok) return dados;

  // As duas falhas que realmente acontecem, traduzidas.
  if (resposta.status === 401) {
    erro(
      'O Notion recusou o token (401).',
      'Confira NOTION_TOKEN no .env. Ele começa com "ntn_" ou "secret_" e sai',
      'de notion.so/my-integrations.',
    );
  }
  if (resposta.status === 404) {
    erro(
      'O Notion respondeu 404: para a API, esse objeto não existe.',
      'Quase sempre não é o ID errado — é a integração não ter sido convidada.',
      'Abra a página no Notion e vá em: ⋯ → Connections → Connect to → sua integração.',
      'A permissão desce para os filhos, então convide na página-mãe.',
    );
  }
  erro(`Notion respondeu ${resposta.status}.`, dados.message || JSON.stringify(dados));
}

async function criar(env) {
  if (env.NOTION_DATABASE_CHAMADOS) {
    erro(
      'NOTION_DATABASE_CHAMADOS já está preenchido no .env.',
      'Rodar de novo criaria um segundo database. Se quiser conferir o que existe:',
      '  node notion-database.mjs --conferir',
    );
  }

  const token = env.NOTION_TOKEN || erro('Falta NOTION_TOKEN no .env.');
  const pai = normalizarId(env.NOTION_PARENT_PAGE_ID, 'NOTION_PARENT_PAGE_ID');

  console.log(`\n  Criando o database "${NOME_DATABASE}"...`);

  const db = await notion(token, 'POST', '/databases', {
    parent: { type: 'page_id', page_id: pai },
    icon: { type: 'emoji', emoji: '🎫' },
    title: [{ type: 'text', text: { content: NOME_DATABASE } }],
    description: [{
      type: 'text',
      text: { content: 'Chamados triados automaticamente pelo workflow 01 do n8n.' },
    }],
    properties: PROPRIEDADES,
  });

  const id = db.id.replace(/-/g, '');
  console.log(`\n  ✓ Database criado com ${Object.keys(PROPRIEDADES).length} propriedades.`);
  console.log(`    ${db.url}\n`);
  console.log('  Cole esta linha no .env:\n');
  console.log(`      NOTION_DATABASE_CHAMADOS=${id}\n`);
  console.log('  Depois recrie o container para o n8n enxergar a variável:\n');
  console.log('      docker compose -f infra/docker-compose.yml up -d --force-recreate n8n\n');
}

async function conferir(env) {
  const token = env.NOTION_TOKEN || erro('Falta NOTION_TOKEN no .env.');
  const id = normalizarId(env.NOTION_DATABASE_CHAMADOS, 'NOTION_DATABASE_CHAMADOS');

  const db = await notion(token, 'GET', `/databases/${id}`);
  const atual = db.properties;
  let problemas = 0;

  console.log(`\n  Conferindo "${db.title?.[0]?.plain_text ?? id}"\n`);

  for (const [nome, definicao] of Object.entries(PROPRIEDADES)) {
    const tipoEsperado = Object.keys(definicao)[0];
    const encontrada = atual[nome];

    if (!encontrada) {
      // O erro clássico: existe com acento diferente ou maiúscula diferente.
      const parecida = Object.keys(atual).find(
        (k) => k.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()
             === nome.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase(),
      );
      console.log(`  ✗ "${nome}" (${tipoEsperado}) não existe`
        + (parecida ? ` — achei "${parecida}", renomeie para bater exatamente` : ''));
      problemas++;
      continue;
    }

    if (encontrada.type !== tipoEsperado) {
      console.log(`  ✗ "${nome}" é ${encontrada.type}, deveria ser ${tipoEsperado}`);
      problemas++;
      continue;
    }

    if (tipoEsperado === 'select') {
      const tem = new Set(encontrada.select.options.map((o) => o.name));
      const faltam = definicao.select.options.map((o) => o.name).filter((o) => !tem.has(o));
      if (faltam.length) {
        console.log(`  ⚠ "${nome}" está sem as opções: ${faltam.join(', ')}`);
        console.log('     (o Notion cria sozinho na primeira página, mas sem a cor definida)');
        continue;
      }
    }

    console.log(`  ✓ ${nome}`);
  }

  const extras = Object.keys(atual).filter((k) => !(k in PROPRIEDADES));
  if (extras.length) console.log(`\n  · Propriedades a mais (sem problema): ${extras.join(', ')}`);

  console.log(problemas
    ? `\n  ${problemas} propriedade(s) precisam de ajuste antes de rodar o fluxo.\n`
    : '\n  ✓ Database pronto para o workflow 01.\n');
  process.exit(problemas ? 1 : 0);
}

const env = lerEnv();
await (process.argv.includes('--conferir') ? conferir(env) : criar(env));
