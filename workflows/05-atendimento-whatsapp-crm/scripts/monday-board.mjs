#!/usr/bin/env node
/**
 * Cria (ou confere) o board de atendimento no Monday.com.
 *
 * Mesmo motivo do workflows/01-triagem-chamados/scripts/notion-database.mjs: o
 * workflow referencia cada coluna pelo ID exato. Criar as colunas na mão, oito
 * vezes, é onde um erro de digitação se esconde até a execução falhar.
 *
 * Uso:
 *   node monday-board.mjs            cria o board e imprime o ID
 *   node monday-board.mjs --conferir confere um board que já existe
 *
 * Lê do .env na raiz do repositório:
 *   MONDAY_API_TOKEN   token pessoal de API (developer.monday.com/api-reference)
 *   MONDAY_BOARD_ID    preenchido depois de criar; usado pelo --conferir
 */

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const ENDPOINT = 'https://api.monday.com/v2';
const NOME_BOARD = 'Atendimento WhatsApp';

const RAIZ = resolve(dirname(fileURLToPath(import.meta.url)), '../../..');

/**
 * Colunas de texto/telefone/data, criadas com a mutation genérica create_column.
 * O `id` é escolhido por nós — sem isso, o Monday gera um ID aleatório e o
 * workflow teria que descobri-lo na mão depois de criar o board.
 */
const COLUNAS_SIMPLES = [
  { id: 'telefone', title: 'Telefone', column_type: 'phone' },
  { id: 'wa_id', title: 'WhatsApp ID', column_type: 'text' },
  { id: 'resumo', title: 'Resumo da conversa', column_type: 'long_text' },
  { id: 'ultima_mensagem', title: 'Última mensagem', column_type: 'long_text' },
  { id: 'atualizado_em', title: 'Atualizado em', column_type: 'date' },
];

/** Colunas de status, com a mutation dedicada create_status_column. */
const COLUNAS_STATUS = [
  {
    id: 'status',
    title: 'Status',
    labels: [
      { index: 0, label: 'Novo', color: 'working_orange' },
      { index: 1, label: 'Em conversa', color: 'bright_blue' },
      { index: 2, label: 'Aguardando humano', color: 'dark_orange' },
      { index: 3, label: 'Qualificado', color: 'done_green', is_done: true },
      { index: 4, label: 'Não qualificado', color: 'stuck_red' },
      { index: 5, label: 'Encerrado', color: 'grey' },
    ],
  },
  {
    id: 'intencao',
    title: 'Intenção',
    labels: [
      { index: 0, label: 'Dúvida', color: 'bright_blue' },
      { index: 1, label: 'Orçamento', color: 'working_orange' },
      { index: 2, label: 'Suporte', color: 'purple' },
      { index: 3, label: 'Reclamação', color: 'stuck_red' },
      { index: 4, label: 'Outro', color: 'grey' },
    ],
  },
];

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

class FalhaAmigavel extends Error {}
function erro(...linhas) {
  throw new FalhaAmigavel(linhas.join('\n    '));
}

async function monday(token, query, variables) {
  const resposta = await fetch(ENDPOINT, {
    method: 'POST',
    headers: { Authorization: token, 'Content-Type': 'application/json' },
    body: JSON.stringify({ query, variables }),
  });
  const dados = await resposta.json().catch(() => ({}));

  if (resposta.status === 401 || dados?.error_code === 'UnauthorizedException') {
    erro(
      'O Monday recusou o token (401).',
      'Confira MONDAY_API_TOKEN no .env — sai em developer.monday.com/api-reference,',
      'ou pelo avatar no canto inferior esquerdo do Monday > Administração > API.',
    );
  }
  if (dados?.errors?.length) {
    erro('O Monday respondeu com erro:', dados.errors.map((e) => e.message).join(' | '));
  }
  return dados.data;
}

async function criar(env) {
  if (env.MONDAY_BOARD_ID) {
    erro(
      'MONDAY_BOARD_ID já está preenchido no .env.',
      'Rodar de novo criaria um segundo board. Se quiser conferir o que existe:',
      '  node monday-board.mjs --conferir',
    );
  }
  const token = env.MONDAY_API_TOKEN || erro('Falta MONDAY_API_TOKEN no .env.');

  console.log(`\n  Criando o board "${NOME_BOARD}"...`);

  const board = await monday(
    token,
    `mutation($nome: String!) {
      create_board(board_name: $nome, board_kind: private) { id }
    }`,
    { nome: NOME_BOARD },
  );
  const boardId = board.create_board.id;

  for (const c of COLUNAS_SIMPLES) {
    await monday(
      token,
      `mutation($boardId: ID!, $id: String!, $title: String!, $type: ColumnType!) {
        create_column(board_id: $boardId, id: $id, title: $title, column_type: $type) { id }
      }`,
      { boardId, id: c.id, title: c.title, type: c.column_type },
    );
    console.log(`    coluna criada: ${c.title}`);
  }

  for (const c of COLUNAS_STATUS) {
    await monday(
      token,
      `mutation($boardId: ID!, $id: String!, $title: String!, $defaults: CreateStatusColumnSettingsInput) {
        create_status_column(board_id: $boardId, id: $id, title: $title, defaults: $defaults) { id }
      }`,
      { boardId, id: c.id, title: c.title, defaults: { labels: c.labels } },
    );
    console.log(`    coluna criada: ${c.title} (status, ${c.labels.length} opções)`);
  }

  console.log(`\n  ✓ Board criado com ${COLUNAS_SIMPLES.length + COLUNAS_STATUS.length} colunas além do nome.`);
  console.log(`    https://view.monday.com/boards/${boardId}\n`);
  console.log('  Cole esta linha no .env:\n');
  console.log(`      MONDAY_BOARD_ID=${boardId}\n`);
}

async function conferir(env) {
  const token = env.MONDAY_API_TOKEN || erro('Falta MONDAY_API_TOKEN no .env.');
  const boardId = env.MONDAY_BOARD_ID || erro('Falta MONDAY_BOARD_ID no .env.');

  const resp = await monday(
    token,
    `query($boardId: [ID!]) {
      boards(ids: $boardId) {
        name
        columns { id title type }
      }
    }`,
    { boardId: [boardId] },
  );
  const board = resp.boards?.[0];
  if (!board) erro(`Nenhum board encontrado com ID ${boardId}.`, 'Confira MONDAY_BOARD_ID no .env.');

  console.log(`\n  Conferindo "${board.name}"\n`);

  const existentes = new Map(board.columns.map((c) => [c.id, c]));
  const esperadas = [
    ...COLUNAS_SIMPLES.map((c) => ({ id: c.id, title: c.title, type: c.column_type })),
    ...COLUNAS_STATUS.map((c) => ({ id: c.id, title: c.title, type: 'status' })),
  ];

  let problemas = 0;
  for (const e of esperadas) {
    const achada = existentes.get(e.id);
    if (!achada) {
      console.log(`  ✗ coluna de id "${e.id}" (${e.title}) não existe`);
      problemas++;
      continue;
    }
    if (achada.type !== e.type) {
      console.log(`  ✗ "${e.id}" é ${achada.type}, deveria ser ${e.type}`);
      problemas++;
      continue;
    }
    console.log(`  ✓ ${e.title} (${e.id})`);
  }

  console.log(problemas
    ? `\n  ${problemas} coluna(s) precisam de ajuste antes de rodar o workflow.\n`
    : '\n  ✓ Board pronto para o workflow 05.\n');
  process.exitCode = problemas ? 1 : 0;
}

try {
  const env = lerEnv();
  await (process.argv.includes('--conferir') ? conferir(env) : criar(env));
} catch (e) {
  if (!(e instanceof FalhaAmigavel)) throw e;
  console.error(`\n  ✗ ${e.message}\n`);
  process.exitCode = 1;
}
