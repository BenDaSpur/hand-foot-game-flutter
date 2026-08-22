# Deployment Guide

Production web hosting is on **Vercel** at **[https://playhandfoot.com](https://playhandfoot.com)**.

## Vercel Automatic Deployment

The repo includes [`vercel.json`](../vercel.json) and [`scripts/vercel_build.sh`](../scripts/vercel_build.sh). Pushes to `main` trigger a production deploy; other branches get preview URLs.

### Deployment flow

```text
Push to GitHub → Vercel build → Clone Flutter 3.44.6 → flutter pub get
  → Inject Firebase config (if set) → flutter build web → Serve build/web
```

### Vercel project settings

Flutter is not a native Vercel framework. Use **Framework Preset: Other**.

| Setting | Value |
|---------|-------|
| **Root Directory** | `.` (repo root) |
| **Framework Preset** | `Other` |
| **Install Command** | See `installCommand` in [`vercel.json`](../vercel.json) |
| **Build Command** | `bash scripts/vercel_build.sh` |
| **Output Directory** | `build/web` |
| **Development Command** | *(leave empty)* — use `flutter run -d web-server` locally |
| **Node.js Version** | *(default / unset)* |

These are defined in [`vercel.json`](../vercel.json) so dashboard and repo stay in sync.

**Important:** Unlike the old GitHub Pages setup, production is served at the domain root. Do **not** pass `--base-href /repository-name/` for Vercel builds.

### Environment variables

Configure in **Vercel → Project → Settings → Environment Variables**.

**Option A — individual vars (recommended if already set in Vercel):**

| Variable | Required for web multiplayer | Notes |
|----------|------------------------------|-------|
| `FIREBASE_PROJECT_ID` | Yes | Firebase project ID |
| `FIREBASE_WEB_API_KEY` | Yes | Web API key from Firebase console |
| `FIREBASE_WEB_APP_ID` | Yes | Web app ID |
| `FIREBASE_MESSAGING_SENDER_ID` | Yes | Usually same as project number |
| `FIREBASE_STORAGE_BUCKET` | Yes | From Firebase console |
| `FIREBASE_WEB_MEASUREMENT_ID` | Recommended | Analytics |
| `FIREBASE_ANDROID_*`, `FIREBASE_IOS_*`, `FIREBASE_MACOS_*` | No for web-only Vercel builds | Used if generating full multi-platform config |

At build time, [`scripts/vercel_build.sh`](../scripts/vercel_build.sh) calls [`scripts/generate_firebase_options_from_env.sh`](../scripts/generate_firebase_options_from_env.sh) when `FIREBASE_WEB_API_KEY` is set.

**Option B — single base64 blob (legacy / GitHub Actions parity):**

| Variable | Purpose |
|----------|---------|
| `FIREBASE_WEB_CONFIG` | Base64-encoded full `lib/firebase_options.dart` file |

If both are set, `FIREBASE_WEB_CONFIG` takes precedence.

**Not needed on Vercel for the web app build:**

- `FIREBASE_CREDENTIALS_FILE` — agent/CLI OAuth only (local analytics queries)
- `FIREBASE_AUTH_EMAIL` — documentation / agent setup only
- `FIREBASE_PROJECT_NUMBER` — not used in `firebase_options.dart` (same value as messaging sender ID)

Without web Firebase vars, **PLAY SOLO** still works (stub Firebase + graceful init). **CREATE GAME** / **JOIN GAME** require the production config.

### Domain and DNS

1. In **Vercel → Project → Settings → Domains**, add `playhandfoot.com` (and `www.playhandfoot.com` if desired).
2. Point DNS per Vercel's instructions (typically `A`/`CNAME` records to Vercel).
3. Set production branch to **`main`**.

### Firebase Console (multiplayer)

Add these **Authorized domains** for the Firebase web app:

- `playhandfoot.com`
- `www.playhandfoot.com` (if used)
- `*.vercel.app` (optional, for preview deployments)

### Monitoring deployments

- **Vercel dashboard** — build logs, preview URLs, and production status
- **GitHub Actions CI** — unit tests and analysis still run on PRs via [`.github/workflows/ci.yml`](../.github/workflows/ci.yml)

### Local web build test

```bash
flutter pub get
flutter build web --release
cd build/web
python3 -m http.server 8000
# Visit http://localhost:8000
```

To test with production Firebase locally, use [`scripts/setup_local_firebase.sh`](../scripts/setup_local_firebase.sh) before building.

### Troubleshooting

**Build fails on Vercel**

- Check Vercel build logs for Flutter SDK or `pub get` errors.
- Confirm Flutter version **3.44.6** matches CI (see [`vercel.json`](../vercel.json) install command).

**Multiplayer does not work on playhandfoot.com**

- Verify Firebase config in Vercel (Production). Either option is valid:
  - **Option A:** `FIREBASE_WEB_CONFIG` (base64-encoded `lib/firebase_options.dart`), or
  - **Option B:** all required individual vars: `FIREBASE_PROJECT_ID`, `FIREBASE_WEB_API_KEY`, `FIREBASE_WEB_APP_ID`, `FIREBASE_MESSAGING_SENDER_ID`, and `FIREBASE_STORAGE_BUCKET`
- Confirm `playhandfoot.com` is in Firebase **Authorized domains**.
- Re-deploy after changing env vars.

**Stale app after deploy**

- App shell files (`index.html`, `flutter_bootstrap.js`, `flutter_service_worker.js`, `main.dart.js`, `version.json`, `manifest.json`) are served with `Cache-Control: no-cache` via [`vercel.json`](../vercel.json).
- Content-hashed assets under `/assets/` and `/canvaskit/` use long-lived immutable caching.
- Each Vercel build stamps `version.json` `build_number` with the git commit SHA (`VERCEL_GIT_COMMIT_SHA`).
- The web app polls `version.json` and shows a **Reload** banner when a newer deploy is detected.
- Flutter's service worker still handles offline caching and asset hash upgrades.

## App version

The bump workflow stamps `version` in [`pubspec.yaml`](../pubspec.yaml) onto the **PR branch** when that PR is about to merge: auto-merge is enabled, or the PR is added to a GitHub merge queue.

GitHub's merge queue cannot inject commits into its temporary `gh-readonly-queue/` snapshot, and `GITHUB_TOKEN` cannot push through protected `main`. Pushing to the unprotected PR head works with the workflow's `contents: write` permission and does not need **Allow GitHub Actions to create and approve pull requests**.

Format: **`YYYY.M.D+N`** (UTC calendar date, no leading zeros).

- First merge on 22 Aug 2026 → `2026.8.22+1`
- Second merge that same UTC day → `2026.8.22+2`
- First merge the next UTC day → `2026.8.23+1`

The next number is computed from `main`'s current `pubspec.yaml`, so two PRs do not invent versions while you work. If a second PR is still open after the first merges, enable auto-merge (or re-enqueue) so it is restamped against the new `main`.

Use **Enable auto-merge** on feature PRs (the repo already allows it). A GitHub merge queue is optional; if you turn on **Require merge queue**, keep CI listening for `merge_group` (already in [`.github/workflows/ci.yml`](../.github/workflows/ci.yml)) and use a batch size of 1 so two PRs do not share one version.

Do not set the version by hand in feature PRs. Only one bump job runs at a time so two merge-ready PRs cannot allocate the same `N`. After the bot pushes the stamp, it dispatches CI on that commit because `GITHUB_TOKEN` pushes do not start `pull_request` workflows.

Flutter maps the part before `+` to the version name and `N` to the build number. The in-app session menu and analytics `appVersion` field show the full `YYYY.M.D+N` string.

## Native releases (Android, Windows, macOS, Linux)

Desktop and mobile builds are published via GitHub Releases. See [`.github/workflows/build-and-release.yml`](../.github/workflows/build-and-release.yml).
