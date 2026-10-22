#!/usr/bin/env node
/**
 * Mostra, por dentro, o passo de BUSCA do RAG: transforma uma pergunta em vetor
 * (embedding) e lista os 4 trechos da base mais próximos dela, com a distância.
 *
 * Distância menor = significado mais parecido. Quando nenhum trecho se destaca
 * (todos com distância parecida e alta), a base não cobre a pergunta — e é aí que
 * o prompt do agente manda responder "Não encontrei isso na base de conhecimento".
 *
 * Uso (da raiz do repositório, com o Docker rodando e a base indexada):
 *   node workflows/03-agente-base-conhecimento/scripts/demo-busca.mjs "minha senha bloqueou"
 *
 * Lê OPENAI_API_KEY do .env da raiz. Não grava nada.
 */

import { readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const RAIZ = resolve(dirname(fileURLToPath(import.meta.url)), '../../..');
// Docker Desktop no Windows nem sempre está no PATH; ajuste se o seu estiver em outro lugar.
const DOCKER = process.env.DOCKER_BIN || 'docker';

const env = Object.fromEntries(readFileSync(resolve(RAIZ, '.env'), 'utf8')
  .split(/\r?\n/).map((l) => l.match(/^([A-Z0-9_]+)=(.*)$/)).filter(Boolean).map((m) => [m[1], m[2].trim()]));

const pergunta = process.argv[2];
if (!pergunta) {
  console.error('Uso: node demo-busca.mjs "sua pergunta"');
  process.exitCode = 1;
} else {
  const r = await fetch('https://api.openai.com/v1/embeddings', {
    method: 'POST',
    headers: { Authorization: 'Bearer ' + env.OPENAI_API_KEY, 'Content-Type': 'application/json' },
    body: JSON.stringify({ model: 'text-embedding-3-small', input: pergunta }),
  });
  const v = (await r.json()).data[0].embedding;
  console.log(`\nPERGUNTA: "${pergunta}"`);
  console.log(`virou um vetor de ${v.length} números: [${v.slice(0, 5).map((x) => x.toFixed(4)).join(', ')}, ...]\n`);

  // <=> é o operador de distância de cosseno do pgvector — o mesmo que o agente usa.
  const sql = `SELECT round((embedding <=> '[${v.join(',')}]')::numeric, 3) AS distancia,
                      metadata->>'fonte' AS fonte,
                      left(regexp_replace(text, '\\s+', ' ', 'g'), 90) AS inicio_do_trecho
                 FROM kb_chunks ORDER BY 1 LIMIT 4;`;
  const out = execFileSync(DOCKER, ['exec', '-i', 'n8n-postgres', 'psql', '-U', 'n8n', '-d', 'n8n'], { input: sql, encoding: 'utf8' });
  console.log('Os 4 trechos mais próximos:\n' + out);
}
