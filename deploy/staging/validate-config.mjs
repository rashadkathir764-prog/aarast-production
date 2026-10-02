import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

const project = 'aarast-full-staging-20261001';
const prodHosts = /(?:aarast(?:-api|-media|-admin)?\.shadowgardn\.com|aarast-production)/i;
const expectedServices = [
  'postgres', 'postgres-roles', 'migrate', 'backend', 'redis', 'media',
  'media-init', 'postgres-backup', 'admin-web', 'public-site',
];

export function validateStagingConfig(config, { allowExampleValues = false, allowBuildTopology = false } = {}) {
  const errors = [];
  const requireValue = (condition, message) => { if (!condition) errors.push(message); };
  const services = config.services ?? {};
  requireValue(config.name === project, 'Compose project must use the isolated staging name');
  requireValue(expectedServices.every((name) => services[name]), 'Full staging service set is incomplete');
  requireValue(Object.keys(services).every((name) => expectedServices.includes(name)), 'Unexpected service in staging project');
  requireValue(config.networks?.private?.internal === true, 'Database network must be internal');
  for (const [name, resource] of Object.entries(config.networks ?? {})) {
    requireValue(resource.name === `${project}_${name}` && !resource.external,
      `Network ${name} must be owned by this project`);
  }
  for (const [name, resource] of Object.entries(config.volumes ?? {})) {
    requireValue(resource.name === `${project}_${name}` && !resource.external,
      `Volume ${name} must be owned by this project`);
  }
  for (const [serviceName, volumeName, target] of [
    ['postgres', 'postgres_data', '/var/lib/postgresql/data'],
    ['postgres-backup', 'postgres_backups', '/backups'],
    ['media', 'media_data', '/data'],
  ]) {
    const mounts = services[serviceName]?.volumes ?? [];
    requireValue(mounts.length === 1 && mounts[0].type === 'volume' &&
      mounts[0].source === volumeName && mounts[0].target === target,
      `${serviceName} must use only its project-owned ${volumeName} volume`);
  }
  for (const [name, service] of Object.entries(services)) {
    requireValue(!service.container_name, `${name} must not use a global container name`);
    requireValue(!(service.networks && Object.keys(service.networks).some(
      (network) => !['private', 'edge'].includes(network))), `${name} joins an external network`);
    requireValue((service.ports ?? []).every((port) => port.host_ip === '127.0.0.1'),
      `${name} exposes a non-loopback port`);
    requireValue(!JSON.stringify(service).match(prodHosts), `${name} references Production`);
    if (!allowBuildTopology) requireValue(!service.build, `${name} must not build on the server`);
  }
  for (const [name, memory, cpus] of [
    ['postgres-roles', '134217728', 0.20],
    ['media-init', '134217728', 0.20],
    ['migrate', '805306368', 1.00],
  ]) {
    requireValue(services[name]?.mem_limit === memory && services[name]?.cpus === cpus,
      `${name} must retain its effective memory and CPU limits`);
  }
  for (const name of ['postgres', 'postgres-roles', 'migrate', 'redis', 'media-init', 'postgres-backup']) {
    requireValue(services[name]?.networks?.private === null && !services[name]?.networks?.edge,
      `${name} must stay private`);
  }
  const backend = services.backend?.environment ?? {};
  const migrate = services.migrate?.environment ?? {};
  const db = services.postgres?.environment ?? {};
  const roles = services['postgres-roles']?.environment ?? {};
  requireValue(backend.NODE_ENV === 'production', 'Backend must run production-like');
  requireValue(backend.READINESS_REQUIRE_REDIS === 'true' && backend.READINESS_REQUIRE_MEDIA === 'true',
    'Redis and media readiness must remain required');
  requireValue(/if \[ "\$\$\{PUSH_NOTIFICATIONS_ENABLED\}" = "true" \]; then\s+node scripts\/prod\/assert-firebase-credentials\.cjs\s+fi/.test(
    (services.backend?.command ?? []).join('\n')),
  'Firebase credential preflight must run only when Staging Push is enabled');
  requireValue(['true', 'false'].includes(backend.PUSH_NOTIFICATIONS_ENABLED),
    'Staging push setting must be explicit');
  requireValue(['disabled', 'whatsapp'].includes(backend.AUTH_OTP_MODE),
    'Staging OTP mode must be disabled or isolated WhatsApp');
  if (backend.PUSH_NOTIFICATIONS_ENABLED === 'true') {
    requireValue(Boolean(backend.FIREBASE_PROJECT_ID) &&
      backend.FIREBASE_PROJECT_ID !== 'aarast-d62e9' &&
      Boolean(backend.GOOGLE_APPLICATION_CREDENTIALS),
    'Enabled Staging push requires an isolated Firebase project and credential');
  } else {
    requireValue(!backend.FIREBASE_PROJECT_ID && !backend.GOOGLE_APPLICATION_CREDENTIALS &&
      !(services.backend?.volumes?.length),
    'Disabled Staging push must not mount or reference Firebase credentials');
  }
  if (backend.AUTH_OTP_MODE === 'whatsapp') {
    requireValue(['WHATSAPP_PHONE_NUMBER_ID', 'WHATSAPP_ACCESS_TOKEN',
      'WHATSAPP_OTP_TEMPLATE_NAME', 'WHATSAPP_VERIFY_TOKEN'].every((key) => Boolean(backend[key])),
    'Enabled Staging OTP requires an isolated Meta sender');
  } else {
    requireValue(!Object.keys(backend).some((key) =>
      key.startsWith('WHATSAPP_') || key.startsWith('OPENWA_') || key === 'AUTH_DEV_OTP_CODE'),
    'Disabled Staging OTP must not reference Meta, OpenWA or development credentials');
  }
  requireValue(backend.REDIS_URL === 'redis://redis:6379' && backend.AARAST_MEDIA_ENDPOINT === 'http://media:9000',
    'Backend must use staging Redis and media');
  requireValue(backend.DATABASE_URL?.includes('@postgres:5432/') &&
    migrate.DATABASE_URL?.includes('@postgres:5432/') &&
    backend.DATABASE_URL !== migrate.DATABASE_URL,
    'Runtime and migrator database URLs must be distinct and local');
  requireValue(new Set([db.POSTGRES_USER, roles.AARAST_DB_MIGRATOR_USER, roles.AARAST_DB_RUNTIME_USER]).size === 3,
    'Owner, migrator and runtime roles must be distinct');
  if (!allowExampleValues) {
    requireValue(new Set([db.POSTGRES_PASSWORD, roles.AARAST_DB_MIGRATOR_PASSWORD,
      roles.AARAST_DB_RUNTIME_PASSWORD]).size === 3,
    'Owner, migrator and runtime passwords must be distinct');
    requireValue(services.media?.environment?.MINIO_ROOT_USER !==
      services['media-init']?.environment?.AARAST_MEDIA_ACCESS_KEY_ID,
    'MinIO root and Backend access keys must be distinct');
  }
  requireValue(backend.AARAST_DB_EXPECTED_ROLE === roles.AARAST_DB_RUNTIME_USER &&
    migrate.AARAST_DB_EXPECTED_ROLE === roles.AARAST_DB_MIGRATOR_USER,
    'Database role identity checks must match');
  requireValue(services.backend?.depends_on?.migrate?.condition === 'service_completed_successfully' &&
    services.migrate?.depends_on?.['postgres-roles']?.condition === 'service_completed_successfully',
    'Backend must wait for roles and separate migration job');
  requireValue(services.backend?.depends_on?.['media-init']?.condition === 'service_completed_successfully' &&
    services.backend?.depends_on?.redis?.condition === 'service_healthy',
    'Backend must wait for media and Redis');
  requireValue(backend.CORS_ORIGINS === services['admin-web']?.environment?.ADMIN_PUBLIC_ORIGIN &&
    services['admin-web']?.environment?.API_ORIGIN !== undefined,
    'Admin/CORS API origins must be explicit');
  for (const key of ['CORS_ORIGINS', 'INVITE_PUBLIC_ORIGIN', 'AARAST_MEDIA_SIGNED_ENDPOINT']) {
    requireValue(isPublicHttpsOrigin(backend[key]), `${key} must be a public HTTPS origin`);
  }
  requireValue(isPublicHttpsOrigin(services['admin-web']?.environment?.API_ORIGIN),
    'Admin API must be a public HTTPS origin');
  requireValue(new Set([
    services['admin-web']?.environment?.API_ORIGIN,
    services['admin-web']?.environment?.ADMIN_PUBLIC_ORIGIN,
    backend.INVITE_PUBLIC_ORIGIN,
    backend.AARAST_MEDIA_SIGNED_ENDPOINT,
  ]).size === 4, 'API, Admin, invite and media must have four distinct origins');
  requireValue(backend.AARAST_MEDIA_PUBLIC_BASE_URL ===
    `${backend.AARAST_MEDIA_SIGNED_ENDPOINT}/${backend.AARAST_MEDIA_BUCKET}`,
    'Public media URL must match staging signed endpoint and bucket');
  if (backend.PUSH_NOTIFICATIONS_ENABLED === 'true') {
    requireValue(services.backend?.volumes?.length === 1 &&
      services.backend.volumes[0].type === 'bind' &&
      services.backend.volumes[0].read_only === true &&
      services.backend.volumes[0].target === '/run/aarast-firebase' &&
      services.backend.volumes[0].source?.toLowerCase().includes('staging'),
      'Firebase credential must come from a stage-only read-only bind');
  }
  for (const [name, prefix] of [
    ['backend', 'aarast-staging-backend:'],
    ['admin-web', 'aarast-staging-admin:'],
    ['public-site', 'aarast-staging-invite:'],
  ]) {
    requireValue(services[name]?.image?.startsWith(prefix), `${name} must use a staging-only image`);
  }
  if (allowBuildTopology) {
    requireValue(['backend', 'admin-web', 'public-site'].every((name) => services[name]?.build),
      'Off-host build topology must define all three staging images');
    const adminArgs = services['admin-web']?.build?.args ?? {};
    const inviteArgs = services['public-site']?.build?.args ?? {};
    const revision = adminArgs.AARAST_GIT_REVISION;
    requireValue(revision === services.backend?.build?.args?.AARAST_GIT_REVISION &&
      revision === inviteArgs.AARAST_GIT_REVISION,
      'All staging images must carry one candidate SHA');
    requireValue(adminArgs.AARAST_BUILD_TARGET === 'staging' &&
      adminArgs.VITE_API_BASE_URL === services['admin-web']?.environment?.API_ORIGIN,
      'Admin build must target the explicit staging API');
    requireValue(inviteArgs.STAGING_INVITE_ORIGIN === backend.INVITE_PUBLIC_ORIGIN &&
      inviteArgs.STAGING_QA_INVITE_HOST === hostnameOf(backend.INVITE_PUBLIC_ORIGIN),
      'QA App Link host must match staging invite origin');
    requireValue(inviteArgs.STAGING_QA_APPLICATION_ID !== 'com.aarast.aarast_mobile',
      'QA application ID must differ from Production');
    if (!allowExampleValues) {
      requireValue(/^[0-9a-f]{40}$/.test(revision) &&
        ['backend', 'admin-web', 'public-site'].every((name) =>
          services[name]?.image?.endsWith(`:${revision}`)),
      'Stage image tags must equal their full candidate SHA');
    }
  }
  if (!allowExampleValues) {
    const revisions = ['backend', 'admin-web', 'public-site'].map((name) =>
      services[name]?.image?.match(/:([0-9a-f]{40})$/)?.[1]);
    requireValue(revisions.every((revision) => revision && revision === revisions[0]),
      'Stage image tags must share one full candidate SHA');
  }
  if (!allowExampleValues) {
    requireValue(!/(?:REPLACE_WITH|GENERATE_UNIQUE|example\.invalid)/.test(JSON.stringify(config)),
      'Staging config still contains example placeholder values');
  }
  return errors;
}

function isPublicHttpsOrigin(value) {
  if (typeof value !== 'string') return false;
  try {
    const url = new URL(value);
    return url.protocol === 'https:' && url.origin === value &&
      !url.username && !url.password && !/^(localhost|127\.|10\.|192\.168\.)/.test(url.hostname);
  } catch { return false; }
}

function hostnameOf(value) {
  try { return new URL(value).hostname; } catch { return undefined; }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const errors = validateStagingConfig(JSON.parse(readFileSync(0, 'utf8')));
  if (errors.length) {
    console.error(errors.join('\n'));
    process.exitCode = 1;
  } else console.log('PASS: isolated staging config');
}
