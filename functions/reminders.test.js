const test = require('node:test');
const assert = require('node:assert/strict');
const {createECDH} = require('node:crypto');
const {Timestamp, FieldValue} = require('firebase-admin/firestore');
const {validateSubscription, createReminderHandler} = require('./reminders');
const key = createECDH('prime256v1');
key.generateKeys();
const subscription = (endpoint = 'https://fcm.googleapis.com/fcm/send/token') => ({
  endpoint, keys: {auth: Buffer.alloc(16, 1).toString('base64url'),
    p256dh: key.getPublicKey().toString('base64url')},
});
const data = () => ({enabled: true, zone: 'Africa/Cairo', hour: 9, minute: 30,
  nextAt: Timestamp.fromMillis(1), subscription: subscription()});

for (const endpoint of [
  'http://fcm.googleapis.com/x', 'https://127.0.0.1/x', 'https://[::1]/x',
  'https://169.254.169.254/computeMetadata/v1/', 'https://2130706433/x',
  'https://fcm.googleapis.com.evil.test/x', 'https://evilpush.apple.com/x',
  'https://push.apple.com.evil.test/x', 'https://fcm.googleapis.com:8443/x',
  'https://user:password@fcm.googleapis.com/x', 'https://fcm.googleapis.com/x#fragment',
  'https://fcm.googleapis.com\\@evil.test/x', ' https://fcm.googleapis.com/x',
  'https://localhost/x', 'https://fcm.googleapis.com./x',
  'https://evilnotify.windows.com/x', 'https://wns.notify.windows.com.evil.test/x',
  'https://regional.push.services.mozilla.com/x',
]) test(`rejects unsafe endpoint ${endpoint}`, () => {
  assert.throws(() => validateSubscription(subscription(endpoint)));
});
for (const host of ['fcm.googleapis.com', 'updates.push.services.mozilla.com', 'web.push.apple.com',
  'wns2-db5p.notify.windows.com']) {
  test(`accepts provider ${host}`, () => {
    const result = validateSubscription({...subscription(`https://${host}/token`), arbitrary: 'ignored'});
    assert.deepEqual(Object.keys(result), ['endpoint', 'keys']);
  });
}
test('rejects malformed, oversized, wrong-length and off-curve keys', () => {
  for (const change of [{auth: 'x'}, {auth: '!'.repeat(22)}, {auth: 'x'.repeat(10000)},
    {p256dh: Buffer.alloc(65, 4).toString('base64url')}, {p256dh: 'AAAA'}]) {
    const value = subscription();
    Object.assign(value.keys, change);
    assert.throws(() => validateSubscription(value));
  }
  for (const value of [null, {}, {endpoint: 42}, {endpoint: 'https://fcm.googleapis.com/x'}]) {
    assert.throws(() => validateSubscription(value));
  }
});

function harness(values, onSend = async () => {}) {
  const rows = values.map((value, i) => ({ref: {path: `pushSubscriptions/user/devices/${i}`}, value}));
  const sent = [], logs = [];
  const db = {
    collectionGroup: () => ({where: () => ({limit: () => ({get: async () => ({docs: rows})})})}),
    runTransaction: async (callback) => callback({
      get: async (ref) => {
        const row = rows.find((item) => item.ref === ref);
        return {exists: !!row.value, data: () => row.value};
      },
      update: (ref, update) => Object.assign(rows.find((item) => item.ref === ref).value, update),
      delete: (ref) => { rows.find((item) => item.ref === ref).value = null; },
    }),
  };
  const run = createReminderHandler({db, Timestamp, FieldValue,
    logger: {error: (...args) => logs.push(args)},
    sendNotification: async (...args) => { sent.push(args); await onSend(rows, ...args); },
  });
  return {rows, sent, logs, run};
}
test('valid reminders send once and use a bounded request timeout', async () => {
  const h = harness([data()]);
  await h.run();
  await h.run();
  assert.equal(h.sent.length, 1);
  assert.equal(h.sent[0][2].timeout, 5000);
  assert.ok(h.rows[0].value.nextAt.toMillis() > Date.now());
});
test('invalid reminders are removed from the due queue without blocking valid ones', async () => {
  const invalid = [ {enabled: 'true'}, {zone: {}}, {zone: 'invalid-zone'}, {hour: 24},
    {minute: -1}, {nextAt: 'bad'}, {subscription: subscription('https://localhost/x')} ];
  const h = harness([...invalid.map((change) => ({...data(), ...change})), data()]);
  await h.run();
  assert.equal(h.sent.length, 1);
  for (const row of h.rows.slice(0, -1)) assert.ok(!(row.value.nextAt instanceof Timestamp));
});
test('does not process unrelated devices collections', async () => {
  const h = harness([data()]);
  h.rows[0].ref.path = 'other/user/devices/1';
  await h.run();
  assert.equal(h.sent.length, 0);
  assert.equal(h.rows[0].value.nextAt.toMillis(), 1);
});
test('uses fresh transaction state rather than the query snapshot', async () => {
  const h = harness([data()]);
  h.rows[0].data = () => data(); // Stale query snapshot must never be used.
  h.rows[0].value.enabled = false;
  await h.run();
  assert.equal(h.sent.length, 0);
});
test('fresh transaction subscription is validated and sent', async () => {
  const h = harness([data()]);
  h.rows[0].data = () => ({...data(), subscription: subscription('https://localhost/x')});
  await h.run();
  assert.equal(h.sent.length, 1);
  assert.equal(h.sent[0][0].endpoint, subscription().endpoint);
});
for (const statusCode of [404, 410]) {
  test(`deletes unchanged expired subscription on ${statusCode}`, async () => {
    const h = harness([data()], async () => { throw {statusCode}; });
    await h.run();
    assert.equal(h.rows[0].value, null);
  });
  test(`preserves replaced subscription on ${statusCode}`, async () => {
    const h = harness([data()], async (rows) => {
      rows[0].value.subscription = subscription('https://fcm.googleapis.com/new');
      throw {statusCode};
    });
    await h.run();
    assert.ok(h.rows[0].value);
  });
}
test('transport errors do not leak endpoints or block later devices', async () => {
  const h = harness([data(), data()], async () => { throw new Error('secret endpoint token'); });
  await h.run();
  assert.equal(h.sent.length, 2);
  assert.doesNotMatch(JSON.stringify(h.logs), /secret endpoint token/);
});
test('scheduled export loads with expected trigger and secret binding', () => {
  const fn = require('./index').sendReadingReminders;
  assert.equal(typeof fn.run, 'function');
  assert.equal(fn.__endpoint.scheduleTrigger.schedule, 'every 1 minutes');
  assert.ok(fn.__endpoint.secretEnvironmentVariables.some((item) => item.key === 'WEB_PUSH_VAPID_PRIVATE'));
});
