# Firebase MCP Quickstart (Cloud Agents)

Fast path for agents to find credentials and query production analytics. **Do not assume `.env` or `.firebase/` exist on disk** — Cloud Agents inject secrets as environment variables that must be materialized first.

## Recommended auth: service account (no token expiry)

For **Firestore analytics reads**, prefer `FIREBASE_HAND_FOOT_SERVICE_ACCOUNT_B64` over user OAuth tokens.

| Auth method | Secret | Expires? | Best for |
|-------------|--------|----------|----------|
| **Service account (preferred)** | `FIREBASE_HAND_FOOT_SERVICE_ACCOUNT_B64` | No (until key rotated) | Cloud Agents, analytics scripts |
| OAuth user (legacy) | `FIREBASE_TOOLS_CREDENTIALS_JSON` | Yes (~1h + reauth) | MCP project setup, local dev |

## Create `FIREBASE_HAND_FOOT_SERVICE_ACCOUNT_B64`

1. In GCP Console → **IAM & Admin** → **Service Accounts**, use `firebase-adminsdk` (or a dedicated read-only account)
2. **Keys** → **Add key** → **JSON** → download (e.g. `your-project-key-id.json`)
3. Base64-encode the entire JSON file:

```bash
# Linux
base64 -w0 your-project-key.json

# macOS
base64 -i your-project-key.json
```

4. In **Cursor → Cloud Agents → Runtime Secrets**, add:

| Name | Value |
|------|-------|
| `FIREBASE_HAND_FOOT_SERVICE_ACCOUNT_B64` | Paste the base64 output (single line, no quotes) |

5. Bootstrap materializes it to `.firebase/hand-foot-service-account.json` (gitignored)

**Never commit the JSON or base64 string to GitHub.**

### Local development (without Cloud Agent secret)

Copy your service account JSON to the gitignored path:

```bash
cp your-project-key.json .firebase/hand-foot-service-account.json
chmod 600 .firebase/hand-foot-service-account.json
```

Or set a custom path:

```bash
export FIREBASE_HAND_FOOT_SERVICE_ACCOUNT_FILE=/path/to/your-key.json
```

## 30-second checklist

```bash
# 1. Check what's available (no secrets printed)
./scripts/check_firebase_credentials.sh

# 2. Materialize env vars → gitignored files
./scripts/bootstrap_firebase_agent_env.sh

# 3. Query analytics (service account preferred)
node scripts/query_analytics_session.js --recent --turn-summaries --decision-outcomes --limit 10
```

## Where credentials live

| Source | Variable / path | Purpose |
|--------|-----------------|---------|
| **Cloud Agent (preferred)** | `FIREBASE_HAND_FOOT_SERVICE_ACCOUNT_B64` | Base64 service account JSON for Firestore reads |
| **After bootstrap** | `.firebase/hand-foot-service-account.json` | Decoded service account (gitignored) |
| **Cloud Agent** | `FIREBASE_TOOLS_CREDENTIALS_JSON` | OAuth user tokens (MCP / legacy fallback) |
| **Cloud Agent** | `FIREBASE_PROJECT_ID`, `FIREBASE_WEB_*`, etc. | Flutter + Firestore project config |
| **After bootstrap** | `.env` | All `FIREBASE_*` vars for Dart/Flutter scripts |
| **After bootstrap** | `.firebase/oauth-credentials.json` | Workspace OAuth copy |
| **After bootstrap** | `~/.config/configstore/firebase-tools.json` | Firebase MCP credential store |
| **After bootstrap** | `.firebase/agent-config.json` | Non-secret paths + project metadata |

List injected secrets: `echo $CLOUD_AGENT_INJECTED_SECRET_NAMES`

### Typical Cloud Agent secret set

**Required for app + bootstrap:**
- `FIREBASE_PROJECT_ID`, `FIREBASE_WEB_API_KEY`, `FIREBASE_WEB_APP_ID`, platform app IDs, etc.

**Required for reliable analytics (add this):**
- `FIREBASE_HAND_FOOT_SERVICE_ACCOUNT_B64`

**Optional / legacy:**
- `FIREBASE_TOOLS_CREDENTIALS_JSON` — OAuth user session (expires)
- `FIREBASE_OAUTH_CLIENT_SECRET` — override only; scripts include Firebase CLI default

## Query analytics

```bash
# Node — prefers service account automatically
node scripts/query_analytics_session.js --recent --turn-summaries --decision-outcomes --limit 10
node scripts/query_analytics_session.js --scores 3325,1140,1185 --foot-only

# Human play patterns
node scripts/analyze_human_decisions.js   # → scripts/human_play_analysis.json
```

Successful auth prints:

```
Auth mode: service-account
Project: your-firebase-project-id
```

## Firestore collections (bot analysis)

| Collection | Use for |
|------------|---------|
| `game_sessions` | Final scores, `botPerformance`, `gameSeed`, `botAiVersion` |
| `bot_decisions` | Per-turn actions, hand size, foot status, reasoning |
| `turn_summaries` | Draw sources, melds created, discard ranks per turn |
| `decision_outcomes` | Whether opponents took bot discards / unlocked pile |
| `game_events` | Raw action stream for human-vs-bot comparison |

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `Auth mode: oauth-user` + `invalid_rapt` | Add `FIREBASE_HAND_FOOT_SERVICE_ACCOUNT_B64` or MCP `firebase_login` |
| `Invalid JWT Signature` | Re-download service account key; re-encode base64 |
| `No analytics credentials found` | Bootstrap + service account B64 or OAuth creds |
| `Authenticated User: <NONE>` | Run bootstrap; OAuth only needed for MCP project tools |
| `No .env file` | Run `./scripts/bootstrap_firebase_agent_env.sh` |

## Security

- Never commit `.env`, `.firebase/*`, service account JSON, or real `lib/firebase_options.dart`
- Bootstrap scripts never print secret values
- Rotate/delete old service account keys in GCP when replacing

See also: [firebase_agent_setup.md](firebase_agent_setup.md), [analytics_guide.md](analytics_guide.md)
