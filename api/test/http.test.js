import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { createApp } from '../src/app.js';

test('errores HTTP consistentes incluso si Redis falla', async (t) => {
  // Sólo simula una caída para verificar el middleware; CRUD se prueba con Redis real.
  const server = createApp({ hGetAll: async () => { throw new Error('Detalle privado'); } }).listen(0, '127.0.0.1');
  await once(server, 'listening');
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const base = `http://127.0.0.1:${server.address().port}`;
  const cases = [
    ['/api/orders/1', {}, 500, 'Error interno del servidor.'],
    ['/api/orders/abc', {}, 400, 'El ID debe ser un entero positivo.'],
    ['/no-existe', {}, 404, 'Ruta inexistente.'],
    ['/api/orders', { method: 'POST', body: '{bad' }, 400, 'JSON inválido.'],
    ['/api/orders', { method: 'POST', body: JSON.stringify({ customer: 'a'.repeat(110000) }) }, 400, 'El cuerpo excede 100 KB.'],
    ['/api/orders', { method: 'POST', body: '{}' }, 400, 'customer debe ser un texto no vacío.'],
  ];
  for (const [path, options, status, message] of cases) {
    const response = await fetch(base + path, { ...options, headers: { 'Content-Type': 'application/json' } });
    assert.equal(response.status, status);
    assert.deepEqual(await response.json(), { error: { message } });
  }
});

test('endpoint /api/replica devuelve numero y hostname de la replica', async (t) => {
  const server = createApp({}).listen(0, '127.0.0.1');
  await once(server, 'listening');
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const base = `http://127.0.0.1:${server.address().port}`;

  const response = await fetch(`${base}/api/replica`);
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.ok(typeof body.data.numero === 'number');
  assert.ok(body.data.numero >= 100 && body.data.numero <= 999);
  assert.ok(typeof body.data.hostname === 'string' && body.data.hostname.length > 0);
});

test('Feature Flag consulta beta y control, y la administración exige token', async (t) => {
  const originalToken = process.env.FEATURE_FLAGS_ADMIN_TOKEN;
  process.env.FEATURE_FLAGS_ADMIN_TOKEN = 'token-local-de-prueba';
  const flags = new Map();
  const redis = {
    get: async (key) => flags.get(key) ?? null,
    set: async (key, value) => { flags.set(key, value); },
  };
  const server = createApp(redis).listen(0, '127.0.0.1');
  await once(server, 'listening');
  t.after(() => {
    if (originalToken === undefined) delete process.env.FEATURE_FLAGS_ADMIN_TOKEN;
    else process.env.FEATURE_FLAGS_ADMIN_TOKEN = originalToken;
    return new Promise((resolve) => server.close(resolve));
  });
  const base = `http://127.0.0.1:${server.address().port}`;

  const control = await fetch(`${base}/api/feature-flags?group=control`);
  assert.deepEqual(await control.json(), { group: 'control', flags: { show_order_wait_time: false } });
  const betaDefault = await fetch(`${base}/api/feature-flags?group=beta`);
  assert.deepEqual(await betaDefault.json(), { group: 'beta', flags: { show_order_wait_time: false } });

  const denied = await fetch(`${base}/api/admin/feature-flags/show_order_wait_time`, {
    method: 'PATCH', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ group: 'beta', enabled: true }),
  });
  assert.equal(denied.status, 403);

  const enabled = await fetch(`${base}/api/admin/feature-flags/show_order_wait_time`, {
    method: 'PATCH', headers: {
      'Content-Type': 'application/json', Authorization: 'Bearer token-local-de-prueba',
    }, body: JSON.stringify({ group: 'beta', enabled: true }),
  });
  assert.equal(enabled.status, 200);
  assert.equal(flags.get('feature-flags:show_order_wait_time:beta'), 'true');
  assert.deepEqual(await (await fetch(`${base}/api/feature-flags?group=beta`)).json(), {
    group: 'beta', flags: { show_order_wait_time: true },
  });
  assert.deepEqual(await (await fetch(`${base}/api/feature-flags?group=control`)).json(), {
    group: 'control', flags: { show_order_wait_time: false },
  });

  const disabled = await fetch(`${base}/api/admin/feature-flags/show_order_wait_time`, {
    method: 'PATCH', headers: {
      'Content-Type': 'application/json', Authorization: 'Bearer token-local-de-prueba',
    }, body: JSON.stringify({ group: 'beta', enabled: false }),
  });
  assert.equal(disabled.status, 200);
  assert.equal(flags.get('feature-flags:show_order_wait_time:beta'), 'false');
  assert.deepEqual(await (await fetch(`${base}/api/feature-flags?group=beta`)).json(), {
    group: 'beta', flags: { show_order_wait_time: false },
  });
});
