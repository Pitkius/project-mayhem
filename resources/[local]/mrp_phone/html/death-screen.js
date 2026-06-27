(function () {
  const DROP_SVG =
    '<svg viewBox="0 0 24 56" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">' +
    '<path d="M12 2C8 14 3 22 3 32a9 9 0 0 0 18 0c0-10-5-18-9-30z" fill="#c81028"/>' +
    '<path d="M12 2C8 14 3 22 3 32a9 9 0 0 0 18 0c0-10-5-18-9-30z" fill="#ff3d58" opacity="0.35"/>' +
    '<ellipse cx="12" cy="40" rx="7.5" ry="5.5" fill="#6a0818" opacity="0.5"/></svg>';

  const SPLATTER_SVG =
    '<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">' +
    '<circle cx="50" cy="50" r="22" fill="#a01024" opacity="0.9"/>' +
    '<circle cx="28" cy="38" r="9" fill="#c0142c"/><circle cx="72" cy="42" r="11" fill="#b01228"/>' +
    '<circle cx="62" cy="68" r="8" fill="#901020"/><circle cx="34" cy="66" r="7" fill="#8a0e1e"/>' +
    '<circle cx="50" cy="22" r="6" fill="#d01834"/><circle cx="18" cy="58" r="5" fill="#7a0c18"/>' +
    '<circle cx="82" cy="55" r="6" fill="#7a0c18"/></svg>';

  const screen = document.getElementById("deathScreen");
  if (!screen) return;

  const titleEl = document.getElementById("deathTitle");
  const line1El = document.getElementById("deathLine1");
  const line2El = document.getElementById("deathLine2");
  const line3El = document.getElementById("deathLine3");
  const dropsEl = document.getElementById("deathDrops");

  let dropsBuilt = false;

  function buildDrops() {
    if (dropsBuilt || !dropsEl) return;
    dropsBuilt = true;
    const splatters = [
      ["death-splatter death-splatter--tl", "110px"],
      ["death-splatter death-splatter--tr", "95px"],
      ["death-splatter death-splatter--bl", "88px"],
      ["death-splatter death-splatter--br", "100px"],
    ];
    splatters.forEach(([cls, size]) => {
      const s = document.createElement("div");
      s.className = cls;
      s.style.setProperty("--splatter-size", size);
      s.innerHTML = SPLATTER_SVG;
      dropsEl.appendChild(s);
    });

    const count = 14;
    for (let i = 0; i < count; i++) {
      const el = document.createElement("div");
      el.className = "death-drop";
      const left = 4 + Math.random() * 92;
      const w = 10 + Math.random() * 12;
      const h = w * (2.1 + Math.random() * 0.8);
      const dur = 2.8 + Math.random() * 2.4;
      const delay = Math.random() * dur;
      el.style.left = left + "%";
      el.style.setProperty("--drop-w", w + "px");
      el.style.setProperty("--drop-h", h + "px");
      el.style.setProperty("--drop-dur", dur + "s");
      el.style.setProperty("--drop-delay", delay + "s");
      el.style.setProperty("--drop-opacity", (0.55 + Math.random() * 0.4).toFixed(2));
      el.innerHTML = DROP_SVG;
      dropsEl.appendChild(el);
    }
  }

  function pad2(n) {
    return n < 10 ? "0" + n : String(n);
  }

  function formatTimer(sec) {
    const s = Math.max(0, Math.ceil(sec));
    const mm = Math.floor(s / 60);
    const ss = s % 60;
    return mm + ":" + pad2(ss);
  }

  function setVisible(show) {
    screen.classList.toggle("death-screen--visible", !!show);
    screen.setAttribute("aria-hidden", show ? "false" : "true");
    if (show) buildDrops();
  }

  function render(data) {
    if (!data) return;
    if (titleEl) titleEl.textContent = data.title || "MIRĘS";
    if (line1El) {
      line1El.innerHTML =
        'Spausk <span class="death-key">G</span> — iškviesti medikus';
    }
    if (line2El) {
      line2El.textContent = "EMS pamatys tavo vietą žemėlapyje";
    }
    if (line3El) {
      if (data.canWake) {
        const hold = data.holdSec || 3;
        line3El.innerHTML =
          'Laikyk <span class="death-key">G</span> ~' + hold + ' s — prisikelti artimiausioje ligoninėje';
        line3El.className = 'death-line death-line--timer';
      } else {
        line3El.textContent =
          'Liko ' + formatTimer(data.timerSec || 0) + ' — tada laikyk G ligoninėje';
        line3El.className = "death-line death-line--timer";
      }
    }
  }

  window.addEventListener("message", function (e) {
    const d = e.data;
    if (!d || d.action !== "deathScreen") return;
    if (d.show === false) {
      setVisible(false);
      return;
    }
    setVisible(true);
    render(d);
  });
})();
