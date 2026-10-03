import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

const project = 'aarast-full-staging-20261001';
const prodHosts = /(?:aarast(?:-api|-media|-admin)?\.shadowgardn\.com|aarast-production)/i;
const expectedServices = [
  'postgres', 'postgres-roles', 'migrate', 'backend', 'redis', 'media',
  'media-init', 'postgres-backup', 'admin-web', 'public-site',
];
const cutoverOrigins = {
  api: 'https://aarast-api.shadowgardn.com', admin: 'https://aarast-admin.shadowgardn.com',
  invite: 'https://aarast.shadowgardn.com', media: 'https://aarast-media.shadowgardn.com',
};
export const cutoverMediaLabels = {
  'traefik.enable': 'true',
  'traefik.docker.network': 'aarast-production-ytxoik_aarast_internal',
  'traefik.http.routers.aarast-media-secure.entrypoints': 'websecure',
  'traefik.http.routers.aarast-media-secure.rule': 'Host(`aarast-media.shadowgardn.com`)',
  'traefik.http.routers.aarast-media-secure.service': 'aarast-media',
  'traefik.http.routers.aarast-media-secure.tls.certresolver': 'letsencrypt',
  'traefik.http.routers.aarast-media-web.entrypoints': 'web',
  'traefik.http.routers.aarast-media-web.middlewares': 'redirect-to-https@file',
  'traefik.http.routers.aarast-media-web.rule': 'Host(`aarast-media.shadowgardn.com`)',
  'traefik.http.routers.aarast-media-web.service': 'aarast-media',
  'traefik.http.services.aarast-media.loadbalancer.server.port': '9000',
};

export function validateStagingConfig(config, {
  allowExampleValues = false, allowBuildTopology = false, phoneAcceptance = false,
} = {}) {
  const errors = [];
  const requireValue = (condition, message) => { if (!condition) errors.push(message); };
  const services = config.services ?? {};
  const routeProfile = services.backend?.environment?.AARAST_STAGING_ROUTE_PROFILE ?? 'isolated';
  requireValue(['isolated', 'aarast-controlled-cutover'].includes(routeProfile), 'Unknown staging route profile');
  const cutover = routeProfile === 'aarast-controlled-cutover';
  requireValue(config.name === project, 'Compose project must use the isolated staging name');
  requireValue(expectedServices.every((name) => services[name]), 'Full staging service set is incomplete');
  requireValue(Object.keys(services).every((name) => expectedServices.includes(name)), 'Unexpected service in staging project');
  requireValue(config.networks?.private?.internal === true, 'Database network must be internal');
  for (const [name, resource] of Object.entries(config.networks ?? {})) {
    if (cutover && name === 'edge') {
      requireValue(resource.external === true && resource.name === 'aarast-production-ytxoik_aarast_internal',
        'Cutover edge must use only the verified existing Aarast network');
      continue;
    }
    if (cutover && phoneAcceptance && name === 'otp_transport') {
      requireValue(resource.external === true && resource.name === 'aarast_full_staging_openwa_test_release_transport',
        'Cutover OTP transport must use only the independent Staging network');
      continue;
    }
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
      (network) => !['private', 'edge'].includes(network) &&
        !(cutover && phoneAcceptance && name === 'backend' && network === 'otp_transport'))), `${name} joins an external network`);
    requireValue((service.ports ?? []).every((port) => port.host_ip === '127.0.0.1'),
      `${name} exposes a non-loopback port`);
    const scanned = structuredClone(service);
    if (cutover) {
      const permitted = name === 'backend' ? {
        CORS_ORIGINS: cutoverOrigins.admin, INVITE_PUBLIC_ORIGIN: cutoverOrigins.invite,
        AARAST_MEDIA_SIGNED_ENDPOINT: cutoverOrigins.media,
        AARAST_MEDIA_PUBLIC_BASE_URL: `${cutoverOrigins.media}/${service.environment?.AARAST_MEDIA_BUCKET}`,
      } : name === 'admin-web' ? {
        API_ORIGIN: cutoverOrigins.api, ADMIN_PUBLIC_ORIGIN: cutoverOrigins.admin, CORS_ORIGINS: cutoverOrigins.admin,
      } : {};
      for (const [key, value] of Object.entries(permitted)) {
        requireValue(service.environment?.[key] === value, `${name} ${key} must match the approved cutover origin`);
        if (scanned.environment?.[key] === value) delete scanned.environment[key];
      }
      if (scanned.build?.args) {
        const buildInputs = name === 'admin-web' ? { VITE_API_BASE_URL: cutoverOrigins.api } :
          name === 'public-site' ? { STAGING_INVITE_ORIGIN: cutoverOrigins.invite, STAGING_QA_INVITE_HOST: 'aarast.shadowgardn.com' } : {};
        for (const [key, value] of Object.entries(buildInputs)) {
          requireValue(scanned.build.args[key] === value, `${name} build origin must match cutover`);
          if (scanned.build.args[key] === value) delete scanned.build.args[key];
        }
      }
      for (const [key, value] of Object.entries(scanned.labels ?? {})) {
        if (name === 'media' && cutoverMediaLabels[key] === value) delete scanned.labels[key];
      }
    }
    requireValue(!JSON.stringify(scanned).match(prodHosts), `${name} references Production`);
    if (Object.keys(service.labels ?? {}).some((key) => key.startsWith('traefik.'))) {
      requireValue(cutover && name === 'media' &&
        JSON.stringify(Object.entries(service.labels).sort()) === JSON.stringify(Object.entries(cutoverMediaLabels).sort()),
      `${name} has unapproved proxy routes`);
    }
    if (!allowBuildTopology) requireValue(!service.build, `${name} must not build on the server`);
  }
  if (cutover) {
    for (const [name, alias, port, target] of [
      ['backend', 'aarast-backend-prod', '8093', 3000],
      ['admin-web', 'aarast-admin-web-prod', '8094', 80],
      ['public-site', 'aarast-public-site-prod', '8095', 80],
    ]) {
      requireValue(JSON.stringify(services[name]?.networks?.edge?.aliases) === JSON.stringify([alias]),
        `${name} must retain only its verified Aarast route alias`);
      const ports = services[name]?.ports ?? [];
      requireValue(ports.length === 1 && String(ports[0].published) === port && ports[0].target === target,
        `${name} must reuse only its verified Aarast port`);
    }
    requireValue(!(services.media?.ports?.length), 'Cutover media must not create a new host port');
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
  requireValue(backend.AARAST_DEPLOYMENT_TIER === 'staging',
    'Backend must declare the isolated staging deployment identity');
  requireValue(backend.READINESS_REQUIRE_REDIS === 'true' && backend.READINESS_REQUIRE_MEDIA === 'true',
    'Redis and media readiness must remain required');
  requireValue(/if \[ "\$\$\{PUSH_NOTIFICATIONS_ENABLED\}" = "true" \]; then\s+node scripts\/prod\/assert-firebase-credentials\.cjs\s+fi/.test(
    (services.backend?.command ?? []).join('\n')),
  'Firebase credential preflight must run only when Staging Push is enabled');
  requireValue(backend.PUSH_NOTIFICATIONS_ENABLED === (phoneAcceptance ? 'true' : 'false'),
    'Core Push must be disabled; phone acceptance requires isolated Firebase');
  requireValue(backend.AUTH_OTP_MODE === (phoneAcceptance ? 'openwa' : 'disabled'),
    'Core OTP must be disabled; phone acceptance requires isolated OpenWA');
  if (backend.PUSH_NOTIFICATIONS_ENABLED === 'true') {
    requireValue(Boolean(backend.FIREBASE_PROJECT_ID) &&
      backend.FIREBASE_PROJECT_ID === 'aarast-staging-qa' &&
      backend.GOOGLE_APPLICATION_CREDENTIALS === '/run/aarast-firebase/service-account.json',
    'Enabled Staging push requires an isolated Firebase project and credential');
  } else {
    requireValue(!backend.FIREBASE_PROJECT_ID && !backend.GOOGLE_APPLICATION_CREDENTIALS &&
      !(services.backend?.volumes?.length),
    'Disabled Staging push must not mount or reference Firebase credentials');
  }
  if (backend.AUTH_OTP_MODE === 'openwa') {
    const rawOpenWaUrl = backend.OPENWA_BASE_URL;
    let openWaUrl;
    try { openWaUrl = new URL(rawOpenWaUrl); } catch { /* rejected below */ }
    requireValue(Boolean(openWaUrl) &&
      ['https:', 'http:'].includes(openWaUrl.protocol) &&
      !openWaUrl.username && !openWaUrl.password &&
      openWaUrl.pathname === '/' && !openWaUrl.search && !openWaUrl.hash &&
      /(?:staging|test)/i.test(openWaUrl.hostname) &&
      !/(?:^aarast-openwa-otp$|otp-lab-api\.shadowgardn\.com$)/i.test(openWaUrl.hostname) &&
      (openWaUrl.protocol === 'https:' ||
        openWaUrl.hostname.endsWith('.internal') || openWaUrl.hostname.endsWith('.local')),
    'OpenWA must use a dedicated Staging/Test HTTPS or private endpoint');
    requireValue(backend.OPENWA_CREDENTIAL_FILE === '/run/aarast-openwa-staging/openwa.env' &&
      !backend.OPENWA_SESSION_ID && !backend.OPENWA_API_KEY &&
      !backend.AUTH_DEV_OTP_CODE &&
      !Object.keys(backend).some((key) => key.startsWith('WHATSAPP_')),
    'OpenWA must use only its dedicated Staging/Test credential file');
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
  requireValue(db.POSTGRES_DB === 'aarast_staging' &&
    backend.POSTGRES_DB === db.POSTGRES_DB &&
    roles.AARAST_DB_RUNTIME_USER === 'aarast_stage_runtime',
    'Staging database and runtime role must match the backend deployment guard');
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
  if (phoneAcceptance) {
    const mounts = services.backend?.volumes ?? [];
    const byTarget = (target) => mounts.find((mount) => mount.target === target);
    requireValue(mounts.length === 2 &&
      ['/run/aarast-firebase', '/run/aarast-openwa-staging'].every((target) =>
        mounts.filter((mount) => mount.target === target).length === 1),
    'Phone integrations require only Firebase and OpenWA credential binds');
    for (const [target, label] of [
      ['/run/aarast-firebase', 'Firebase'],
      ['/run/aarast-openwa-staging', 'OpenWA'],
    ]) {
      const mount = byTarget(target);
      requireValue(mount?.type === 'bind' && mount.read_only === true &&
        mount.source?.replaceAll('\\', '/').startsWith('/var/lib/aarast-staging-test/') &&
        !mount.source?.includes('/aarast-otp-staging/'),
      `${label} credential must come from its separate Staging/Test read-only path`);
    }
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
    requireValue((adminArgs.STAGING_ROUTE_PROFILE ?? 'isolated') === routeProfile &&
      (inviteArgs.STAGING_ROUTE_PROFILE ?? 'isolated') === routeProfile,
    'Build and runtime route profiles must match');
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

export function validateOpenWaStagingConfig(config, { allowExampleValues = false } = {}) {
  const errors = [];
  const requireValue = (condition, message) => { if (!condition) errors.push(message); };
  const projectName = 'aarast-full-staging-openwa-test-release';
  const services = config.services ?? {};
  const serviceNames = ['openwa', 'openwa-bootstrap', 'openwa-credential-rotator', 'storage-init'];
  const secureRoot = '/var/lib/aarast-full-staging-openwa-test/secure';
  requireValue(config.name === projectName, 'OpenWA must use its dedicated Staging project');
  requireValue(serviceNames.every((name) => services[name]) &&
    Object.keys(services).every((name) => serviceNames.includes(name)),
  'OpenWA Staging service set must be isolated from Backend and old OTP lab');
  requireValue(config.networks?.transport?.internal === true &&
    config.networks?.egress?.internal !== true,
  'OpenWA transport must be internal while its own egress stays separate');
  for (const [name, network] of Object.entries(config.networks ?? {})) {
    requireValue(['transport', 'egress'].includes(name) &&
      network.name === `aarast_full_staging_openwa_test_release_${name}` &&
      !network.external,
    `OpenWA network ${name} must belong only to Staging`);
  }
  requireValue(!Object.keys(config.volumes ?? {}).length,
    'OpenWA Staging must use only its dedicated encrypted host path');
  for (const [name, service] of Object.entries(services)) {
    requireValue(!service.container_name && !service.build,
      `${name} must not reuse a container or build on the server`);
    requireValue((service.ports ?? []).every((port) => port.host_ip === '127.0.0.1') &&
      (name === 'openwa' || !(service.ports ?? []).length),
    `${name} may publish only the OpenWA loopback operator port`);
    for (const mount of service.volumes ?? []) {
      const source = String(mount.source ?? '').replaceAll('\\', '/');
      requireValue(!source.includes('/var/lib/aarast-otp-staging/') &&
        mount.target !== '/run/aarast/production',
      `${name} must not mount the old shared OpenWA session or Production credential`);
      if (mount.target !== '/opt/bootstrap-openwa.mjs') {
        requireValue(source === secureRoot || source.startsWith(`${secureRoot}/`),
          `${name} requires its dedicated encrypted Staging OpenWA path`);
      } else {
        requireValue(mount.read_only === true &&
          source.endsWith('/deploy/openwa-otp-staging/bootstrap-openwa.mjs'),
        `${name} must mount the reviewed bootstrap script read-only`);
      }
    }
  }
  requireValue(services.openwa?.mem_limit === '2147483648' &&
    services.openwa?.cpus === 1.5,
  'OpenWA must retain its proven 2 GiB / 1.5 CPU limit');
  requireValue((services.openwa?.ports ?? []).length === 1,
    'OpenWA requires exactly one loopback operator port');
  requireValue(services['storage-init']?.network_mode === 'none' &&
    (services['storage-init']?.command ?? []).join('\n').includes(
      '.aarast-full-staging-openwa-encrypted'),
  'OpenWA storage init must require the dedicated encrypted mount marker');
  for (const name of ['openwa-bootstrap', 'openwa-credential-rotator']) {
    const env = services[name]?.environment ?? {};
    requireValue(env.OPENWA_BOOTSTRAP_PROFILE === 'isolated-staging' &&
      env.OPENWA_SESSION_NAME === 'aarast-full-staging-test-release',
    `${name} requires the independent Staging session profile`);
    requireValue(env.OPENWA_STAGING_TRANSPORT_SECRET_PATH ===
      '/run/aarast/staging/openwa.env' &&
      !env.OPENWA_PRODUCTION_TRANSPORT_SECRET_PATH,
    `${name} must issue only a Staging transport credential`);
    requireValue((services[name]?.volumes ?? []).some((mount) =>
      mount.target === '/run/aarast/staging' &&
      mount.source === `${secureRoot}/backend-secret`) &&
      !(services[name]?.volumes ?? []).some((mount) =>
        /production/i.test(mount.target)),
    `${name} must mount only the dedicated Staging credential path`);
  }
  if (!allowExampleValues) {
    requireValue(/^(?:sha256:[a-f0-9]{64}|[^\s]+@sha256:[a-f0-9]{64})$/.test(
      services.openwa?.image ?? ''),
    'OpenWA image must be an immutable reviewed ID or digest');
    requireValue(!/replace-with|example\.invalid/i.test(JSON.stringify(config)),
      'OpenWA Staging config still contains example placeholders');
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
  const mode = process.argv[2];
  if (mode && !['--phone-acceptance', '--openwa'].includes(mode)) {
    console.error('Unknown staging validation mode');
    process.exit(2);
  }
  const config = JSON.parse(readFileSync(0, 'utf8'));
  const errors = mode === '--openwa'
    ? validateOpenWaStagingConfig(config)
    : validateStagingConfig(config, { phoneAcceptance: mode === '--phone-acceptance' });
  if (errors.length) {
    console.error(errors.join('\n'));
    process.exitCode = 1;
  } else console.log('PASS: isolated staging config');
}
