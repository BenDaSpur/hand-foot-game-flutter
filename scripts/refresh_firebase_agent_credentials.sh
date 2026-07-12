#!/bin/bash
# Refresh Firebase OAuth credentials for agent/CLI use.
# Copies the MCP/CLI credential store into the gitignored workspace copy.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${FIREBASE_TOOLS_CONFIG:-$HOME/.config/configstore/firebase-tools.json}"
DEST="$REPO_ROOT/.firebase/oauth-credentials.json"

if [[ ! -f "$SRC" ]]; then
  echo "❌ No Firebase credentials found at: $SRC"
  echo "   Log in via Firebase MCP (firebase_login) or run: firebase login"
  exit 1
fi

mkdir -p "$REPO_ROOT/.firebase"
cp "$SRC" "$DEST"
chmod 600 "$DEST"

echo "✅ Refreshed workspace Firebase credentials"
echo "   Source: $SRC"
echo "   Dest:   $DEST"
echo "   Active project: hand-foot-game-flutter (set via MCP or firebase use)"
