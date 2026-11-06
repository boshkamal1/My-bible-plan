'use strict';
let firebaseModules;
// External dynamic imports avoid FlutterFire's inline script injection under CSP.
// Keep this SDK version aligned with firebase_core_web's supported version.
window.biblePrepareFirebase = function () {
  return firebaseModules ??= Promise.all([
    import('https://www.gstatic.com/firebasejs/11.9.1/firebase-app.js'),
    import('https://www.gstatic.com/firebasejs/11.9.1/firebase-auth.js'),
    import('https://www.gstatic.com/firebasejs/11.9.1/firebase-firestore.js'),
    import('https://www.gstatic.com/firebasejs/11.9.1/firebase-app-check.js'),
  ]).then(([core, auth, firestore, appCheck]) => {
    window.firebase_auth = auth;
    window.firebase_firestore = firestore;
    window.firebase_app_check = appCheck;
    // Publish core last: FlutterFire treats this as the readiness signal.
    window.firebase_core = core;
    return true;
  }).catch(error => { firebaseModules = undefined; throw error; });
};
