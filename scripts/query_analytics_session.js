#!/usr/bin/env node
/**
 * Query Firestore analytics using OAuth credentials from .firebase/firebase-tools-credentials.json
 * Analytics collections are write-only from client SDK; this uses admin REST API with user OAuth.
 */
const fs = require('fs');
const path = require('path');
const https = require('https');

const REPO_ROOT = path.resolve(__dirname, '..');
const CREDS_PATH =
  process.env.FIREBASE_CREDENTIALS_FILE ||
  path.join(REPO_ROOT, '.firebase/firebase-tools-credentials.json');
const PROJECT_ID =
  process.env.FIREBASE_PROJECT_ID || 'hand-foot-game-flutter';

function parseArgs(argv) {
  const args = { scores: null, session: null, footOnly: false, limit: 5, recent: false };
  for (let i = 2; i < argv.length; i++) {
    if (argv[i] === '--scores' && argv[i + 1]) {
      args.scores = argv[++i].split(',').map((s) => parseInt(s.trim(), 10));
    } else if (argv[i] === '--session' && argv[i + 1]) {
      args.session = argv[++i];
    } else if (argv[i] === '--foot-only') {
      args.footOnly = true;
    } else if (argv[i] === '--limit' && argv[i + 1]) {
      args.limit = parseInt(argv[++i], 10);
    } else if (argv[i] === '--recent') {
      args.recent = true;
    }
  }
  return args;
}

function loadCreds() {
  const raw = fs.readFileSync(CREDS_PATH, 'utf8');
  return JSON.parse(raw);
}

function httpsRequest(options, body) {
  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve(JSON.parse(data || '{}'));
        } else {
          reject(new Error(`HTTP ${res.statusCode}: ${data}`));
        }
      });
    });
    req.on('error', reject);
    if (body) req.write(body);
    req.end();
  });
}

async function refreshAccessToken(creds) {
  const refreshToken = creds.tokens?.refresh_token;
  if (!refreshToken) throw new Error('No refresh_token in credentials file');

  const body = new URLSearchParams({
    client_id:
      '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
    client_secret: 'j9iVZfS8kkCEFUPaAeJV0sAi',
    refresh_token: refreshToken,
    grant_type: 'refresh_token',
  }).toString();

  const result = await httpsRequest(
    {
      hostname: 'oauth2.googleapis.com',
      path: '/token',
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(body),
      },
    },
    body,
  );

  creds.tokens.access_token = result.access_token;
  creds.tokens.expires_at = Date.now() + result.expires_in * 1000;
  fs.writeFileSync(CREDS_PATH, JSON.stringify(creds, null, '\t'), {
    mode: 0o600,
  });
  return result.access_token;
}

async function getAccessToken(creds) {
  const expiresAt = creds.tokens?.expires_at || 0;
  if (creds.tokens?.access_token && Date.now() < expiresAt - 60000) {
    return creds.tokens.access_token;
  }
  return refreshAccessToken(creds);
}

function firestoreValueToJs(v) {
  if (v == null) return null;
  if (v.stringValue !== undefined) return v.stringValue;
  if (v.integerValue !== undefined) return parseInt(v.integerValue, 10);
  if (v.doubleValue !== undefined) return parseFloat(v.doubleValue);
  if (v.booleanValue !== undefined) return v.booleanValue;
  if (v.timestampValue !== undefined) return v.timestampValue;
  if (v.arrayValue) {
    return (v.arrayValue.values || []).map(firestoreValueToJs);
  }
  if (v.mapValue) {
    const out = {};
    for (const [k, val] of Object.entries(v.mapValue.fields || {})) {
      out[k] = firestoreValueToJs(val);
    }
    return out;
  }
  return v;
}

function docToObject(doc) {
  const data = { _id: doc.name.split('/').pop() };
  for (const [k, v] of Object.entries(doc.fields || {})) {
    data[k] = firestoreValueToJs(v);
  }
  return data;
}

async function listCollection(accessToken, collection, pageSize = 300) {
  const all = [];
  let pageToken = null;
  do {
    const path =
      `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${collection}` +
      `?pageSize=${pageSize}` +
      (pageToken ? `&pageToken=${encodeURIComponent(pageToken)}` : '');
    const result = await httpsRequest({
      hostname: 'firestore.googleapis.com',
      path,
      method: 'GET',
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    all.push(...(result.documents || []).map(docToObject));
    pageToken = result.nextPageToken;
  } while (pageToken);
  return all;
}

async function runStructuredQuery(accessToken, collection, field, op, value, limit = 500) {
  const body = JSON.stringify({
    structuredQuery: {
      from: [{ collectionId: collection }],
      where: {
        fieldFilter: {
          field: { fieldPath: field },
          op,
          value,
        },
      },
      limit,
    },
  });

  const result = await httpsRequest(
    {
      hostname: 'firestore.googleapis.com',
      path: `/v1/projects/${PROJECT_ID}/databases/(default)/documents:runQuery`,
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body),
      },
    },
    body,
  );

  return result
    .filter((row) => row.document)
    .map((row) => docToObject(row.document));
}

function scoresMatch(sessionScores, targetScores) {
  if (!sessionScores || !targetScores) return false;
  const a = [...sessionScores].sort((x, y) => y - x);
  const b = [...targetScores].sort((x, y) => y - x);
  return a.length === b.length && a.every((v, i) => v === b[i]);
}

async function main() {
  const args = parseArgs(process.argv);
  const creds = loadCreds();
  const accessToken = await getAccessToken(creds);

  let sessionId = args.session;

  if (!sessionId) {
    console.log('Fetching recent game_sessions...');
    const sessions = await listCollection(accessToken, 'game_sessions', 200);
    sessions.sort((a, b) => {
      const ta = a.startTime || a.endTime || '';
      const tb = b.startTime || b.endTime || '';
      return tb.localeCompare(ta);
    });

    let match = null;
    if (args.scores) {
      match = sessions.find((s) => scoresMatch(s.finalScores, args.scores));
    }
    if (!match) {
      match = sessions.find((s) => s.status === 'completed');
    }
    if (!match && args.recent) {
      match = sessions[0];
    }
    if (!match && sessions.length > 0) {
      match = sessions[0];
    }
    if (!match) {
      console.error('No matching session found');
      process.exit(1);
    }
    sessionId = match._id;
    console.log('Session:', sessionId);
    console.log(JSON.stringify(match, null, 2));
  }

  console.log('\nFetching bot_decisions for session...');
  let decisions = await runStructuredQuery(
    accessToken,
    'bot_decisions',
    'sessionId',
    'EQUAL',
    { stringValue: sessionId },
    1000,
  );
  if (decisions.length === 0) {
    const allDecisions = await listCollection(accessToken, 'bot_decisions', 500);
    decisions = allDecisions.filter((d) => d.sessionId === sessionId);
  }
  if (args.footOnly) {
    decisions = decisions.filter((d) => d.botHasPickedUpFoot === true);
  }
  decisions.sort((a, b) => (a.timestamp || '').localeCompare(b.timestamp || ''));

  console.log(`Found ${decisions.length} bot decisions`);
  for (const d of decisions.slice(-args.limit * 10)) {
    console.log(
      `- [R${d.round}] ${d.botId} (${d.botPersonality}): ${d.decision} | foot=${d.botHasPickedUpFoot} hand=${d.botHandSize} books=${d.botBookCount} | ${d.reasoning}`,
    );
  }

  console.log('\nFetching game_events for session...');
  let events = await runStructuredQuery(
    accessToken,
    'game_events',
    'sessionId',
    'EQUAL',
    { stringValue: sessionId },
    500,
  );
  if (events.length === 0) {
    const allEvents = await listCollection(accessToken, 'game_events', 500);
    events = allEvents.filter((e) => e.sessionId === sessionId);
  }
  events.sort((a, b) => (a.timestamp || '').localeCompare(b.timestamp || ''));
  console.log(`Found ${events.length} game events`);
  for (const e of events.slice(-30)) {
    console.log(`- ${e.eventType} | ${e.playerId} | ${JSON.stringify(e.eventData || {})}`);
  }
}

main().catch((err) => {
  console.error('Query failed:', err.message);
  process.exit(1);
});
