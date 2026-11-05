const bibleVapidPublic = 'BEKq2bt7Hg59i4daMdvCBCbzPoliq7qCUwaT7aeP5yO5CIJwf23l_lbJvIyUTbnBA96RzuadI5INFHmowt3rxfk';

function bibleVapidBytes(key) {
  const padding = '='.repeat((4 - key.length % 4) % 4);
  const raw = atob((key + padding).replace(/-/g, '+').replace(/_/g, '/'));
  return Uint8Array.from(raw, c => c.charCodeAt(0));
}

window.biblePushPermission = () =>
  'Notification' in window ? Notification.permission : 'unsupported';

window.biblePushSubscribe = async () => {
  if (!('serviceWorker' in navigator) || !('PushManager' in window) ||
      !('Notification' in window)) throw new Error('unsupported');
  const permission = await Notification.requestPermission();
  if (permission !== 'granted') throw new Error('permission-denied');
  const registration = await navigator.serviceWorker.register('sw.js');
  const ready = await navigator.serviceWorker.ready;
  let subscription = await ready.pushManager.getSubscription();
  if (!subscription) {
    subscription = await ready.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: bibleVapidBytes(bibleVapidPublic),
    });
  }
  let id = localStorage.getItem('bible-push-device');
  if (!id) {
    id = crypto.randomUUID();
    localStorage.setItem('bible-push-device', id);
  }
  return JSON.stringify({
    id,
    subscription: subscription.toJSON(),
    zone: Intl.DateTimeFormat().resolvedOptions().timeZone,
  });
};

window.biblePushDeviceId = () => localStorage.getItem('bible-push-device');
window.biblePushUnsubscribe = async () => {
  const registration = await navigator.serviceWorker.ready;
  const subscription = await registration.pushManager.getSubscription();
  if (subscription) await subscription.unsubscribe();
};
