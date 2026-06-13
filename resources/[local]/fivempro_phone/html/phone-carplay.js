(function () {
  const carplay = {
    inVehicle: false,
    session: null,
    audioEl: null,
    ytFrame: null,
  };

  const ICONS = {
    play: `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M8 5.5v13l11-6.5-11-6.5z" fill="currentColor"/></svg>`,
    pause: `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M7 5h3v14H7V5zm7 0h3v14h-3V5z" fill="currentColor"/></svg>`,
    skip: `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 5.5v13l9-6.5-9-6.5zm11 0v13h2.5v-13H16z" fill="currentColor"/></svg>`,
    stop: `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M7 7h10v10H7V7z" fill="currentColor"/></svg>`,
    volume: `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 10v4h3l4 3.5V6.5L7 10H4zm10.5-1.2a4.5 4.5 0 010 6.4l1.2 1.2a6 6 0 000-8.8l-1.2 1.2zm2.8-2.8a7.8 7.8 0 010 11l1.2 1.2a9.3 9.3 0 000-13.4l-1.2 1.2z" fill="currentColor"/></svg>`,
    music: `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3v10.3a4 4 0 10-2 3.46V7.7l8-2.3v7.86a4 4 0 10-2 3.46V5.7L12 3z" fill="currentColor"/></svg>`,
    spotify: `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 2a10 10 0 100 20 10 10 0 000-20zm4.6 14.3a.8.8 0 01-1.1-.2 12.5 12.5 0 00-13.8-3.7.8.8 0 11-.8-1.4 14.1 14.1 0 0115.5 4.1.8.8 0 01-.8 1.2zm1.5-3.4a1 1 0 00-1.3-.3 15.8 15.8 0 00-16.5-4.4 1 1 0 10-.9-1.8 17.8 17.8 0 0118.6 5 .9.9 0 00-.9 1.5zm.2-3.6a1.2 1.2 0 00-1.5-.4 19.2 19.2 0 00-18.8-5.2 1.2 1.2 0 10-1-2.2 21.6 21.6 0 0121.2 5.8 1.2 1.2 0 00-1.1 1.8z" fill="currentColor"/></svg>`,
    youtube: `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M21.6 7.2a2.5 2.5 0 00-1.8-1.8C18 5 12 5 12 5s-6 0-7.8.4A2.5 2.5 0 002.4 7.2 26 26 0 002 12a26 26 0 00.4 4.8 2.5 2.5 0 001.8 1.8C6 19 12 19 12 19s6 0 7.8-.4a2.5 2.5 0 001.8-1.8A26 26 0 0022 12a26 26 0 00-.4-4.8zM10 15.5v-7l6 3.5-6 3.5z" fill="currentColor"/></svg>`,
  };

  function parseYoutubeId(url) {
    const u = String(url || "");
    return (
      u.match(/youtu\.be\/([\w-]+)/)?.[1] ||
      u.match(/youtube\.com\/watch\?v=([\w-]+)/)?.[1] ||
      u.match(/youtube\.com\/embed\/([\w-]+)/)?.[1] ||
      null
    );
  }

  async function fetchMediaMeta(url) {
    const raw = String(url || "").trim();
    if (!raw) return null;

    const ytId = parseYoutubeId(raw);
    if (ytId) {
      let title = "YouTube vaizdo įrašas";
      let artist = "YouTube";
      try {
        const res = await fetch(`https://www.youtube.com/oembed?url=${encodeURIComponent(raw)}&format=json`);
        if (res.ok) {
          const data = await res.json();
          title = data.title || title;
          artist = data.author_name || artist;
        }
      } catch (_) {}
      return {
        title,
        artist,
        thumbnail: `https://img.youtube.com/vi/${ytId}/hqdefault.jpg`,
      };
    }

    if (raw.includes("spotify.com")) {
      try {
        const res = await fetch(`https://open.spotify.com/oembed?url=${encodeURIComponent(raw)}`);
        if (res.ok) {
          const data = await res.json();
          return {
            title: data.title || "Spotify",
            artist: data.author_name || "Spotify",
            thumbnail: data.thumbnail_url || "",
          };
        }
      } catch (_) {}
      return { title: "Spotify takelis", artist: "Spotify", thumbnail: "" };
    }

    return { title: "Medija", artist: "Tiesioginė nuoroda", thumbnail: "" };
  }

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

  function coverHtml(session) {
    const thumb = session?.thumbnail || "";
    if (thumb) {
      return `<img class="carplay-cover-img" src="${window.PhoneEsc(thumb)}" alt="" loading="lazy" />`;
    }
    return `<span class="carplay-cover-fallback">${ICONS.music}</span>`;
  }

  function sourceLabel(session) {
    const type = session?.mediaType || "";
    if (type === "youtube") return "YouTube";
    if (type === "spotify") return "Spotify";
    if (type === "audio") return "Tiesioginė nuoroda";
    return session?.artist || "CarPlay";
  }

  function renderCarPlayUi(content, state) {
    const s = state?.session || {};
    const playing = !!s.playing;
    const title = s.title || window.t("carplay.emptyTitle", "Niekas negroja");
    const artist = s.artist || sourceLabel(s);
    const vol = Math.round((Number(s.volume) || 0.65) * 100);
    const progress = Math.max(0, Math.min(100, Number(s.progress) || (playing ? 38 : 0)));

    content.className = "scroll-body carplay-body";
    content.innerHTML = `
      <div class="carplay-app">
        <div class="neon-card carplay-now">
          <div class="carplay-cover ${s.thumbnail ? "has-thumb" : "is-fallback"}">
            ${coverHtml(s)}
          </div>
          <div class="carplay-sub">${window.t("carplay.nowPlaying", "Dabar groja")}</div>
          <div class="carplay-title" id="cpTitle">${window.PhoneEsc(title)}</div>
          <div class="carplay-artist" id="cpArtist">${window.PhoneEsc(artist)}</div>
          <div class="carplay-progress"><span style="width:${progress}%"></span></div>
        </div>
        <div class="carplay-transport">
          <button type="button" class="carplay-icon-btn" id="cpSkip" title="Kitas">${ICONS.skip}</button>
          <button type="button" class="carplay-icon-btn play-main" id="cpPlay" title="${playing ? "Pauzė" : "Leisti"}">${playing ? ICONS.pause : ICONS.play}</button>
          <button type="button" class="carplay-icon-btn" id="cpStop" title="Sustabdyti">${ICONS.stop}</button>
        </div>
        <div class="neon-card carplay-volume">
          <span class="carplay-icon-inline">${ICONS.volume}</span>
          <input type="range" id="cpVolume" min="0" max="100" value="${vol}" />
          <span class="carplay-vol-lbl" id="cpVolLbl">${vol}%</span>
        </div>
        <div class="neon-card carplay-url-box">
          <label class="carplay-label">${window.t("carplay.addUrl", "Pridėti nuorodą")}</label>
          <input type="text" id="cpUrl" placeholder="Spotify arba YouTube nuoroda" value="${window.PhoneEsc(s.url || "")}" />
          <div class="carplay-chip-row">
            <button type="button" class="carplay-chip spotify" data-paste="spotify">${ICONS.spotify}<span>Spotify</span></button>
            <button type="button" class="carplay-chip youtube" data-paste="youtube">${ICONS.youtube}<span>YouTube</span></button>
          </div>
          <button type="button" class="neon-btn primary carplay-play-btn" id="cpAddPlay">Leisti automobilyje</button>
        </div>
      </div>`;

    if (!state?.inVehicle) {
      content.innerHTML = `<div class="empty-state carplay-empty">${window.t("carplay.inVehicleOnly", "CarPlay veikia tik sėdint transporto priemonėje.")}</div>`;
      return;
    }

    const coverImg = content.querySelector(".carplay-cover-img");
    if (coverImg) {
      coverImg.addEventListener("error", () => {
        const wrap = coverImg.closest(".carplay-cover");
        if (!wrap) return;
        wrap.classList.remove("has-thumb");
        wrap.classList.add("is-fallback");
        wrap.innerHTML = `<span class="carplay-cover-fallback">${ICONS.music}</span>`;
      });
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

    async function playWithMeta(url, extraAction) {
      const meta = await fetchMediaMeta(url);
      const payload = {
        action: extraAction || "play",
        url,
        title: meta?.title,
        artist: meta?.artist,
        thumbnail: meta?.thumbnail,
      };
      return window.PhoneNui("carplayControl", payload);
    }

    content.querySelector("#cpAddPlay").addEventListener("click", async () => {
      const url = urlInput.value.trim();
      if (!url) return;
      const res = await playWithMeta(url, "play");
      if (!res?.ok) alert(res?.message || "Klaida");
      else renderCarPlayUi(content, { inVehicle: true, session: res.session });
    });

    content.querySelector("#cpPlay").addEventListener("click", async () => {
      const url = urlInput?.value?.trim() || s.url;
      const act = playing ? "pause" : s.stream ? "resume" : "play";
      let res;
      if (act === "play" && url) res = await playWithMeta(url, "play");
      else res = await window.PhoneNui("carplayControl", { action: act, url });
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
      content.innerHTML = `<div class="empty-state carplay-empty">${window.PhoneEsc(res?.message || "CarPlay nepasiekiamas.")}</div>`;
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
