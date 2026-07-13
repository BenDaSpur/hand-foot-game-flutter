#!/usr/bin/env node
/**
 * Query Firestore analytics via admin REST API.
 * Auth: service account preferred (hand-foot-flutter-firebase.json,
 * FIREBASE_HAND_FOOT_SERVICE_ACCOUNT_B64, or legacy hand-foot-service-account.json),
 * (resolveAccessToken in analytics_http_common.js).
 */
const fs = require('fs');
const path = require('path');
const {
  httpsRequest,
  hasServiceAccountCredentials,
  loadServiceAccount,
  resolveAccessToken,
} = require('./analytics_http_common');

const REPO_ROOT = path.resolve(__dirname, '..');
const CREDS_PATH =
  process.env.FIREBASE_CREDENTIALS_FILE ||
  path.join(REPO_ROOT, '.firebase/oauth-credentials.json');


function getProjectId() {
  if (process.env.FIREBASE_PROJECT_ID) {
    return process.env.FIREBASE_PROJECT_ID;
  }
  const serviceAccount = loadServiceAccount();
  if (serviceAccount?.project_id) {
    return serviceAccount.project_id;
  }
  throw new Error(
    'FIREBASE_PROJECT_ID is required (or provide a service account JSON with project_id).',
  );
}
function parseArgs(argv) {
  const args = {
    scores: null,
    session: null,
    footOnly: false,
    limit: 5,
    recent: false,
    turnSummaries: false,
    decisionOutcomes: false,
  };
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
    } else if (argv[i] === '--turn-summaries') {
      args.turnSummaries = true;
    } else if (argv[i] === '--decision-outcomes') {
      args.decisionOutcomes = true;
    }
  }
  return args;
}

function loadCreds() {
  if (!fs.existsSync(CREDS_PATH)) {
    return null;
  }
  const raw = fs.readFileSync(CREDS_PATH, 'utf8');
  return JSON.parse(raw);
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
  const projectId = getProjectId();
  const all = [];
  let pageToken = null;
  do {
    const path =
      `/v1/projects/${projectId}/databases/(default)/documents/${collection}` +
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

async function runStructuredQuery(
  accessToken,
  collection,
  field,
  op,
  value,
  limit = 500,
) {
  const all = [];
  let lastDoc = null;

  while (true) {
    const structuredQuery = {
      from: [{ collectionId: collection }],
      where: {
        fieldFilter: {
          field: { fieldPath: field },
          op,
          value,
        },
      },
      limit,
    };
    if (lastDoc) {
      structuredQuery.startAt = {
        values: [{ referenceValue: lastDoc.name }],
        before: false,
      };
    }

    const body = JSON.stringify({ structuredQuery });
    const result = await httpsRequest(
      {
        hostname: 'firestore.googleapis.com',
        path: `/v1/projects/${getProjectId()}/databases/(default)/documents:runQuery`,
        method: 'POST',
        headers: {
          Authorization: `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(body),
        },
      },
      body,
    );

    const docs = result
      .filter((row) => row.document)
      .map((row) => row.document);
    if (docs.length === 0) {
      break;
    }

    all.push(...docs.map(docToObject));
    if (docs.length < limit) {
      break;
    }

    console.warn(
      `Warning: structured query for ${collection} hit limit ${limit}; fetching more...`,
    );
    lastDoc = docs[docs.length - 1];
  }

  return all;
}

async function fetchBySessionId(
  accessToken,
  collection,
  sessionId,
  structuredLimit,
) {
  let docs = await runStructuredQuery(
    accessToken,
    collection,
    'sessionId',
    'EQUAL',
    { stringValue: sessionId },
    structuredLimit,
  );
  if (docs.length === 0) {
    const allDocs = await listCollection(accessToken, collection, 500);
    docs = allDocs.filter((d) => d.sessionId === sessionId);
  }
  return docs;
}

function scoresMatch(sessionScores, targetScores) {
  if (!sessionScores || !targetScores) return false;
  const a = [...sessionScores].sort((x, y) => y - x);
  const b = [...targetScores].sort((x, y) => y - x);
  return a.length === b.length && a.every((v, i) => v === b[i]);
}

async function main() {
  const args = parseArgs(process.argv);
  const projectId = getProjectId();
  const creds = loadCreds();
  const accessToken = await resolveAccessToken({ creds, credsPath: CREDS_PATH });
  const authMode = hasServiceAccountCredentials()
    ? 'service-account'
    : 'oauth-user';
  console.log(`Auth mode: ${authMode}`);
  console.log(`Project: ${projectId}`);

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
    if (!match) {
      console.error('No matching session found');
      process.exit(1);
    }
    sessionId = match._id;
    console.log('Session:', sessionId);
    console.log(JSON.stringify(match, null, 2));
  }

  console.log('\nFetching bot_decisions for session...');
  let decisions = await fetchBySessionId(
    accessToken,
    'bot_decisions',
    sessionId,
    1000,
  );
  if (args.footOnly) {
    decisions = decisions.filter((d) => d.botHasPickedUpFoot === true);
  }
  decisions.sort((a, b) => (a.timestamp || '').localeCompare(b.timestamp || ''));

  console.log(`Found ${decisions.length} bot decisions`);
  for (const d of decisions.slice(-args.limit * 10)) {
    const drawSource = d.drawSource ? ` drawSource=${d.drawSource}` : '';
    const version = d.botAiVersion ? ` ai=${d.botAiVersion}` : '';
    console.log(
      `- [R${d.round}] ${d.botId} (${d.botPersonality}): ${d.decision}${drawSource}${version} | foot=${d.botHasPickedUpFoot} hand=${d.botHandSize} books=${d.botBookCount} | ${d.reasoning}`,
    );
  }

  console.log('\nFetching game_events for session...');
  let events = await fetchBySessionId(
    accessToken,
    'game_events',
    sessionId,
    500,
  );
  events.sort((a, b) => (a.timestamp || '').localeCompare(b.timestamp || ''));
  console.log(`Found ${events.length} game events`);
  for (const e of events.slice(-30)) {
    const drawSource = e.drawSource ? ` drawSource=${e.drawSource}` : '';
    console.log(
      `- ${e.eventType}${drawSource} | ${e.playerId} | ${JSON.stringify(e.eventData || {})}`,
    );
  }

  if (args.turnSummaries) {
    console.log('\nFetching turn_summaries for session...');
    const turns = await fetchBySessionId(
      accessToken,
      'turn_summaries',
      sessionId,
      500,
    );
    turns.sort((a, b) => (a.timestamp || '').localeCompare(b.timestamp || ''));
    console.log(`Found ${turns.length} turn summaries`);
    for (const t of turns.slice(-args.limit * 5)) {
      console.log(
        `- turn ${t.turnNumber} ${t.playerId} (${t.playerType}): actions=${t.actionCount} melds=${t.meldsCreated} draws=${JSON.stringify(t.drawSources || [])} discard=${t.discardedRank || 'none'}`,
      );
    }
  }

  if (args.decisionOutcomes) {
    console.log('\nFetching decision_outcomes for session...');
    const outcomes = await fetchBySessionId(
      accessToken,
      'decision_outcomes',
      sessionId,
      500,
    );
    outcomes.sort((a, b) =>
      (a.timestamp || '').localeCompare(b.timestamp || ''),
    );
    console.log(`Found ${outcomes.length} decision outcomes`);
    for (const o of outcomes.slice(-args.limit * 5)) {
      console.log(
        `- ${o.originalDecision} -> ${o.outcome} (${o.turnsLater} turns) | ${JSON.stringify(o.outcomeContext || {})}`,
      );
    }
  }
}

main().catch((err) => {
  console.error('Query failed:', err.message);
  process.exit(1);
});
