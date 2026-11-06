'use strict';
document.getElementById('loading-retry')?.addEventListener('click', () => location.reload());
// Enumerate names only. Never open or read authentication token records here.
window.bibleHasSavedSignIn = async function () {
  if (!indexedDB.databases) return true;
  try {
    const databases = await indexedDB.databases();
    return databases.some(db => db.name === 'firebaseLocalStorageDb');
  } catch (_) { return true; }
};
