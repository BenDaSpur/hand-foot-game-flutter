# Deployment Guide

Production web hosting is on **Vercel** at **[https://playhandfoot.com](https://playhandfoot.com)**.

## Vercel Automatic Deployment

The repo includes [`vercel.json`](../vercel.json) and [`scripts/vercel_build.sh`](../scripts/vercel_build.sh). Pushes to `main` trigger a production deploy; other branches get preview URLs.

### Deployment flow

```
Push to GitHub → Vercel build → Clone Flutter 3.32.8 → flutter pub get
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
- Confirm Flutter version **3.32.8** matches CI (see [`vercel.json`](../vercel.json) install command).

**Multiplayer does not work on playhandfoot.com**

- Verify `FIREBASE_WEB_CONFIG` is set in Vercel (Production environment).
- Confirm `playhandfoot.com` is in Firebase **Authorized domains**.
- Re-deploy after changing env vars.

**Stale app after deploy**

- `index.html` is served with `Cache-Control: no-cache` via [`vercel.json`](../vercel.json).
- Hard-refresh the browser if assets still look old.

## Native releases (Android, Windows, macOS, Linux)

Desktop and mobile builds are published via GitHub Releases. See [`.github/workflows/build-and-release.yml`](../.github/workflows/build-and-release.yml).
