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
- Flutter SDK **3.32.8** (Dart 3.8.1) is pre-installed at `/opt/flutter`. `PATH` and `CHROME_EXECUTABLE=/usr/local/bin/google-chrome` are exported in `~/.bashrc`. If `flutter` isn't on `PATH` in a fresh non-login shell, call it via `/opt/flutter/bin/flutter`.
- Only the **web (Chrome)** and headless test toolchains are set up. The Android and Linux-desktop toolchains are intentionally not installed, so `flutter doctor` reports them as missing — this is expected and does not affect web/test workflows.

### Running the app (dev mode)
- Run on web: `flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080` (serves at `http://localhost:8080`). Use a browser to reach it; the `web-server` device has no auto-launched Chrome. The first web build takes ~30–60s to compile before the URL is served.
- Solo play (`PLAY SOLO`) is fully offline and needs no backend. `main.dart` catches Firebase init failures and continues, so the app runs without Firebase credentials.

### Multiplayer / Firebase (optional, not set up here)
- The repo ships a **stub** `lib/firebase_options.dart`. Online multiplayer (`CREATE GAME`/`JOIN GAME`) requires real Firebase/Firestore credentials injected via `scripts/setup_local_firebase.sh` + a `.env`. Without them, only solo vs. bots works — which is sufficient to exercise core gameplay.

### Testing
- `flutter test` runs the full unit/widget suite (~750 tests) and passes headlessly with no extra setup. Tests skip Firebase automatically under `FLUTTER_TEST`.
- `flutter analyze` must be clean (zero issues) — the repo enforces this.
- E2E integration tests (`e2e_test/`) are documented to run on `-d macos` and are **disabled in CI**; they are not runnable in this Linux/web environment.

### Code quality (required before commit/PR)

CI enforces formatting — unformatted Dart will fail `quality-checks`. After any code change:

```bash
dart format .              # required — CI runs: dart format --set-exit-if-changed .
flutter analyze            # must be zero issues
flutter test               # full suite must pass
```

Or run the all-in-one script: `./format_and_test.sh`
