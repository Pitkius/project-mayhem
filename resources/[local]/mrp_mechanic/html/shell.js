(function () {
  const perfFrame = document.getElementById('perf-frame');
  const cosmeticRoot = document.getElementById('cosmetic-root');

  function showPerf(show) {
    if (perfFrame) perfFrame.classList.toggle('hidden', !show);
    if (cosmeticRoot) cosmeticRoot.classList.toggle('hidden', show);
  }

  window.addEventListener('message', function (e) {
    const msg = e.data || {};
    if (msg.action === 'openPerformanceUI') {
      showPerf(true);
      if (perfFrame && perfFrame.contentWindow) {
        perfFrame.contentWindow.postMessage(msg, '*');
      }
      return;
    }
    if (msg.action === 'closePerformanceUI') {
      showPerf(false);
      if (perfFrame && perfFrame.contentWindow) {
        perfFrame.contentWindow.postMessage(msg, '*');
      }
      return;
    }
    if (msg.action === 'open' || msg.action === 'close') {
      showPerf(false);
    }
  });
})();
