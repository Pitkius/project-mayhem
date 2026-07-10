/**
 * web-bridge.js — tiltas tarp seno vanilla NUI sluoksnio ir naujos
 * React + PixiJS darbo stoties (web/dist/index.html), kuri gyvena <iframe>.
 *
 * Naudojama migruojant narkotikus po vieną: MIGRATED sąraše esantys narkotikai
 * paleidžia naują React stotį; visi kiti lieka senuose mg-*.js žaidimuose.
 *
 * Srautas:
 *   Lua -> nui('minigameSchedule') -> schedule.js runScheduleGame()
 *     jei drug yra MIGRATED -> MrpWebStation.run(data)
 *       -> iframe postMessage({source:'mrp_drugs', action:'startStation'})
 *       -> žaidėjas žaidžia Pixi stotį
 *       -> iframe postMessage({source:'mrp_drugs_web', action:'result'})
 *       -> fetch scheduleResult (success, score, quality, mistakes) -> Lua
 */
(() => {
  // Narkotikai, jau perkelti į naują React/Pixi variklį.
  const MIGRATED = new Set([
    'thc',
    'alcohol',
    'vape',
    'weed',
    'heroin',
    'cocaine',
    'amp',
    'meth',
    'pills',
    'mushroom',
  ]);

  // Kelias reliatyvus html/index.html dokumentui -> ../web/dist/index.html
  const WEB_SRC = '../web/dist/index.html';
  let iframe = null;
  let ready = false;
  let pending = null; // laukianti payload kol iframe užsikraus
  let active = false;

  function ensureIframe() {
    if (iframe) return iframe;
    iframe = document.createElement('iframe');
    iframe.id = 'mrpWebStation';
    iframe.src = WEB_SRC;
    iframe.setAttribute('allowtransparency', 'true');
    Object.assign(iframe.style, {
      position: 'fixed',
      inset: '0',
      width: '100%',
      height: '100%',
      border: '0',
      background: 'transparent',
      zIndex: '9998',
      display: 'none',
    });
    document.body.appendChild(iframe);
    return iframe;
  }

  function show() {
    ensureIframe();
    iframe.style.display = 'block';
    // Perduodam klaviatūros fokusą į iframe (SPACE/ESC turi pasiekti React app).
    try {
      if (iframe.contentWindow) iframe.contentWindow.focus();
    } catch (_) {
      /* ignore */
    }
  }

  function hide() {
    if (iframe) iframe.style.display = 'none';
    active = false;
  }

  function postToIframe(msg) {
    if (iframe && iframe.contentWindow) {
      iframe.contentWindow.postMessage(msg, '*');
    }
  }

  function startStation(payload) {
    postToIframe({ source: 'mrp_drugs', action: 'startStation', data: payload });
  }

  // Rezultatas iš iframe -> perduodam Lua per esamą scheduleResult callback.
  function reportResult(data) {
    if (!active) return;
    active = false;
    hide();
    try {
      fetch(`https://${GetParentResourceName()}/scheduleResult`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          success: !!(data && data.success),
          score: data && typeof data.score === 'number' ? data.score : undefined,
          quality: data && data.quality,
          mistakes: data && typeof data.mistakes === 'number' ? data.mistakes : undefined,
        }),
      });
    } catch (_) {
      /* ignore */
    }
  }

  // Klausom iframe pranešimų (rezultatas / ready).
  window.addEventListener('message', (e) => {
    const msg = e.data || {};
    if (msg.source !== 'mrp_drugs_web') return;
    if (msg.action === 'ready') {
      ready = true;
      if (pending) {
        const p = pending;
        pending = null;
        show();
        startStation(p);
      }
      return;
    }
    if (msg.action === 'result') {
      reportResult(msg.data || {});
      return;
    }
    if (msg.action === 'cancel') {
      reportResult({ success: false, score: 0, quality: 'poor', mistakes: 0 });
      return;
    }
  });

  window.MrpWebStation = {
    isMigrated(drug) {
      return MIGRATED.has(drug);
    },
    run(payload) {
      active = true;
      ensureIframe();
      // iframe užkrautas iš karto; jei dar ne "ready", pranešam kai bus.
      // Bet startStation veikia ir prieš ready (App klausosi message iškart po mount),
      // todėl siunčiam iškart ir pakartotinai per pending, jei prireiktų.
      show();
      startStation(payload);
      if (!ready) pending = payload;
    },
    close() {
      if (iframe) postToIframe({ source: 'mrp_drugs', action: 'close' });
      hide();
    },
  };
})();
