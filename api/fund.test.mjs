// Node.js native test runner - 无额外依赖
// Usage: node --test api/fund.test.js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const handler = require('./fund.js');

/**
 * 构造伪造的 req/res 对象，返回一个包含 state 的 context
 */
function createMockReqRes(query = {}) {
  const state = { statusCode: 200, body: null, headers: {} };
  const req = { query };
  const res = {
    setHeader: (k, v) => { state.headers[k] = v; },
    status: (code) => { state.statusCode = code; return res; },
    send: (data) => { state.body = data; return res; },
    json: (obj) => { state.body = JSON.stringify(obj); return res; },
  };
  return { req, res, state };
}

/**
 * 保存全局 fetch 以便 mock 后恢复
 */
function mockFetch(impl) {
  const original = globalThis.fetch;
  globalThis.fetch = impl;
  return () => { globalThis.fetch = original; };
}

test('拒绝无 code 参数', async () => {
  const { req, res, state } = createMockReqRes();
  await handler(req, res);
  assert.equal(state.statusCode, 400);
});

test('拒绝非 6 位数字 code', async () => {
  const c1 = createMockReqRes({ code: 'abc' });
  await handler(c1.req, c1.res);
  assert.equal(c1.state.statusCode, 400);

  const c2 = createMockReqRes({ code: '12345' });
  await handler(c2.req, c2.res);
  assert.equal(c2.state.statusCode, 400);
});

test('合法 code 转发到天天基金', async () => {
  let fetchedUrl = null;
  const restore = mockFetch(async (url) => {
    fetchedUrl = url;
    return new Response(
      'jsonpgz({"fundcode":"000071","name":"测试"});',
      { status: 200 },
    );
  });

  try {
    const { req, res, state } = createMockReqRes({ code: '000071' });
    await handler(req, res);

    assert.equal(state.statusCode, 200);
    assert.ok(
      fetchedUrl.includes('fundgz.1234567.com.cn/js/000071.js'),
      `fetched URL ${fetchedUrl}`,
    );
    assert.ok(state.body.includes('jsonpgz'));
    // 必须设置 CORS
    assert.equal(state.headers['Access-Control-Allow-Origin'], '*');
  } finally {
    restore();
  }
});

test('携带 rt 参数时透传到下游', async () => {
  let fetchedUrl = null;
  const restore = mockFetch(async (url) => {
    fetchedUrl = url;
    return new Response('jsonpgz({});', { status: 200 });
  });

  try {
    const { req, res } = createMockReqRes({ code: '000071', rt: '1234567890' });
    await handler(req, res);
    assert.ok(fetchedUrl.includes('rt=1234567890'));
  } finally {
    restore();
  }
});

test('下游失败返回 500', async () => {
  const restore = mockFetch(async () => {
    throw new Error('Network down');
  });

  try {
    const { req, res, state } = createMockReqRes({ code: '000071' });
    await handler(req, res);
    assert.equal(state.statusCode, 500);
    assert.ok(state.body.includes('Network down'));
  } finally {
    restore();
  }
});

test('响应 Content-Type 为 javascript', async () => {
  const restore = mockFetch(async () =>
    new Response('jsonpgz({});', { status: 200 }),
  );

  try {
    const { req, res, state } = createMockReqRes({ code: '000071' });
    await handler(req, res);
    assert.ok(
      state.headers['Content-Type'].includes('application/javascript'),
      `got ${state.headers['Content-Type']}`,
    );
  } finally {
    restore();
  }
});
