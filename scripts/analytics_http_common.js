const fs = require('fs');
const https = require('https');
const crypto = require('crypto');
const path = require('path');

const DEFAULT_REQUEST_TIMEOUT_MS = 30000;
const REPO_ROOT = path.resolve(__dirname, '..');
const DEFAULT_SERVICE_ACCOUNT_FILES = [
  path.join(REPO_ROOT, 'hand-foot-flutter-firebase.json'),
  path.join(REPO_ROOT, '.firebase/hand-foot-flutter-firebase.json'),
  path.join(REPO_ROOT, '.firebase/hand-foot-service-account.json'),
];

// Firebase CLI OAuth client (public installed-app credentials).
// Source: https://github.com/firebase/firebase-tools/blob/master/src/api.ts
const DEFAULT_OAUTH_CLIENT_ID =
  '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const DEFAULT_OAUTH_CLIENT_SECRET = 'j9iVZfS8kkCEFUPaAeJV0sAi';

const SERVICE_ACCOUNT_SCOPES = [
  'https://www.googleapis.com/auth/datastore',
  'https://www.googleapis.com/auth/cloud-platform',
].join(' ');

let cachedServiceAccountToken = null;
let cachedServiceAccountTokenExpiresAt = 0;

function getOAuthClientConfig() {
  const clientId =
    process.env.FIREBASE_OAUTH_CLIENT_ID || DEFAULT_OAUTH_CLIENT_ID;
  const clientSecret =
    process.env.FIREBASE_OAUTH_CLIENT_SECRET || DEFAULT_OAUTH_CLIENT_SECRET;
  return { clientId, clientSecret };
}

function base64url(value) {
  const buffer = Buffer.isBuffer(value) ? value : Buffer.from(value);
  return buffer
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}

function loadServiceAccount() {
  try {
    const explicitFilePath = process.env.FIREBASE_HAND_FOOT_SERVICE_ACCOUNT_FILE;
    if (explicitFilePath && fs.existsSync(explicitFilePath)) {
      return JSON.parse(fs.readFileSync(explicitFilePath, 'utf8'));
    }

    const defaultFilePath = DEFAULT_SERVICE_ACCOUNT_FILES.find((candidate) =>
      fs.existsSync(candidate),
    );
    if (defaultFilePath) {
      return JSON.parse(fs.readFileSync(defaultFilePath, 'utf8'));
    }

    if (process.env.FIREBASE_HAND_FOOT_SERVICE_ACCOUNT_B64) {
      const json = Buffer.from(
        process.env.FIREBASE_HAND_FOOT_SERVICE_ACCOUNT_B64,
        'base64',
      ).toString('utf8');
      return JSON.parse(json);
    }
  } catch (error) {
    throw new Error(
      `Failed to load service account credentials: ${error.message}`,
    );
  }

  return null;
}

function hasServiceAccountCredentials() {
  return loadServiceAccount() != null;
}

async function getServiceAccountAccessToken(serviceAccount) {
  const now = Math.floor(Date.now() / 1000);
  if (
    cachedServiceAccountToken &&
    Date.now() < cachedServiceAccountTokenExpiresAt - 60000
  ) {
    return cachedServiceAccountToken;
  }

  const header = base64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claim = base64url(
    JSON.stringify({
      iss: serviceAccount.client_email,
      scope: SERVICE_ACCOUNT_SCOPES,
      aud: serviceAccount.token_uri || 'https://oauth2.googleapis.com/token',
      exp: now + 3600,
      iat: now,
    }),
  );
  const unsigned = `${header}.${claim}`;
  const signer = crypto.createSign('RSA-SHA256');
  signer.update(unsigned);
  signer.end();
  const signature = base64url(signer.sign(serviceAccount.private_key));
  const assertion = `${unsigned}.${signature}`;

  const body = new URLSearchParams({
    grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
    assertion,
  }).toString();

  const result = await httpsRequest(
    {
      hostname: 'oauth2.googleapis.com',
      path: '/token',
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(body),
      },
    },
    body,
  );

  cachedServiceAccountToken = result.access_token;
  cachedServiceAccountTokenExpiresAt =
    Date.now() + (result.expires_in || 3600) * 1000;
  return cachedServiceAccountToken;
}

function httpsRequest(options, body, timeoutMs = DEFAULT_REQUEST_TIMEOUT_MS) {
  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          try {
            resolve(JSON.parse(data || '{}'));
          } catch (parseError) {
            reject(parseError);
          }
        } else {
          reject(new Error(`HTTP ${res.statusCode}: ${data}`));
        }
      });
    });

    req.setTimeout(timeoutMs, () => {
      req.destroy();
      reject(
        new Error(
          `Request timed out after ${timeoutMs}ms: ${options.hostname || ''}${options.path || ''}`,
        ),
      );
    });

    req.on('error', reject);
    if (body) {
      req.write(body);
    }
    req.end();
  });
}

async function refreshAccessToken(creds, credsPath) {
  const refreshToken = creds.tokens?.refresh_token;
  if (!refreshToken) {
    throw new Error('No refresh_token in credentials file');
  }

  const { clientId, clientSecret } = getOAuthClientConfig();
  const body = new URLSearchParams({
    client_id: clientId,
    client_secret: clientSecret,
    refresh_token: refreshToken,
    grant_type: 'refresh_token',
  }).toString();

  const result = await httpsRequest(
    {
      hostname: 'oauth2.googleapis.com',
      path: '/token',
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(body),
      },
    },
    body,
  );

  creds.tokens.access_token = result.access_token;
  creds.tokens.expires_at = Date.now() + result.expires_in * 1000;

  if (credsPath) {
    fs.writeFileSync(credsPath, JSON.stringify(creds, null, '\t'), {
      mode: 0o600,
    });
  }

  return result.access_token;
}

async function getAccessToken(creds, credsPath) {
  const expiresAt = creds.tokens?.expires_at || 0;
  if (creds.tokens?.access_token && Date.now() < expiresAt - 60000) {
    return creds.tokens.access_token;
  }
  return refreshAccessToken(creds, credsPath);
}

async function resolveAccessToken({ creds, credsPath } = {}) {
  const serviceAccount = loadServiceAccount();
  if (serviceAccount) {
    return getServiceAccountAccessToken(serviceAccount);
  }

  if (!creds) {
    throw new Error(
      'No analytics credentials found. Set FIREBASE_HAND_FOOT_SERVICE_ACCOUNT_B64, ' +
        'place JSON at hand-foot-flutter-firebase.json, or bootstrap OAuth credentials.',
    );
  }

  return getAccessToken(creds, credsPath);
}

module.exports = {
  DEFAULT_REQUEST_TIMEOUT_MS,
  DEFAULT_SERVICE_ACCOUNT_FILES,
  getOAuthClientConfig,
  hasServiceAccountCredentials,
  loadServiceAccount,
  httpsRequest,
  refreshAccessToken,
  getAccessToken,
  getServiceAccountAccessToken,
  resolveAccessToken,
};
