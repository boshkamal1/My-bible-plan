const {onSchedule} = require('firebase-functions/v2/scheduler');
const {defineSecret} = require('firebase-functions/params');
const admin = require('firebase-admin');
const webpush = require('web-push');
const {createReminderHandler} = require('./reminders');

admin.initializeApp();
const privateKey = defineSecret('WEB_PUSH_VAPID_PRIVATE');
const publicKey = process.env.WEB_PUSH_VAPID_PUBLIC;

// Invocation authorization belongs to Cloud Scheduler/Cloud Run IAM, not headers.
exports.sendReadingReminders = onSchedule({
  schedule: 'every 1 minutes',
  timeZone: 'Etc/UTC',
  region: 'europe-west1',
  secrets: [privateKey],
  maxInstances: 1,
}, async () => {
  if (!publicKey) throw new Error('WEB_PUSH_VAPID_PUBLIC is missing');
  webpush.setVapidDetails('mailto:boshkamal1@gmail.com', publicKey, privateKey.value());
  await createReminderHandler({
    db: admin.firestore(),
    Timestamp: admin.firestore.Timestamp,
    FieldValue: admin.firestore.FieldValue,
    sendNotification: webpush.sendNotification.bind(webpush),
  })();
});
