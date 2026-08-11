#!/usr/bin/env node
'use strict';

const { assertManagedSmokeEnvironment } = require('./smoke-utils');

assertManagedSmokeEnvironment();

const baseUrl = process.env.SMOKE_BASE_URL.replace(/\/$/, '');
let failed = 0;

function check(label, condition) {
  console.log(`${condition ? 'PASS' : 'FAIL'} - ${label}`);
  if (!condition) failed += 1;
}

async function getBootstrap(version) {
  const query = version ? `?version=${encodeURIComponent(version)}` : '';
  const response = await fetch(`${baseUrl}/api/v1/catalogs/bootstrap${query}`);
  const body = await response.json().catch(() => null);
  return { response, body };
}

async function run() {
  const first = await getBootstrap();
  check('bootstrap returns HTTP 200', first.response.status === 200);
  check(
    'bootstrap returns a stable version token',
    typeof first.body?.version === 'string' &&
      /^[a-f0-9]{24}$/.test(first.body.version),
  );
  check('first bootstrap contains data', first.body?.unchanged === false);

  const moneyCatalog = first.body?.catalogs?.find(
    (catalog) => catalog.key === 'money.starter.categories',
  );
  check('published Money starter catalog is present', Boolean(moneyCatalog));
  check(
    'Money starter catalog contains published items',
    Array.isArray(moneyCatalog?.items) && moneyCatalog.items.length >= 40,
  );
  check(
    'Money items include groom and bride audiences',
    moneyCatalog?.items?.some(
      (item) => item.showForGroom === true && item.showForBride === false,
    ) &&
      moneyCatalog?.items?.some(
        (item) => item.showForBride === true && item.showForGroom === false,
      ),
  );
  check(
    'catalog bootstrap returns dynamic marketplace and location arrays',
    Array.isArray(first.body?.providerCategories) &&
      Array.isArray(first.body?.cities) &&
      Array.isArray(first.body?.governorates),
  );

  if (typeof first.body?.version === 'string') {
    const second = await getBootstrap(first.body.version);
    check('versioned bootstrap returns HTTP 200', second.response.status === 200);
    check('matching version returns unchanged', second.body?.unchanged === true);
    check(
      'unchanged response keeps the same version',
      second.body?.version === first.body.version,
    );
    check(
      'unchanged response omits duplicate payload',
      second.body?.catalogs === undefined,
    );
  }

  if (failed > 0) {
    console.error(`Reference Catalog Smoke Result: FAIL (${failed} checks)`);
    process.exit(1);
  }
  console.log('Reference Catalog Smoke Result: PASS');
}

run().catch((error) => {
  console.error('Reference Catalog Smoke Result: FAIL');
  console.error(error instanceof Error ? error.message : String(error));
  process.exit(1);
});
