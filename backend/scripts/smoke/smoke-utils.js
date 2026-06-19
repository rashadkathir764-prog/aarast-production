'use strict';

const DEFAULT_SMOKE_BASE_URL = 'http://127.0.0.1:3115';
const LOCAL_COMPOSE_DATABASE_URL =
  'postgresql://aarast:aarast_dev_password@localhost:5433/aarast?schema=public';

function configureSmokeDatabaseUrl() {
  if (process.env.SMOKE_DATABASE_URL) {
    process.env.DATABASE_URL = process.env.SMOKE_DATABASE_URL;
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
