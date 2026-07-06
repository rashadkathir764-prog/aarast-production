'use strict';

const fs = require('fs');
const path = require('path');

const DEFAULT_SMOKE_BASE_URL = 'http://127.0.0.1:3115';
const LOCAL_COMPOSE_DATABASE_URL =
  'postgresql://aarast:aarast_dev_password@localhost:5433/aarast?schema=public';

function loadLocalEnvFile() {
  const envPath = path.resolve(__dirname, '..', '..', '.env');
  if (!fs.existsSync(envPath)) return;

  const lines = fs.readFileSync(envPath, 'utf8').split(/\r?\n/);
  for (const line of lines) {
    const match = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$/);
    if (!match) continue;

    const [, key, rawValue] = match;
    if (process.env[key] !== undefined) continue;

    let value = rawValue.trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    process.env[key] = value;
  }
}

function configureSmokeDatabaseUrl() {
  loadLocalEnvFile();

  if (process.env.SMOKE_DATABASE_URL) {
    process.env.DATABASE_URL = process.env.SMOKE_DATABASE_URL;
    return;
  }

  if (process.env.DATABASE_URL) {
    return;
  }

  const smokeBaseUrl = process.env.SMOKE_BASE_URL ?? DEFAULT_SMOKE_BASE_URL;
  const isLocalComposeBackend =
    smokeBaseUrl === DEFAULT_SMOKE_BASE_URL ||
    smokeBaseUrl === 'http://localhost:3115';

  if (isLocalComposeBackend) {
    process.env.DATABASE_URL = LOCAL_COMPOSE_DATABASE_URL;
    process.env.SMOKE_DATABASE_URL = LOCAL_COMPOSE_DATABASE_URL;
  }
}

function requireResponseId(label, response) {
  const id = response.body?.id;
  if (typeof id === 'string' && id.length > 0) {
    return id;
  }

  console.log(`${label} response status: ${response.status}`);
  console.log(`${label} response body: ${JSON.stringify(response.body, null, 2)}`);
  throw new Error(`${label} did not return an id`);
}

module.exports = {
  configureSmokeDatabaseUrl,
  requireResponseId,
};
