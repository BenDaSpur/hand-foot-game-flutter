# Firebase access for agents (Cloud / local)

This repo is **public**. Firebase secrets live only in **gitignored** local files. Never commit `.env`, `.firebase/oauth-credentials.json`, or real `lib/firebase_options.dart`.

**Fast path:** [firebase_mcp_quickstart.md](firebase_mcp_quickstart.md)

## Cloud Agent bootstrap (run first)

Secrets are injected as environment variables (`CLOUD_AGENT_INJECTED_SECRET_NAMES`) and/or as a credential file. They are **not** on disk until bootstrapped or injected:

**Required for Firestore analytics:** `hand-foot-flutter-firebase.json` at the repo root — a Firebase service account JSON with permissions to query the production Firestore account. Cloud Agent workspaces provide this file as part of setup.

```bash
./scripts/check_firebase_credentials.sh      # status check (no secrets printed)
./scripts/bootstrap_firebase_agent_env.sh    # writes .env, OAuth files, agent-config.json
```

| Env var (injected) / file | Written to |
|---------------------------|------------|
| `hand-foot-flutter-firebase.json` (Cloud Agent workspace file) | Repo root (gitignored) |
| `FIREBASE_TOOLS_CREDENTIALS_JSON` | `.firebase/oauth-credentials.json` + `~/.config/configstore/firebase-tools.json` |
| `FIREBASE_HAND_FOOT_SERVICE_ACCOUNT_B64` | `hand-foot-flutter-firebase.json` (repo root, gitignored) |
| `FIREBASE_PROJECT_ID` + other `FIREBASE_*` | `.env` |
| `FIREBASE_CREDENTIALS_FILE` | Path hint for OAuth file location |

Non-secret metadata: `.firebase/agent-config.json` (see [agent-config.example.json](agent-config.example.json))

## Quick start (after bootstrap)

| File | Purpose |
|------|---------|
| `hand-foot-flutter-firebase.json` | **Preferred** — service account JSON for Firestore analytics reads (repo root, gitignored) |
| `.env` | Flutter/web Firebase config + project IDs |
| `.firebase/oauth-credentials.json` | OAuth tokens for CLI/admin Firestore reads |
| `.firebase/agent-config.json` | Non-secret metadata + script pointers |

**Project:** value of `FIREBASE_PROJECT_ID`  
**Account:** `FIREBASE_AUTH_EMAIL` (see `firebase_get_environment` after MCP login)

## Firebase MCP (preferred in Cursor)

1. `./scripts/bootstrap_firebase_agent_env.sh` — materialize Cloud Agent secrets
2. `firebase_update_environment` with `active_project: <FIREBASE_PROJECT_ID>`, `project_dir: /workspace`
3. `firebase_get_environment` — verify authenticated user + project
4. If tokens expired: `firebase_login` (paste auth code), then re-run bootstrap

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

Analytics collections (`game_sessions`, `bot_decisions`, `game_events`, `performance_metrics`, `turn_summaries`, `decision_outcomes`) are **write-only** from the client SDK. Agents must read via:

- `scripts/query_analytics_session.js` (Node) — **prefers service account** (`hand-foot-flutter-firebase.json`, `FIREBASE_HAND_FOOT_SERVICE_ACCOUNT_B64`, or `.firebase/hand-foot-service-account.json`), falls back to stored OAuth credentials, or
- Firebase MCP after login (project setup / legacy OAuth workflows)

```bash
node scripts/query_analytics_session.js --scores 3325,1140,1185
node scripts/query_analytics_session.js --session <sessionId> --foot-only
node scripts/query_analytics_session.js --session <sessionId> --turn-summaries --decision-outcomes
```

Node analytics scripts prefer **service account** auth (`hand-foot-flutter-firebase.json`, `FIREBASE_HAND_FOOT_SERVICE_ACCOUNT_B64`, or `.firebase/hand-foot-service-account.json`). OAuth user tokens are a legacy fallback via `scripts/analytics_http_common.js`.

### New analytics fields (2026 quick wins)

| Field | Collections | Values |
|-------|-------------|--------|
| `appVersion` | all | e.g. `1.0.0` (from package metadata at runtime) |
| `botAiVersion` | all | e.g. `2026.07-hand-foot-rush` — bump when bot AI changes |
| `drawSource` | `game_events`, `bot_decisions` | `deck`, `discard`, `unlock` |
| `actionCount`, `drawSources`, `meldsCreated`, `discardedRank` | `turn_summaries` | per completed turn |
| `outcome` | `decision_outcomes` | `opponent_took_discard`, `opponent_unlocked`, `discard_not_taken` |

## Token expiry

Access tokens last ~1 hour. The `refresh_token` in the credentials file is long-lived. If queries fail with 401:

1. Add `FIREBASE_OAUTH_CLIENT_SECRET` to Cloud Agent secrets, or re-run Firebase MCP `firebase_login`
2. `./scripts/bootstrap_firebase_agent_env.sh` (or `./scripts/refresh_firebase_agent_credentials.sh`)

## Security checklist

- [ ] `.env` and `.firebase/*credentials*` are gitignored
- [ ] Do not paste tokens into PRs, issues, or commits
- [ ] Restore stub config before committing Flutter changes: `git checkout lib/firebase_options.dart`
