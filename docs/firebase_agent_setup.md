# Firebase access for agents (Cloud / local)

This repo is **public**. Firebase secrets live only in **gitignored** local files. Never commit `.env`, `.firebase/firebase-tools-credentials.json`, or real `lib/firebase_options.dart`.

## Quick start (already configured in this workspace)

| File | Purpose |
|------|---------|
| `.env` | Flutter/web Firebase config + project IDs |
| `.firebase/firebase-tools-credentials.json` | OAuth tokens for CLI/admin Firestore reads |
| `.firebase/agent-config.json` | Non-secret metadata + script pointers |

**Project:** `hand-foot-game-flutter`  
**Account:** `ben@spurlock.app`

## Firebase MCP (preferred in Cursor)

1. `firebase_login` — complete browser auth if tokens expired
2. `firebase_update_environment` with `active_project: hand-foot-game-flutter`, `project_dir: /workspace`
3. `firebase_get_environment` — verify authenticated user + project

Then refresh workspace copy:

```bash
./scripts/refresh_firebase_agent_credentials.sh
```

## Flutter / Dart scripts

Apply real Firebase config to the stub `lib/firebase_options.dart`:

```bash
./scripts/setup_local_firebase.sh   # reads .env
dart run scripts/export_analytics.dart --days 7 --include-raw
```

## Firestore analytics (important)

Analytics collections (`game_sessions`, `bot_decisions`, `game_events`, `performance_metrics`) are **write-only** from the client SDK. Agents must read via:

- OAuth credentials in `.firebase/firebase-tools-credentials.json`, or
- Firebase MCP after login, or
- `scripts/query_analytics_session.js` (Node, uses stored OAuth)

```bash
node scripts/query_analytics_session.js --scores 3325,1140,1185
node scripts/query_analytics_session.js --session <sessionId> --foot-only
```

## Token expiry

Access tokens last ~1 hour. The `refresh_token` in the credentials file is long-lived. If queries fail with 401:

1. Re-run Firebase MCP `firebase_login` (paste new auth code)
2. `./scripts/refresh_firebase_agent_credentials.sh`

## Security checklist

- [ ] `.env` and `.firebase/*credentials*` are gitignored
- [ ] Do not paste tokens into PRs, issues, or commits
- [ ] Restore stub config before committing Flutter changes: `git checkout lib/firebase_options.dart`
