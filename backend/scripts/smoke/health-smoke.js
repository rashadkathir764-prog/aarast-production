const baseUrl = (process.env.SMOKE_BASE_URL || 'http://127.0.0.1:3115').replace(
  /\/$/,
  '',
);

async function check(path, expectedStatus) {
  const url = `${baseUrl}${path}`;
  const response = await fetch(url);
  const body = await response.json().catch(() => null);
  return {
    url,
    checks: [
      ['HTTP 200', response.status === 200],
      [`status is ${expectedStatus}`, body?.status === expectedStatus],
      ['service is aarast-backend', body?.service === 'aarast-backend'],
      ...(path === '/ready'
        ? [
            ['database is up', body?.checks?.database?.status === 'up'],
            [
              'no required dependency is down',
              Object.values(body?.checks ?? {}).every(
                (value) => value?.status !== 'down',
              ),
            ],
          ]
        : []),
    ],
  };
}

async function run() {
  try {
    const reports = await Promise.all([
      check('/live', 'ok'),
      check('/ready', 'ready'),
    ]);
    const failed = reports.flatMap((report) =>
      report.checks.filter(([, passed]) => !passed),
    );

    console.log('Health Smoke Report');
    for (const report of reports) {
      console.log(`Target: ${report.url}`);
      for (const [name, passed] of report.checks) {
        console.log(`${passed ? 'PASS' : 'FAIL'} - ${name}`);
      }
    }

    if (failed.length > 0) {
      console.error('Overall Result: FAIL');
      process.exit(1);
    }
    console.log('Overall Result: PASS');
  } catch (error) {
    console.error('Health Smoke Report');
    console.error(`Target: ${baseUrl}`);
    console.error('Overall Result: FAIL');
    console.error(error instanceof Error ? error.message : String(error));
    process.exit(1);
  }
}

void run();
