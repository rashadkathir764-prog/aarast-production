const baseUrl = (process.env.SMOKE_BASE_URL || 'http://localhost:3105').replace(/\/$/, '');
const healthUrl = `${baseUrl}/health`;

async function run() {
  try {
    const response = await fetch(healthUrl);
    const body = await response.json().catch(() => null);
    const checks = [
      ['HTTP 200', response.status === 200],
      ['status is ok', body?.status === 'ok'],
      ['service is aarast-backend', body?.service === 'aarast-backend'],
    ];
    const failed = checks.filter(([, passed]) => !passed);

    console.log(`Health Smoke Report`);
    console.log(`Target: ${healthUrl}`);
    for (const [name, passed] of checks) {
      console.log(`${passed ? 'PASS' : 'FAIL'} - ${name}`);
    }

    if (failed.length > 0) {
      console.error(`Overall Result: FAIL`);
      process.exit(1);
    }

    console.log(`Overall Result: PASS`);
  } catch (error) {
    console.error(`Health Smoke Report`);
    console.error(`Target: ${healthUrl}`);
    console.error(`Overall Result: FAIL`);
    console.error(error instanceof Error ? error.message : String(error));
    process.exit(1);
  }
}

void run();
