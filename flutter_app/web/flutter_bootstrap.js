{{flutter_js}}
{{flutter_build_config}}

for (const build of _flutter.buildConfig.builds) {
  if (build.mainJsPath === 'main.dart.js') {
    build.mainJsPath = 'main.dart.js?v=20261105-25';
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
  navigator.serviceWorker.addEventListener('controllerchange', function () {
    if (sessionStorage.getItem('bible-pwa-refreshed-v25') !== 'yes') {
      sessionStorage.setItem('bible-pwa-refreshed-v25', 'yes');
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
