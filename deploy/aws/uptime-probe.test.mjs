import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { test } from 'node:test';

// RA-BE-02, RA-OP-06: what the uptime probe in uptime.yaml reports for each
// answer of /ready. The probe's own code is read from the template and run
// against a fake fetch and a fake CloudWatch, so the alarms are pinned by
// what the deployed code does, not by a copy of it.
function probeCode() {
  const lines = readFileSync(resolve('deploy/aws/uptime.yaml'), 'utf8').split(/\r?\n/);
  const start = lines.findIndex((line) => line.trim() === 'ZipFile: |') + 1;
  const indent = lines[start].match(/^\s*/)[0].length;
  const body = [];
  for (const line of lines.slice(start)) {
    if (line.trim() !== '' && line.match(/^\s*/)[0].length < indent) break;
    body.push(line.slice(indent));
  }
  return body.join('\n');
}

async function probe(answers) {
  const sent = [];
  const module = { exports: {} };
  const require = (name) => {
    assert.equal(name, '@aws-sdk/client-cloudwatch');
    return {
      CloudWatchClient: class { async send(command) { sent.push(command.input); } },
      PutMetricDataCommand: class { constructor(input) { this.input = input; } },
    };
  };
  const realFetch = globalThis.fetch;
  globalThis.fetch = async (url) => {
    const answer = answers[url];
    if (answer === undefined) throw new TypeError('fetch failed');
    return { json: async () => answer };
  };
  const realLog = console.log;
  console.log = () => {};
  process.env.READY_URL = 'https://named/ready';
  process.env.DIRECT_READY_URL = 'https://direct/ready';
  try {
    new Function('require', 'exports', 'module', probeCode())(require, module.exports, module);
    await module.exports.handler();
  } finally {
    globalThis.fetch = realFetch;
    console.log = realLog;
  }
  return Object.fromEntries(sent[0].MetricData.map((m) => [m.MetricName, m.Value]));
}

const up = { status: 'up' };
const healthy = {
  checks: {
    database: up, redis: up, media: up, openwa: up,
    otpCapacity: { status: 'up' }, disk: { status: 'up' },
  },
};

test('a healthy host reads one on every metric', async () => {
  assert.deepEqual(
    await probe({ 'https://named/ready': healthy, 'https://direct/ready': healthy }),
    { Api: 1, WhatsApp: 1, WhatsAppCapacity: 1, Disk: 1, DirectIp: 1 },
  );
});

test('the code limit and the disk warn from the answer', async () => {
  const warned = { checks: { ...healthy.checks, otpCapacity: { status: 'near_limit' }, disk: { status: 'low' } } };
  const metrics = await probe({ 'https://named/ready': warned, 'https://direct/ready': warned });
  assert.equal(metrics.WhatsAppCapacity, 0);
  assert.equal(metrics.Disk, 0);
  assert.equal(metrics.Api, 1);
  const exhausted = { checks: { ...healthy.checks, otpCapacity: { status: 'down' } } };
  assert.equal((await probe({ 'https://named/ready': exhausted })).WhatsAppCapacity, 0);
});

test('an unreachable API is the Api alarm alone, not a limit or disk warning', async () => {
  assert.deepEqual(await probe({}), {
    Api: 0, WhatsApp: 0, WhatsAppCapacity: 1, Disk: 1, DirectIp: 0,
  });
});

test('a server older than a check, with no field for it, warns of nothing', async () => {
  const older = { checks: { database: up, redis: up, media: up, openwa: up } };
  const metrics = await probe({ 'https://named/ready': older, 'https://direct/ready': older });
  assert.equal(metrics.WhatsAppCapacity, 1);
  assert.equal(metrics.Disk, 1);
});

test('the direct address counts only when it answers with the database up', async () => {
  const metrics = await probe({ 'https://named/ready': healthy });
  assert.equal(metrics.DirectIp, 0, 'an expired IP certificate fails the fetch');
});
