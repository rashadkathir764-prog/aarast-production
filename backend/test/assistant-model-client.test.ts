import assert from 'node:assert/strict';
import { createServer, type IncomingMessage, type ServerResponse } from 'node:http';
import { createServer as createNetServer } from 'node:net';
import type { AddressInfo } from 'node:net';
import { test } from 'node:test';
import { AssistantModelError, ClaudeAssistantModel } from '../src/dashboard/assistant/assistant-model.client';

// RA-BE-165: the Claude client behind the assistant, against a local stand-in
// for the API. Every attempt may be billed and a question reserves one call,
// so the client never retries on its own; a failure after the request may
// have been sent is UNANSWERED (its reserved cost is kept), and only a
// refusal or a connection that never opened is BUSY (given back).

const request = { model: 'claude-opus-5-5', system: 'قواعد', userText: 'سؤال' };

async function standIn(answer: (req: IncomingMessage, res: ServerResponse) => void) {
  let hits = 0;
  const server = createServer((req, res) => {
    hits += 1;
    req.resume();
    req.on('end', () => answer(req, res));
  });
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address() as AddressInfo;
  return {
    baseURL: `http://127.0.0.1:${port}`,
    hits: () => hits,
    close: () => new Promise<void>((resolve) => {
      server.closeAllConnections();
      server.close(() => resolve());
    }),
  };
}

async function failure(model: ClaudeAssistantModel): Promise<AssistantModelError> {
  try {
    await model.ask(request);
  } catch (error) {
    assert.ok(error instanceof AssistantModelError, String(error));
    return error;
  }
  assert.fail('the call answered');
}

const json = (res: ServerResponse, status: number, body: unknown) => {
  res.writeHead(status, { 'content-type': 'application/json' });
  res.end(JSON.stringify(body));
};

test('RA-BE-165: an overloaded API is asked once, not retried behind the reservation', async () => {
  for (const status of [429, 500, 529]) {
    const api = await standIn((_req, res) =>
      json(res, status, { type: 'error', error: { type: 'overloaded_error', message: 'busy' } }),
    );
    try {
      const error = await failure(new ClaudeAssistantModel('test-key', { baseURL: api.baseURL }));
      assert.equal(error.failure, 'BUSY', `status ${status}`);
      assert.equal(api.hits(), 1, `status ${status}: one attempt`);
    } finally {
      await api.close();
    }
  }
});

test('RA-BE-165: a timeout is one attempt and may have been billed', async () => {
  const api = await standIn(() => {
    // Never answers.
  });
  try {
    const error = await failure(new ClaudeAssistantModel('test-key', { baseURL: api.baseURL, timeoutMs: 300 }));
    assert.equal(error.failure, 'UNANSWERED');
    assert.equal(api.hits(), 1, 'no second attempt');
  } finally {
    await api.close();
  }
});

test('RA-BE-165: a connection dropped after the request was sent may have been billed', async () => {
  const api = await standIn((req) => req.socket.destroy());
  try {
    const error = await failure(new ClaudeAssistantModel('test-key', { baseURL: api.baseURL }));
    assert.equal(error.failure, 'UNANSWERED');
    assert.match(error.detail, /APIConnectionError/);
    assert.equal(api.hits(), 1);
  } finally {
    await api.close();
  }
});

test('RA-BE-165: a connection that never opened is busy, nothing was sent', async () => {
  // A port that was just free: the connection is refused.
  const probe = createNetServer();
  await new Promise<void>((resolve) => probe.listen(0, '127.0.0.1', resolve));
  const { port } = probe.address() as AddressInfo;
  await new Promise<void>((resolve) => probe.close(() => resolve()));
  const error = await failure(new ClaudeAssistantModel('test-key', { baseURL: `http://127.0.0.1:${port}` }));
  assert.equal(error.failure, 'BUSY');
  assert.match(error.detail, /ECONNREFUSED/);
});

test('an answer is read with its stop reason, model and usage', async () => {
  const api = await standIn((_req, res) =>
    json(res, 200, {
      id: 'msg_1',
      type: 'message',
      role: 'assistant',
      model: 'claude-opus-5-5',
      content: [{ type: 'text', text: ' خطة ' }],
      stop_reason: 'max_tokens',
      stop_sequence: null,
      usage: { input_tokens: 10, output_tokens: 8000, cache_read_input_tokens: 2, cache_creation_input_tokens: 3 },
    }),
  );
  try {
    const reply = await new ClaudeAssistantModel('test-key', { baseURL: api.baseURL }).ask(request);
    assert.deepEqual(reply, {
      text: 'خطة',
      stopReason: 'max_tokens',
      model: 'claude-opus-5-5',
      usage: { inputTokens: 10, outputTokens: 8000, cacheReadTokens: 2, cacheWriteTokens: 3 },
    });
    assert.equal(api.hits(), 1);
  } finally {
    await api.close();
  }
});
