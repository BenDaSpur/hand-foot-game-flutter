# AGENTS.md

## Repository context

**This is a public repository** (`BenDaSpur/hand-foot-game-flutter` on GitHub). Treat all code, commits, PRs, and review comments as world-readable.

- **Never commit secrets** — no API keys, Firebase credentials, `.env` files, service account JSON, or tokens.
- **Never paste secrets** into issues, PR descriptions, or agent prompts.
- Use the repo's **stub** `lib/firebase_options.dart` locally; inject real Firebase config only via `scripts/setup_local_firebase.sh` + a local `.env` (gitignored).
- Assume CI logs, PR reviews (including CodeRabbit), and Cloud Agent transcripts may be visible to others.

## Cursor Cloud specific instructions

This is a Flutter (Dart) app — the **Hand & Foot** card game with AI bots and optional Firebase multiplayer. Standard dev/test/build commands live in `README.md`, `CLAUDE.md`, and `format_and_test.sh`; use those as the source of truth.

### Environment
- Flutter SDK **3.44.6** (Dart 3.12.2) is the project target (and should be pre-installed at `/opt/flutter` in Cloud Agent workspaces). `PATH` and `CHROME_EXECUTABLE=/usr/local/bin/google-chrome` are exported in `~/.bashrc`. If `flutter` isn't on `PATH` in a fresh non-login shell, call it via `/opt/flutter/bin/flutter`.
- Only the **web (Chrome)** and headless test toolchains are set up. The Android and Linux-desktop toolchains are intentionally not installed, so `flutter doctor` reports them as missing — this is expected and does not affect web/test workflows.

### Running the app (dev mode)
- Run on web: `flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080` (serves at `http://localhost:8080`). Use a browser to reach it; the `web-server` device has no auto-launched Chrome. The first web build takes ~30–60s to compile before the URL is served.
- Production web app: **https://playhandfoot.com** (Vercel; see `docs/DEPLOYMENT.md` and `vercel.json`).
- Solo play (`PLAY SOLO`) is fully offline and needs no backend. `main.dart` catches Firebase init failures and continues, so the app runs without Firebase credentials.

### Multiplayer / Firebase (optional)
- The repo ships a **stub** `lib/firebase_options.dart`. Online multiplayer (`CREATE GAME`/`JOIN GAME`) requires real Firebase/Firestore credentials injected via `scripts/setup_local_firebase.sh` + a local `.env` (gitignored).
- **Firebase credentials (Cloud Agent):** Cloud Agent workspaces include **`hand-foot-flutter-firebase.json`** at the repo root — a Firebase service account JSON with permissions to query the production Firestore account (gitignored). Run `./scripts/bootstrap_firebase_agent_env.sh` to materialize other injected secrets. Alternatively, inject `FIREBASE_HAND_FOOT_SERVICE_ACCOUNT_B64` (base64-encoded service account JSON). See [docs/firebase_mcp_quickstart.md](docs/firebase_mcp_quickstart.md).
- **Analytics queries:** `node scripts/query_analytics_session.js --scores 3325,1140,1185 --foot-only` — uses **service account** auth when `hand-foot-flutter-firebase.json` (or `FIREBASE_HAND_FOOT_SERVICE_ACCOUNT_B64` / `.firebase/hand-foot-service-account.json`) is configured; falls back to OAuth user tokens otherwise (add `FIREBASE_OAUTH_CLIENT_SECRET` only if OAuth refresh fails).
- Without Firebase credentials, solo vs. bots still works — sufficient for core gameplay.

### Investigating game data (use Firebase MCP)

When a user asks about a **session**, **bot behavior**, **foot transitions**, **scores**, or other **production analytics**, use **Firebase MCP first** — do not guess from code alone.

1. **Bootstrap credentials** — confirm `hand-foot-flutter-firebase.json` exists at the repo root (or run `./scripts/check_firebase_credentials.sh`), then `./scripts/bootstrap_firebase_agent_env.sh`
2. **Check MCP is ready** — `GetMcpTools` with server `Firebase`. If status is `loading`, wait and retry.
3. **Authenticate / set project**
   - `firebase_get_environment` — confirm `Authenticated User` and `Active Project ID`
   - If unauthenticated or expired: `firebase_login` (user pastes auth code), then re-run bootstrap
   - `firebase_update_environment` with `project_dir: /workspace` and `active_project: <FIREBASE_PROJECT_ID>`
4. **Query Firestore analytics** (preferred script after MCP auth):

```bash
node scripts/query_analytics_session.js --session <sessionId> --turn-summaries --decision-outcomes
node scripts/query_analytics_session.js --session <sessionId> --foot-only
node scripts/query_analytics_session.js --scores 3325,1140,1185
```

5. **Collections to use**
   - `game_sessions` — seed, players, final scores, `botPerformance.hasPickedUpFoot`
   - `bot_decisions` — per-turn AI choices, hand size, foot status, reasoning
   - `game_events` / `turn_summaries` — turn-by-turn state snapshots

6. **Repro hints** — `gameSeed` + `botAiVersion` on session docs allow correlating analytics with deterministic local tests.

See `docs/firebase_mcp_quickstart.md`, `docs/firebase_agent_setup.md`, and `docs/analytics_guide.md` for full details. Never commit or paste OAuth tokens, `.env`, or credential JSON.

### Testing
- `flutter test` runs the full unit/widget suite (~750 tests) and passes headlessly with no extra setup. Tests skip Firebase automatically under `FLUTTER_TEST`.
- `flutter analyze` must be clean (zero issues) — the repo enforces this.
- E2E integration tests (`e2e_test/`) run in CI on Ubuntu Chrome (`flutter test e2e_test/ -d chrome`). Locally: same command, or `-d macos` on a Mac with desktop enabled.

### Code quality (required before commit/PR)

CI enforces formatting — unformatted Dart will fail `quality-checks`. After any code change:

```bash
dart format .              # required — CI runs: dart format --set-exit-if-changed .
flutter analyze            # must be zero issues
flutter test               # full suite must pass
```

Or run the all-in-one script: `./format_and_test.sh`
