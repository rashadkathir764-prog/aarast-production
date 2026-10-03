'use strict';

// Execute the installed library and hardened adapter, replacing only WhatsApp's
// external browser modules. No messages, credentials, or session files are used.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { createRequire } = require('node:module');
const test = require('node:test');
const appRequire = createRequire(path.join(process.cwd(), 'package.json'));
const { Client } = appRequire('whatsapp-web.js');
const { WhatsAppWebJsAdapter } = appRequire('./dist/engine/adapters/whatsapp-web-js.adapter.js');
const { EngineStatus } = appRequire('./dist/engine/interfaces/whatsapp-engine.interface.js');
const { TransientTransportUnavailableError } = appRequire('./dist/common/errors/transient-transport-unavailable.error.js');
const utilsSource = fs.readFileSync(appRequire.resolve('whatsapp-web.js/src/util/Injected/Utils.js'), 'utf8');
const fixtureId = 'true_100000000001@lid_FIXTURE';
const recipient = '100000000001@lid';

function fixture({ renamed = true, ack = 2, laterAck, missingId = false, timestamp = 1706868000, sendReject = false } = {}) {
  const messages = new Map();
  let sends = 0;
  const wid = { _serialized: recipient, isLid: () => true };
  class MsgKey {
    constructor() { if (!missingId) this[renamed ? '$1' : '_serialized'] = fixtureId; }
    static async newId() { return 'FIXTURE'; }
  }
  const modules = {
    WAWebChatGetters: { getIsNewsletter: () => false, getIsBroadcast: () => false },
    WALinkify: { findLink: () => null, findLinks: () => [] },
    WAWebUserPrefsMeUser: { getMaybeMeLidUser: () => wid, getMaybeMePnUser: () => wid },
    WAWebMsgKey: MsgKey,
    WAWebGetEphemeralFieldsMsgActionsUtils: { getEphemeralFields: () => ({}) },
    WAWebCollections: { Msg: { get: id => messages.get(id) } },
    WAWebSendMsgChatAction: { addAndSendMsgToChat(_chat, data) {
      sends++;
      if (sendReject) throw new Error('External send rejected');
      const model = { ...data, ack, t: timestamp, serialize() {
        return { id: { ...data.id, remote: recipient, fromMe: true }, ack: this.ack,
          t: this.t, body: data.body, from: recipient, to: recipient, type: 'chat' };
      } };
      if (!missingId) messages.set(fixtureId, model);
      return [Promise.resolve(model), Promise.resolve()];
    } },
  };
  const context = vm.createContext({ exports: {}, window: { require(name) {
    if (!(name in modules)) throw new Error('Unused browser module');
    return modules[name];
  } } });
  vm.runInContext(utilsSource, context);
  context.exports.LoadUtils();
  context.window.WWebJS.getChat = async () => ({ id: wid });
  const adapter = new WhatsAppWebJsAdapter({ sessionId: 'fixture', sessionDataPath: '/unused' });
  adapter.status = EngineStatus.READY;
  adapter.logTransientRouteOutcome = () => {};
  const client = {
    getNumberId: async () => wid,
    pupPage: { async evaluate(fn, ...args) {
      context.args = args;
      return vm.runInContext(`(${fn.toString()})(...args)`, context);
    } },
    async sendMessage(...args) {
      const message = await Client.prototype.sendMessage.apply(client, args);
      if (laterAck !== undefined) setTimeout(() => adapter.rememberTransientAck(fixtureId,
        laterAck === 2 ? 'delivered' : laterAck === 3 ? 'read' : 'failed'), 20);
      return message;
    },
  };
  adapter.client = client;
  return { adapter, client, context, sends: () => sends };
}

test('real $1-only message key returns a complete message and device-confirmed transient delivery', async () => {
  const { adapter } = fixture();
  const result = await adapter.sendTransientTextMessage('100000000001@c.us', 'random test body');
  assert.deepEqual(result, { id: fixtureId, timestamp: 1706868000 });
});

test('legacy _serialized message key still returns the same contract', async () => {
  const { adapter } = fixture({ renamed: false });
  assert.deepEqual(await adapter.sendTransientTextMessage('100000000001@c.us', 'test body'),
    { id: fixtureId, timestamp: 1706868000 });
});

test('returned message uses the real renamed identifier without losing timestamp or ACK', async () => {
  const { client } = fixture();
  const message = await client.sendMessage(recipient, 'test body', { sendSeen: false, linkPreview: false, waitUntilMsgSent: true });
  assert.equal(message?.id?._serialized, fixtureId);
  assert.equal(message.timestamp, 1706868000);
  assert.equal(message.ack, 2);
});

test('server ACK alone waits for the installed adapter device ACK event', async () => {
  const { adapter } = fixture({ ack: 1, laterAck: 2 });
  assert.equal((await adapter.sendTransientTextMessage('100000000001@c.us', 'test body')).id, fixtureId);
});

test('negative ACK remains a definitive post-send failure', async () => {
  const { adapter } = fixture({ ack: -1 });
  await assert.rejects(adapter.sendTransientTextMessage('100000000001@c.us', 'test body'),
    error => error instanceof TransientTransportUnavailableError && error.sendEntered && !error.deliveryUncertain);
});

test('missing identifier remains uncertain even if send did not throw', async () => {
  const { adapter } = fixture({ missingId: true });
  await assert.rejects(adapter.sendTransientTextMessage('100000000001@c.us', 'test body'),
    error => error instanceof TransientTransportUnavailableError && error.deliveryUncertain);
});

test('missing timestamp remains uncertain despite a valid identifier and device ACK', async () => {
  const { adapter } = fixture({ timestamp: 0 });
  await assert.rejects(adapter.sendTransientTextMessage('100000000001@c.us', 'test body'),
    error => error instanceof TransientTransportUnavailableError && error.deliveryUncertain);
});

test('send exception stays uncertain and never resends', async () => {
  const { adapter, sends } = fixture({ sendReject: true });
  await assert.rejects(adapter.sendTransientTextMessage('100000000001@c.us', 'test body'),
    error => error instanceof TransientTransportUnavailableError && error.deliveryUncertain);
  assert.equal(sends(), 1);
});

test('device ACK timeout remains uncertain; server acceptance is not delivery', async () => {
  const { adapter } = fixture({ ack: 1 });
  const keepAlive = setTimeout(() => {}, 12000);
  try {
    await assert.rejects(adapter.sendTransientTextMessage('100000000001@c.us', 'test body'),
      error => error instanceof TransientTransportUnavailableError && error.deliveryUncertain);
  } finally { clearTimeout(keepAlive); }
});
