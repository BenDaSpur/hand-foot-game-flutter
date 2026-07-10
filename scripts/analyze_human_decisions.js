#!/usr/bin/env node
/**
 * Analyze human player decisions from game_events Firestore collection.
 */
const fs = require('fs');
const path = require('path');
const {
  httpsRequest,
  getAccessToken,
} = require('./analytics_http_common');

const REPO_ROOT = path.resolve(__dirname, '..');
const CREDS_PATH =
  process.env.FIREBASE_CREDENTIALS_FILE ||
  path.join(REPO_ROOT, '.firebase/firebase-tools-credentials.json');
const PROJECT_ID = process.env.FIREBASE_PROJECT_ID || 'hand-foot-game-flutter';

function loadCreds() {
  return JSON.parse(fs.readFileSync(CREDS_PATH, 'utf8'));
}

function classifyDiscardTier(parsed) {
  if (parsed.isWild) {
    return 'wild';
  }
  if (parsed.isThree) {
    return 'three';
  }
  if (parsed.points >= 20) {
    return 'high';
  }
  if (parsed.points >= 10) {
    return 'mid';
  }
  return 'low';
}

function percentOf(count, total) {
  return total === 0 ? 0 : (count / total) * 100;
}

function firestoreValueToJs(v) {
  if (v == null) return null;
  if (v.stringValue !== undefined) return v.stringValue;
  if (v.integerValue !== undefined) return parseInt(v.integerValue, 10);
  if (v.doubleValue !== undefined) return parseFloat(v.doubleValue);
  if (v.booleanValue !== undefined) return v.booleanValue;
  if (v.timestampValue !== undefined) return v.timestampValue;
  if (v.arrayValue) return (v.arrayValue.values || []).map(firestoreValueToJs);
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
    const p =
      `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${collection}` +
      `?pageSize=${pageSize}` +
      (pageToken ? `&pageToken=${encodeURIComponent(pageToken)}` : '');
    const result = await httpsRequest({
      hostname: 'firestore.googleapis.com',
      path: p,
      method: 'GET',
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    all.push(...(result.documents || []).map(docToObject));
    pageToken = result.nextPageToken;
  } while (pageToken);
  return all;
}

function parseCard(cardStr) {
  if (!cardStr) return { rank: 'unknown', isWild: false, isThree: false, points: 0 };
  const s = cardStr.trim();
  const isWild = s.startsWith('2 ') || s === 'JK' || s.startsWith('Joker');
  const isThree = s.startsWith('3 ');
  let points = 20;
  if (isWild) points = 50;
  else if (isThree) points = s.includes('♥') || s.includes('♦') ? 100 : -100;
  else if (s.startsWith('A ')) points = 20;
  else if (s.startsWith('K ') || s.startsWith('Q ') || s.startsWith('J ')) points = 10;
  else if (s.startsWith('10 ')) points = 10;
  else points = 5;
  const rank = s.split(' ')[0];
  return { rank, isWild, isThree, points, raw: s };
}

function rankInHand(handCards, discardedCard) {
  const parsed = parseCard(discardedCard);
  const count = (handCards || []).filter((c) => parseCard(c).rank === parsed.rank).length;
  return count;
}

function meldRankFromEvent(e) {
  const card = e.eventData?.context?.card;
  if (!card) return null;
  return parseCard(card).rank;
}

async function main() {
  const creds = loadCreds();
  const token = await getAccessToken(creds, CREDS_PATH);

  console.log('Loading sessions...');
  const sessions = await listCollection(token, 'game_sessions', 500);
  const humanSessions = sessions.filter((s) => (s.humanPlayers || 0) > 0);
  console.log(`Sessions: ${sessions.length}, with humans: ${humanSessions.length}`);

  console.log('Loading game_events...');
  const allEvents = await listCollection(token, 'game_events', 500);
  const humanEvents = allEvents.filter((e) => e.playerType === 'human');
  console.log(`Total events: ${allEvents.length}, human: ${humanEvents.length}`);

  const byType = {};
  const discards = [];
  const meldActions = [];
  const drawActions = [];
  const unlockActions = [];

  for (const e of humanEvents) {
    const t = e.eventType || 'unknown';
    const data = e.eventData || {};
    byType[t] = (byType[t] || 0) + 1;

    if (t === 'discardCard') {
      const card = data.context?.card;
      const hand = data.handCards || [];
      const parsed = parseCard(card);
      discards.push({
        card,
        rank: parsed.rank,
        points: parsed.points,
        isWild: parsed.isWild,
        isThree: parsed.isThree,
        handSize: data.handSize,
        sameRankInHand: rankInHand(hand, card),
        hasPlayedDown: data.hasPlayedDown,
        hasPickedUpFoot: data.hasPickedUpFoot,
        bookCount: data.bookCount,
        meldCount: data.meldCount,
        round: data.round,
        goingOut: data.context?.goingOut,
        topDiscard: data.topDiscardCard,
      });
    }

    if (
      t === 'addToMeld' ||
      t === 'createMeld' ||
      t === 'createMultipleMelds' ||
      t === 'playDown'
    ) {
      meldActions.push({
        type: t,
        handSizeBefore: data.handSize,
        bookCount: data.bookCount,
        meldCount: data.meldCount,
        hasPlayedDown: data.hasPlayedDown,
        hasPickedUpFoot: data.hasPickedUpFoot,
        round: data.round,
        cardsInMeld: data.context?.meldCount,
        totalCards: data.context?.totalCards,
        card: data.context?.card,
      });
    }

    if (t === 'drawFromDeck' || t === 'drawFromDiscard' || t === 'unlockDiscardPile') {
      drawActions.push({
        type: t,
        handSize: data.handSize,
        hasPlayedDown: data.hasPlayedDown,
        hasPickedUpFoot: data.hasPickedUpFoot,
        topDiscard: data.topDiscardCard,
        round: data.round,
      });
      if (t === 'unlockDiscardPile') unlockActions.push(data);
    }
  }

  console.log('\n=== Event type counts ===');
  console.log(JSON.stringify(byType, null, 2));

  console.log('\n=== Draw behavior ===');
  const drawTypes = {};
  for (const d of drawActions) drawTypes[d.type] = (drawTypes[d.type] || 0) + 1;
  console.log(drawTypes);
  console.log(`Unlock discard pile: ${unlockActions.length} times`);

  console.log('\n=== Discard analysis ===');
  console.log(`Total discards: ${discards.length}`);
  const discardByRank = {};
  const discardPoints = { high: 0, mid: 0, low: 0, wild: 0, three: 0 };
  let discardWithMeldPotential = 0;
  let discardWhileBuildingBook = 0;

  for (const d of discards) {
    discardByRank[d.rank] = (discardByRank[d.rank] || 0) + 1;
    const tier = classifyDiscardTier({
      isWild: d.isWild,
      isThree: d.isThree,
      points: d.points,
    });
    discardPoints[tier]++;
    if (d.sameRankInHand >= 2) discardWithMeldPotential++;
    if (d.sameRankInHand >= 3 && d.bookCount > 0) discardWhileBuildingBook++;
  }

  const discardWithMeldPotentialPct = percentOf(
    discardWithMeldPotential,
    discards.length,
  );

  console.log('By point tier:', discardPoints);
  console.log(
    'Discarding rank with 2+ same in hand:',
    discardWithMeldPotential,
    `(${discardWithMeldPotentialPct.toFixed(1)}%)`,
  );
  console.log('Top discarded ranks:', Object.entries(discardByRank).sort((a, b) => b[1] - a[1]).slice(0, 10));

  const avgHandAtDiscard =
    discards.reduce((s, d) => s + (d.handSize || 0), 0) / (discards.length || 1);
  console.log(`Avg hand size when discarding: ${avgHandAtDiscard.toFixed(1)}`);

  const footDiscards = discards.filter((d) => d.hasPickedUpFoot);
  const handDiscards = discards.filter((d) => !d.hasPickedUpFoot);
  console.log(`Discards in foot: ${footDiscards.length}, in hand: ${handDiscards.length}`);

  console.log('\n=== Meld analysis ===');
  console.log(`Total meld actions: ${meldActions.length}`);
  const meldByType = {};
  for (const m of meldActions) meldByType[m.type] = (meldByType[m.type] || 0) + 1;
  console.log('By type:', meldByType);

  const multiMeldTurns = meldActions.filter((m) => m.type === 'createMultipleMelds');
  console.log(`Multi-meld plays: ${multiMeldTurns.length}`);

  const meldsPerTurn = {};
  for (const m of meldActions) {
    const key = `${m.round}-${m.handSizeBefore}`;
    meldsPerTurn[key] = (meldsPerTurn[key] || 0) + 1;
  }
  const burstMelds = meldActions.filter((m) => m.handSizeBefore >= 15);
  console.log(`Meld actions with 15+ cards in hand: ${burstMelds.length}`);

  const addToMeldNearBook = meldActions.filter(
    (m) => m.type === 'addToMeld' && m.bookCount >= 1,
  );
  console.log(`Add-to-meld when already have books: ${addToMeldNearBook.length}`);

  const playDownEvents = meldActions.filter((m) => !m.hasPlayedDown || m.type === 'playDown');
  console.log(`Pre/during play-down melds: ${playDownEvents.length}`);

  // Sessions with most human activity
  const eventsBySession = {};
  for (const e of humanEvents) {
    const sid = e.sessionId || 'unknown';
    eventsBySession[sid] = (eventsBySession[sid] || 0) + 1;
  }
  console.log('\n=== Top sessions by human events ===');
  console.log(
    Object.entries(eventsBySession)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 10)
      .map(([id, count]) => ({ id, count })),
  );

  // Output summary JSON for agent
  const summary = {
    totalHumanEvents: humanEvents.length,
    sessionsWithHumans: humanSessions.length,
    drawTypes,
    unlockCount: unlockActions.length,
    discardStats: {
      total: discards.length,
      discardPoints,
      discardWithMeldPotentialPct,
      avgHandSize: avgHandAtDiscard,
      topRanks: Object.entries(discardByRank).sort((a, b) => b[1] - a[1]).slice(0, 8),
    },
    meldStats: {
      total: meldActions.length,
      meldByType,
      multiMeldPlays: multiMeldTurns.length,
      burstMeldActions: burstMelds.length,
    },
  };

  fs.writeFileSync(
    path.join(REPO_ROOT, 'scripts/human_play_analysis.json'),
    JSON.stringify(summary, null, 2),
  );
  console.log('\nWrote scripts/human_play_analysis.json');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
