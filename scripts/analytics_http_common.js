const fs = require('fs');
const https = require('https');

const DEFAULT_REQUEST_TIMEOUT_MS = 30000;
const DEFAULT_OAUTH_CLIENT_ID =
  '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';

function getOAuthClientConfig() {
  const clientId =
    process.env.FIREBASE_OAUTH_CLIENT_ID || DEFAULT_OAUTH_CLIENT_ID;
  const clientSecret = process.env.FIREBASE_OAUTH_CLIENT_SECRET;
  if (!clientSecret) {
    throw new Error(
      'FIREBASE_OAUTH_CLIENT_SECRET is required for OAuth token refresh. ' +
        'Set it in your environment or local .env (gitignored). ' +
        'Rotate any secret previously committed to the repository.',
    );
  }
  return { clientId, clientSecret };
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

module.exports = {
  DEFAULT_REQUEST_TIMEOUT_MS,
  getOAuthClientConfig,
  httpsRequest,
  refreshAccessToken,
  getAccessToken,
};
