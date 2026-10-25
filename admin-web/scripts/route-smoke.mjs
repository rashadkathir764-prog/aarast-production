import { spawn } from 'node:child_process';
import { join } from 'node:path';

const host = '127.0.0.1';
const port = Number(process.env.ADMIN_WEB_SMOKE_PORT ?? '4173');
const baseUrl = `http://${host}:${port}`;
const routes = [
  '/',
  '/login',
  '/users',
  '/users/example-user-id',
  '/providers',
  '/providers/applications',
  '/categories',
  '/cities',
  '/services',
  '/reviews',
  '/bookings',
  '/conversation-reports',
  '/providers/listed',
  '/featured',
  '/reference-catalogs',
  '/administrative-areas',
  '/audit-logs',
  '/reports',
  '/providers/new',
  '/services/new',
  '/admin',
];

const viteCli = join(process.cwd(), 'node_modules', 'vite', 'bin', 'vite.js');
const preview = spawn(
  process.execPath,
  [viteCli, 'preview', '--host', host, '--port', String(port)],
  {
    cwd: process.cwd(),
    stdio: ['ignore', 'pipe', 'pipe'],
  },
);

let output = '';
preview.stdout.on('data', (chunk) => {
  output += chunk.toString();
});
preview.stderr.on('data', (chunk) => {
  output += chunk.toString();
});

async function waitForPreview() {
  for (let attempt = 0; attempt < 40; attempt += 1) {
    try {
      const response = await fetch(baseUrl);
      if (response.ok) return;
    } catch {
      await new Promise((resolve) => setTimeout(resolve, 250));
    }
  }

  throw new Error(`Vite preview did not become ready at ${baseUrl}.\n${output}`);
}

try {
  await waitForPreview();

  for (const route of routes) {
    const response = await fetch(`${baseUrl}${route}`);
    if (response.status !== 200) {
      throw new Error(`Route ${route} returned HTTP ${response.status}`);
    }
    console.log(`PASS ${route} ${response.status}`);
  }
} finally {
  preview.kill();
}
