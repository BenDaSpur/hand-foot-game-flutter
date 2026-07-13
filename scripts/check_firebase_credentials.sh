#!/bin/bash
# Read-only Firebase credential status check for agents.
# Prints green/red status without exposing secret values.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_CREDS_FILE="$REPO_ROOT/.firebase/oauth-credentials.json"
CREDS_FILE="${FIREBASE_CREDENTIALS_FILE:-$DEFAULT_CREDS_FILE}"
MCP_STORE="${FIREBASE_TOOLS_CONFIG:-$HOME/.config/configstore/firebase-tools.json}"

status() {
  if [[ "$1" == "ok" ]]; then
    echo "✅ $2"
  else
    echo "❌ $2"
  fi
}

check_env() {
  local name="$1"
  if [[ -n "${!name:-}" ]]; then
    status ok "env:$name is set"
    return 0
  fi
  status fail "env:$name is missing"
  return 1
}

check_file() {
  local path="$1"
  local label="$2"
  if [[ -f "$path" ]]; then
    status ok "$label exists ($path)"
    return 0
  fi
  status fail "$label missing ($path)"
  return 1
}

echo "Firebase Credential Status"
echo "=========================="
echo "Repo: $REPO_ROOT"
echo ""

ENV_OK=0
FILE_OK=0

echo "Environment variables (Cloud Agent / shell):"
check_env FIREBASE_PROJECT_ID && ENV_OK=$((ENV_OK + 1)) || true
check_env FIREBASE_TOOLS_CREDENTIALS_JSON && ENV_OK=$((ENV_OK + 1)) || true
check_env FIREBASE_WEB_API_KEY && ENV_OK=$((ENV_OK + 1)) || true
check_env FIREBASE_WEB_APP_ID && ENV_OK=$((ENV_OK + 1)) || true
check_env FIREBASE_AUTH_EMAIL && ENV_OK=$((ENV_OK + 1)) || true
if [[ -n "${FIREBASE_HAND_FOOT_SERVICE_ACCOUNT_B64:-}" ]]; then
  status ok "env:FIREBASE_HAND_FOOT_SERVICE_ACCOUNT_B64 is set (preferred analytics auth)"
elif [[ -f "$REPO_ROOT/.firebase/hand-foot-flutter-firebase.json" ]]; then
  status ok "service account file exists (.firebase/hand-foot-flutter-firebase.json)"
elif [[ -f "$REPO_ROOT/.firebase/hand-foot-service-account.json" ]]; then
  status ok "service account file exists (.firebase/hand-foot-service-account.json)"
else
  echo "⚠️  No service account configured (analytics will fall back to OAuth user tokens)"
fi
if [[ -n "${FIREBASE_OAUTH_CLIENT_SECRET:-}" ]]; then
  status ok "env:FIREBASE_OAUTH_CLIENT_SECRET is set (Node token refresh)"
else
  echo "ℹ️  env:FIREBASE_OAUTH_CLIENT_SECRET not set (scripts use Firebase CLI default)"
fi
echo ""

echo "On-disk credential files:"
check_file "$REPO_ROOT/.env" ".env" && FILE_OK=$((FILE_OK + 1)) || true
check_file "$CREDS_FILE" "workspace OAuth credentials" && FILE_OK=$((FILE_OK + 1)) || true
check_file "$MCP_STORE" "MCP credential store" && FILE_OK=$((FILE_OK + 1)) || true
check_file "$REPO_ROOT/.firebase/agent-config.json" "agent-config.json" && FILE_OK=$((FILE_OK + 1)) || true
check_file "$REPO_ROOT/.firebase/hand-foot-flutter-firebase.json" "hand-foot-flutter-firebase.json" && FILE_OK=$((FILE_OK + 1)) || true
check_file "$REPO_ROOT/.firebase/hand-foot-service-account.json" "service account JSON (legacy)" && FILE_OK=$((FILE_OK + 1)) || true
echo ""

if [[ -n "${CLOUD_AGENT_INJECTED_SECRET_NAMES:-}" ]]; then
  SECRET_COUNT=$(echo "$CLOUD_AGENT_INJECTED_SECRET_NAMES" | tr ',' '\n' | wc -l)
  status ok "Cloud Agent injected $SECRET_COUNT Firebase-related secrets"
else
  echo "⚠️  CLOUD_AGENT_INJECTED_SECRET_NAMES not set (not a Cloud Agent pod?)"
fi
echo ""

SERVICE_ACCOUNT_READY=false
if [[ -n "${FIREBASE_HAND_FOOT_SERVICE_ACCOUNT_B64:-}" ]] ||
  [[ -f "$REPO_ROOT/.firebase/hand-foot-flutter-firebase.json" ]] ||
  [[ -f "$REPO_ROOT/.firebase/hand-foot-service-account.json" ]]; then
  SERVICE_ACCOUNT_READY=true
fi

if [[ "$SERVICE_ACCOUNT_READY" == true ]]; then
  echo "Next: node scripts/query_analytics_session.js --recent --turn-summaries --decision-outcomes"
elif [[ -f "$CREDS_FILE" || -f "$MCP_STORE" ]]; then
  echo "Next: verify MCP with firebase_get_environment"
elif [[ -n "${FIREBASE_TOOLS_CREDENTIALS_JSON:-}" ]]; then
  echo "Next: run ./scripts/bootstrap_firebase_agent_env.sh to materialize credentials"
else
  echo "Next: firebase_login via MCP, or inject FIREBASE_TOOLS_CREDENTIALS_JSON"
fi
