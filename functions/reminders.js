'use strict';
const {ECDH} = require('node:crypto');
const {DateTime} = require('luxon');

function decodeKey(value, length) {
  if (typeof value !== 'string' || value.length > 100 ||
      !/^[A-Za-z0-9_-]+={0,2}$/.test(value)) throw new Error('Invalid push key');
  const bytes = Buffer.from(value, 'base64url');
  if (bytes.length !== length || bytes.toString('base64url') !== value.replace(/=+$/, '')) {
    throw new Error('Invalid push key');
  }
  return bytes;
}
function validateSubscription(subscription) {
  if (!subscription || typeof subscription.endpoint !== 'string' ||
      subscription.endpoint.length > 2048 || /[\s\\]/.test(subscription.endpoint)) {
    throw new Error('Invalid push endpoint');
  }
  const endpoint = new URL(subscription.endpoint);
  const host = endpoint.hostname;
  const allowed = host === 'fcm.googleapis.com' || host === 'updates.push.services.mozilla.com' ||
    /^(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+(?:push\.apple\.com|notify\.windows\.com)$/.test(host);
  if (endpoint.protocol !== 'https:' || endpoint.port || endpoint.username ||
      endpoint.password || endpoint.hash || !allowed) throw new Error('Invalid push endpoint');
  const auth = decodeKey(subscription.keys?.auth, 16);
  const p256dh = decodeKey(subscription.keys?.p256dh, 65);
  if (p256dh[0] !== 4) throw new Error('Invalid push key');
  ECDH.convertKey(p256dh, 'prime256v1');
  return {endpoint: endpoint.href, keys: {
    auth: auth.toString('base64url'), p256dh: p256dh.toString('base64url'),
  }};
}
function createReminderHandler({db, Timestamp, FieldValue, sendNotification, logger = console}) {
  return async () => {
    const now = Timestamp.now();
    const due = await db.collectionGroup('devices').where('nextAt', '<=', now).limit(100).get();
    for (const doc of due.docs) {
      // Admin bypasses rules; collection-group results may include unrelated devices.
      if (!/^pushSubscriptions\/[^/]+\/devices\/[^/]+$/.test(doc.ref.path)) continue;
      try {
        const claim = await db.runTransaction(async (tx) => {
          const current = await tx.get(doc.ref);
          if (!current.exists) return null;
          const data = current.data();
          if (!(data.nextAt instanceof Timestamp)) {
            tx.update(doc.ref, {nextAt: FieldValue.delete()});
            return null;
          }
          if (data.nextAt.toMillis() > now.toMillis()) return null;
          let subscription;
          let local;
          try {
            if (data.enabled !== true || typeof data.zone !== 'string' || data.zone.length > 100 ||
                !Number.isInteger(data.hour) || data.hour < 0 || data.hour > 23 ||
                !Number.isInteger(data.minute) || data.minute < 0 || data.minute > 59) {
              throw new Error('Invalid reminder');
            }
            local = DateTime.fromMillis(now.toMillis(), {zone: data.zone});
            if (!local.isValid) throw new Error('Invalid zone');
            subscription = validateSubscription(data.subscription);
          } catch {
            tx.update(doc.ref, {nextAt: FieldValue.delete()});
            return null;
          }
          const next = local.plus({days: 1}).set({hour: data.hour, minute: data.minute,
            second: 0, millisecond: 0});
          const nextAt = Timestamp.fromDate(next.toJSDate());
          tx.update(doc.ref, {nextAt});
          return {subscription, nextAt};
        });
        if (!claim) continue;
        try {
          await sendNotification(claim.subscription, JSON.stringify({
            title: 'وقت قراءة الكتاب المقدس',
            body: 'قراءة اليوم مستنياك في My Bible Plan',
            url: 'https://mybibleplan.web.app/',
          }), {TTL: 3600, timeout: 5000});
        } catch (error) {
          if (error.statusCode === 404 || error.statusCode === 410) {
            // Preserve subscriptions replaced while delivery was in flight.
            await db.runTransaction(async (tx) => {
              const current = await tx.get(doc.ref);
              if (!current.exists) return;
              const data = current.data();
              let subscription;
              try { subscription = validateSubscription(data.subscription); } catch { return; }
              if (data.nextAt instanceof Timestamp && data.nextAt.isEqual(claim.nextAt) &&
                  JSON.stringify(subscription) === JSON.stringify(claim.subscription)) tx.delete(doc.ref);
            });
          } else {
            logger.error('Push delivery failed', Number.isInteger(error.statusCode) ? error.statusCode : 'transport');
          }
        }
      } catch {
        // Raw errors may contain secret-bearing endpoints.
        logger.error('Reminder processing failed');
      }
    }
  };
}
module.exports = {validateSubscription, createReminderHandler};
