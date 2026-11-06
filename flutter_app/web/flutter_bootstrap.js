{{flutter_js}}
{{flutter_build_config}}

for (const build of _flutter.buildConfig.builds) {
  for (const field of ['mainJsPath', 'mainWasmPath', 'jsSupportRuntimePath']) {
    if (build[field]) build[field] += '?v=20261106-34';
  }
}

const loadingScreen = document.getElementById('app-loading');
let loadingFinished = false;
function finishLoading() {
  if (loadingFinished) return;
  loadingFinished = true;
  clearTimeout(slowLoadingTimer);
  loadingScreen?.classList.add('done');
  setTimeout(() => loadingScreen?.remove(), 350);
}
const slowLoadingTimer = setTimeout(() => loadingScreen?.classList.add('slow'), 15000);
window.addEventListener('flutter-first-frame', finishLoading, {once: true});

_flutter.loader.load({
  config: {forceSingleThreadedSkwasm: true},
  onEntrypointLoaded: async function (engineInitializer) {
    try {
      const appRunner = await engineInitializer.initializeEngine();
      await appRunner.runApp();
      // The first-frame event normally fires here; this also covers engines that omit it.
      setTimeout(finishLoading, 800);
    } catch (error) {
      loadingScreen?.classList.add('slow');
      console.error('App could not start:', error);
    }
  },
});

if ('serviceWorker' in navigator) {
  const wasControlledAtLoad = Boolean(navigator.serviceWorker.controller);
  navigator.serviceWorker.addEventListener('controllerchange', function () {
    // The first worker already serves this release. Avoid reloading the app
    // a second time on a first visit; reload only when upgrading an old worker.
    if (!wasControlledAtLoad) return;
    if (sessionStorage.getItem('bible-pwa-refreshed-v34') !== 'yes') {
      sessionStorage.setItem('bible-pwa-refreshed-v34', 'yes');
      location.reload();
    }
  });
  window.addEventListener('load', function () {
    navigator.serviceWorker.register('sw.js').then(function (registration) {
      registration.update();
    }).catch(function (error) {
      console.warn('PWA offline cache could not start:', error);
    });
  });
}
