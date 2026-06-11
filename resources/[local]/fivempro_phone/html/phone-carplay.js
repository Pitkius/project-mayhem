(function () {
  const carplay = {
    inVehicle: false,
    session: null,
    audioEl: null,
    ytFrame: null,
  };

  function ensureAudioHost() {
    let host = document.getElementById("carplayAudioHost");
    if (!host) {
      host = document.createElement("div");
      host.id = "carplayAudioHost";
      document.body.appendChild(host);
    }
    return host;
  }

  function stopAudio() {
    if (carplay.audioEl) {
      carplay.audioEl.pause();
      carplay.audioEl.removeAttribute("src");
      carplay.audioEl = null;
    }
    if (carplay.ytFrame) {
      carplay.ytFrame.remove();
      carplay.ytFrame = null;
    }
    ensureAudioHost().innerHTML = "";
  }

  function playAudio(cmd) {
    if (!cmd) return;
    const host = ensureAudioHost();
    if (cmd.command === "stop") {
      stopAudio();
      return;
    }
    if (cmd.command === "pause") {
      if (carplay.audioEl) carplay.audioEl.pause();
      return;
    }
    if (cmd.command === "volume") {
      const v = Math.max(0, Math.min(1, Number(cmd.volume) || 0.65));
      if (carplay.audioEl) carplay.audioEl.volume = v;
      return;
    }
    if (cmd.command === "play" && cmd.stream) {
      stopAudio();
      if (cmd.mediaType === "youtube" || String(cmd.stream).includes("youtube.com/embed")) {
        carplay.ytFrame = document.createElement("iframe");
        carplay.ytFrame.src = cmd.stream;
        carplay.ytFrame.allow = "autoplay; encrypted-media";
        host.appendChild(carplay.ytFrame);
      } else {
        carplay.audioEl = document.createElement("audio");
        carplay.audioEl.autoplay = true;
        carplay.audioEl.volume = Number(cmd.volume) || 0.65;
        carplay.audioEl.src = cmd.stream;
        host.appendChild(carplay.audioEl);
        carplay.audioEl.play().catch(() => {});
      }
    }
  }

  function renderCarPlayUi(content, state) {
    const s = state?.session || {};
    const playing = !!s.playing;
    const title = s.title || "Niekas negroja";
    const vol = Math.round((Number(s.volume) || 0.65) * 100);

    content.className = "scroll-body carplay-body";
    content.innerHTML = `
      <div class="carplay-app">
        <div class="neon-card carplay-now">
          <div class="carplay-cover">♪</div>
          <div class="carplay-sub">Dabar groja</div>
          <div class="carplay-title" id="cpTitle">${window.PhoneEsc(title)}</div>
          <div class="carplay-progress"><span></span></div>
        </div>
        <div class="carplay-transport">
          <button type="button" id="cpSkip" title="Skip">►►</button>
          <button type="button" class="play-main" id="cpPlay">${playing ? "❚❚" : "▶"}</button>
          <button type="button" id="cpStop" title="Stop">■</button>
        </div>
        <div class="neon-card carplay-volume">
          <span>🔊</span>
          <input type="range" id="cpVolume" min="0" max="100" value="${vol}" />
          <span id="cpVolLbl">${vol}%</span>
        </div>
        <div class="neon-card carplay-url-box">
          <label class="small muted">Pridėti nuorodą</label>
          <input type="text" id="cpUrl" placeholder="Spotify arba YouTube nuoroda" />
          <div class="carplay-chip-row">
            <button type="button" class="carplay-chip" data-paste="spotify">Spotify</button>
            <button type="button" class="carplay-chip" data-paste="youtube">YouTube</button>
          </div>
          <button type="button" class="neon-btn primary" style="width:100%;margin-top:10px" id="cpAddPlay">Leisti automobilyje</button>
        </div>
      </div>`;

    if (!state?.inVehicle) {
      content.innerHTML = `<div class="empty-state" style="padding:24px">CarPlay veikia tik sėdint transporto priemonėje.</div>`;
      return;
    }

    const urlInput = content.querySelector("#cpUrl");
    content.querySelector("[data-paste=youtube]")?.addEventListener("click", () => {
      urlInput.placeholder = "https://www.youtube.com/watch?v=...";
      urlInput.focus();
    });
    content.querySelector("[data-paste=spotify]")?.addEventListener("click", () => {
      urlInput.placeholder = "https://open.spotify.com/track/...";
      urlInput.focus();
    });

    content.querySelector("#cpAddPlay").addEventListener("click", async () => {
      const url = urlInput.value.trim();
      if (!url) return;
      const res = await window.PhoneNui("carplayControl", { action: "play", url });
      if (!res?.ok) alert(res?.message || "Klaida");
      else renderCarPlayUi(content, { inVehicle: true, session: res.session });
    });

    content.querySelector("#cpPlay").addEventListener("click", async () => {
      const act = playing ? "pause" : s.stream ? "resume" : "play";
      const res = await window.PhoneNui("carplayControl", {
        action: act,
        url: urlInput?.value || s.url,
      });
      if (res?.ok) renderCarPlayUi(content, { inVehicle: true, session: res.session });
    });

    content.querySelector("#cpSkip").addEventListener("click", async () => {
      const res = await window.PhoneNui("carplayControl", { action: "skip" });
      if (res?.ok) renderCarPlayUi(content, { inVehicle: true, session: res.session });
    });

    content.querySelector("#cpStop").addEventListener("click", async () => {
      const res = await window.PhoneNui("carplayControl", { action: "stop" });
      if (res?.ok) renderCarPlayUi(content, { inVehicle: true, session: res.session });
    });

    content.querySelector("#cpVolume").addEventListener("input", async (e) => {
      const v = Number(e.target.value) / 100;
      content.querySelector("#cpVolLbl").textContent = `${e.target.value}%`;
      await window.PhoneNui("carplayControl", { action: "volume", volume: v });
    });
  }

  window.renderCarplayApp = async function renderCarplayApp(content) {
    const res = await window.PhoneNui("carplayGetState", {});
    if (!res?.ok && !res?.session) {
      content.innerHTML = `<div class="empty-state" style="padding:24px">${window.PhoneEsc(res?.message || "CarPlay nepasiekiamas.")}</div>`;
      return;
    }
    renderCarPlayUi(content, { inVehicle: res.ok !== false, session: res.session });
  };

  window.addEventListener("message", (e) => {
    const { action, payload } = e.data || {};
    if (action === "carplayAudio") playAudio(payload);
    if (action === "carplayState" && payload?.session) {
      carplay.session = payload.session;
      const content = document.getElementById("appContent");
      const title = document.getElementById("appTitle");
      if (content && title?.textContent === "CarPlay") {
        renderCarPlayUi(content, payload);
      }
    }
  });
})();
