(function () {
  const carplay = {
    inVehicle: false,
    session: null,
    audioEl: null,
    ytPlayer: null,
    ytReady: false,
    activeStream: "",
    mediaType: "",
    duration: 0,
    currentTime: 0,
    isSeeking: false,
    isVolumeDragging: false,
    progressTimer: null,
    ytApiPromise: null,
  };

  const ICONS = {
    play: `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M8 5.5v13l11-6.5-11-6.5z" fill="currentColor"/></svg>`,
    pause: `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M7 5h3v14H7V5zm7 0h3v14h-3V5z" fill="currentColor"/></svg>`,
    skip: `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M5 5.5v13l9-6.5-9-6.5zm11 0v13h2.5v-13H16z" fill="currentColor"/></svg>`,
    stop: `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M7 7h10v10H7V7z" fill="currentColor"/></svg>`,
    volume: `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 10v4h3l4 3.5V6.5L7 10H4zm10.5-1.2a4.5 4.5 0 010 6.4l1.2 1.2a6 6 0 000-8.8l-1.2 1.2zm2.8-2.8a7.8 7.8 0 010 11l1.2 1.2a9.3 9.3 0 000-13.4l-1.2 1.2z" fill="currentColor"/></svg>`,
    music: `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 3v10.3a4 4 0 10-2 3.46V7.7l8-2.3v7.86a4 4 0 10-2 3.46V5.7L12 3z" fill="currentColor"/></svg>`,
    spotify: `<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="12" fill="currentColor"/><path d="M17.9 10.2c-3.1-1.9-8.2-2-11.1-1.1-.5.2-1-.3-1-.8 0-.4.3-.7.7-.8 3.3-1.1 8.8-.9 12.4 1.3.4.2.5.7.3 1.1-.2.4-.7.5-1.1.3zm-.1 2.7c-.2.3-.6.4-.9.2-2.7-1.6-6.8-2.1-10.1-1.1-.4.1-.8-.1-.9-.5-.1-.4.1-.8.5-.9 3.8-1.1 8.4-.5 11.5 1.4.3.2.4.6.2.9zm-1.2 2.7c-.2.3-.6.4-.9.2-2.3-1.4-5.8-1.8-8.6-1-.3.1-.7-.2-.8-.5 0-.4.3-.7.6-.8 3.2-.9 7.2-.5 10 1.1.3.2.4.6.2 1z" fill="#0a0812" fill-opacity="0.8"/></svg>`,
    youtube: `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M21.6 7.2a2.5 2.5 0 00-1.8-1.8C18 5 12 5 12 5s-6 0-7.8.4A2.5 2.5 0 002.4 7.2 26 26 0 002 12a26 26 0 00.4 4.8 2.5 2.5 0 001.8 1.8C6 19 12 19 12 19s6 0 7.8-.4a2.5 2.5 0 001.8-1.8A26 26 0 0022 12a26 26 0 00-.4-4.8zM10 15.5v-7l6 3.5-6 3.5z" fill="currentColor"/></svg>`,
  };

  function formatTime(seconds) {
    const s = Math.max(0, Math.floor(Number(seconds) || 0));
    const m = Math.floor(s / 60);
    const r = s % 60;
    return `${m}:${String(r).padStart(2, "0")}`;
  }

  function syncRangeFill(el) {
    if (!el) return;
    const max = Number(el.max) || 100;
    const min = Number(el.min) || 0;
    const val = Number(el.value);
    const pct = max === min ? 0 : ((val - min) / (max - min)) * 100;
    el.style.setProperty("--fill", `${pct}%`);
  }

  function loadYouTubeApi() {
    if (window.YT && window.YT.Player) return Promise.resolve();
    if (carplay.ytApiPromise) return carplay.ytApiPromise;
    carplay.ytApiPromise = new Promise((resolve) => {
      const done = () => resolve();
      const prev = window.onYouTubeIframeAPIReady;
      window.onYouTubeIframeAPIReady = () => {
        if (typeof prev === "function") prev();
        done();
      };
      if (!document.getElementById("yt-iframe-api")) {
        const script = document.createElement("script");
        script.id = "yt-iframe-api";
        script.src = "https://www.youtube.com/iframe_api";
        document.head.appendChild(script);
      } else if (window.YT && window.YT.Player) {
        done();
      }
    });
    return carplay.ytApiPromise;
  }

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

  function stopProgressLoop() {
    if (carplay.progressTimer) {
      clearInterval(carplay.progressTimer);
      carplay.progressTimer = null;
    }
  }

  function getMediaTimes() {
    if (carplay.audioEl && Number.isFinite(carplay.audioEl.duration)) {
      return {
        current: carplay.audioEl.currentTime || 0,
        duration: carplay.audioEl.duration || 0,
      };
    }
    if (carplay.ytPlayer && carplay.ytReady && typeof carplay.ytPlayer.getCurrentTime === "function") {
      return {
        current: carplay.ytPlayer.getCurrentTime() || 0,
        duration: carplay.ytPlayer.getDuration() || 0,
      };
    }
    return { current: carplay.currentTime || 0, duration: carplay.duration || 0 };
  }

  function updateProgressUi(opts = {}) {
    const { current, duration } = getMediaTimes();
    if (duration > 0) {
      carplay.duration = duration;
      carplay.currentTime = current;
    }

    const curEl = document.getElementById("cpCurrent");
    const durEl = document.getElementById("cpDuration");
    const seekEl = document.getElementById("cpSeek");
    if (!seekEl) return;

    const dur = carplay.duration || 0;
    const cur = carplay.isSeeking ? Number(seekEl.value) : carplay.currentTime || 0;

    if (curEl) curEl.textContent = formatTime(cur);
    if (durEl) durEl.textContent = dur > 0 ? formatTime(dur) : "--:--";

    if (!carplay.isSeeking) {
      seekEl.max = dur > 0 ? String(dur) : "100";
      seekEl.value = dur > 0 ? String(Math.min(cur, dur)) : "0";
      seekEl.disabled = dur <= 0;
      syncRangeFill(seekEl);
    }
  }

  function startProgressLoop() {
    stopProgressLoop();
    carplay.progressTimer = setInterval(() => {
      updateProgressUi();
      const { duration } = getMediaTimes();
      if (duration > 0 && duration !== carplay.duration) {
        carplay.duration = duration;
        window.PhoneNui("carplayControl", { action: "duration", duration }).catch(() => {});
      }
    }, 500);
  }

  function destroyPlayers() {
    stopProgressLoop();
    carplay.ytReady = false;
    if (carplay.audioEl) {
      carplay.audioEl.pause();
      carplay.audioEl.removeAttribute("src");
      carplay.audioEl = null;
    }
    if (carplay.ytPlayer) {
      try {
        carplay.ytPlayer.destroy();
      } catch (_) {}
      carplay.ytPlayer = null;
    }
    ensureAudioHost().innerHTML = "";
    carplay.activeStream = "";
    carplay.mediaType = "";
    carplay.duration = 0;
    carplay.currentTime = 0;
  }

  function applyVolume(volume) {
    const v = Math.max(0, Math.min(1, Number(volume) || 0));
    if (carplay.audioEl) carplay.audioEl.volume = v;
    if (carplay.ytPlayer && carplay.ytReady && typeof carplay.ytPlayer.setVolume === "function") {
      carplay.ytPlayer.setVolume(Math.round(v * 100));
    }
    if (!carplay.isVolumeDragging) {
      const volInput = document.getElementById("cpVolume");
      const volLbl = document.getElementById("cpVolLbl");
      const pct = Math.round(v * 100);
      if (volInput) {
        volInput.value = String(pct);
        syncRangeFill(volInput);
      }
      if (volLbl) volLbl.textContent = `${pct}%`;
    }
  }

  function seekMedia(seconds) {
    const t = Math.max(0, Number(seconds) || 0);
    if (carplay.audioEl && Number.isFinite(carplay.audioEl.duration)) {
      carplay.audioEl.currentTime = Math.min(t, carplay.audioEl.duration);
      carplay.currentTime = carplay.audioEl.currentTime;
    } else if (carplay.ytPlayer && carplay.ytReady && typeof carplay.ytPlayer.seekTo === "function") {
      carplay.ytPlayer.seekTo(t, true);
      carplay.currentTime = t;
    } else {
      carplay.currentTime = t;
    }
    updateProgressUi();
  }

  function bindAudioEvents(audio) {
    audio.addEventListener("loadedmetadata", () => {
      carplay.duration = audio.duration || 0;
      updateProgressUi();
      if (carplay.duration > 0) {
        window.PhoneNui("carplayControl", { action: "duration", duration: carplay.duration }).catch(() => {});
      }
    });
    audio.addEventListener("timeupdate", () => {
      if (!carplay.isSeeking) {
        carplay.currentTime = audio.currentTime || 0;
        updateProgressUi();
      }
    });
    audio.addEventListener("ended", () => {
      stopProgressLoop();
      updateProgressUi();
    });
  }

  function playYoutube(videoId, volume) {
    const host = ensureAudioHost();
    host.innerHTML = '<div id="yt-player-node"></div>';
    carplay.ytReady = false;
    loadYouTubeApi().then(() => {
      carplay.ytPlayer = new window.YT.Player("yt-player-node", {
        height: "0",
        width: "0",
        videoId,
        playerVars: {
          autoplay: 1,
          controls: 0,
          disablekb: 1,
          playsinline: 1,
          modestbranding: 1,
          rel: 0,
        },
        events: {
          onReady: (e) => {
            carplay.ytReady = true;
            e.target.setVolume(Math.round((Number(volume) || 0.65) * 100));
            carplay.duration = e.target.getDuration() || 0;
            startProgressLoop();
            updateProgressUi();
            if (carplay.duration > 0) {
              window.PhoneNui("carplayControl", { action: "duration", duration: carplay.duration }).catch(() => {});
            }
          },
          onStateChange: (e) => {
            if (e.data === window.YT.PlayerState.PLAYING) startProgressLoop();
            if (e.data === window.YT.PlayerState.PAUSED) stopProgressLoop();
            if (e.data === window.YT.PlayerState.ENDED) {
              stopProgressLoop();
              updateProgressUi();
            }
          },
        },
      });
    });
  }

  function playAudio(cmd) {
    if (!cmd) return;
    const host = ensureAudioHost();

    if (cmd.command === "stop") {
      destroyPlayers();
      updateProgressUi();
      return;
    }
    if (cmd.command === "pause") {
      if (carplay.audioEl) carplay.audioEl.pause();
      if (carplay.ytPlayer && carplay.ytReady && typeof carplay.ytPlayer.pauseVideo === "function") {
        carplay.ytPlayer.pauseVideo();
      }
      stopProgressLoop();
      return;
    }
    if (cmd.command === "volume") {
      applyVolume(cmd.volume);
      return;
    }
    if (cmd.command === "seek") {
      if (cmd.seconds != null) seekMedia(cmd.seconds);
      else if (cmd.position != null && carplay.duration > 0) seekMedia(cmd.position * carplay.duration);
      return;
    }
    if (cmd.command === "play" && cmd.stream) {
      if (carplay.activeStream === cmd.stream && (carplay.audioEl || carplay.ytPlayer)) {
        applyVolume(cmd.volume);
        if (carplay.audioEl) {
          carplay.audioEl.play().catch(() => {});
          startProgressLoop();
        } else if (carplay.ytPlayer && carplay.ytReady) {
          carplay.ytPlayer.playVideo();
          startProgressLoop();
        }
        return;
      }

      destroyPlayers();
      carplay.activeStream = cmd.stream;
      carplay.mediaType = cmd.mediaType || "";

      const ytId = parseYoutubeId(cmd.stream) || (cmd.mediaType === "youtube" ? parseYoutubeId(cmd.url || "") : null);
      if (ytId || cmd.mediaType === "youtube") {
        playYoutube(ytId || parseYoutubeId(cmd.stream), cmd.volume);
        return;
      }

      carplay.audioEl = document.createElement("audio");
      carplay.audioEl.autoplay = true;
      carplay.audioEl.volume = Number(cmd.volume) || 0.65;
      carplay.audioEl.src = cmd.stream;
      bindAudioEvents(carplay.audioEl);
      host.appendChild(carplay.audioEl);
      carplay.audioEl.play().catch(() => {});
      startProgressLoop();
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

  function syncSessionMeta(content, session) {
    const s = session || {};
    const titleEl = content.querySelector("#cpTitle");
    const artistEl = content.querySelector("#cpArtist");
    const playBtn = content.querySelector("#cpPlay");
    if (titleEl) titleEl.textContent = s.title || window.t("carplay.emptyTitle", "Niekas negroja");
    if (artistEl) artistEl.textContent = s.artist || sourceLabel(s);
    if (playBtn) {
      const playing = !!s.playing;
      playBtn.title = playing ? "Pauzė" : "Leisti";
      playBtn.innerHTML = playing ? ICONS.pause : ICONS.play;
    }
  }

  function bindRangeControl(input, onChange) {
    if (!input) return;
    syncRangeFill(input);
    input.classList.add("carplay-range");
    input.addEventListener("input", () => syncRangeFill(input));
    if (onChange) {
      input.addEventListener("change", onChange);
    }
  }

  function renderCarPlayUi(content, state) {
    const s = state?.session || {};
    const playing = !!s.playing;
    const title = s.title || window.t("carplay.emptyTitle", "Niekas negroja");
    const artist = s.artist || sourceLabel(s);
    const vol = Math.round((Number(s.volume) || 0.65) * 100);
    const dur = Number(s.duration) || carplay.duration || 0;
    const pos = Number(s.position) || carplay.currentTime || 0;

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
          <div class="carplay-progress-wrap">
            <div class="carplay-time-row">
              <span class="carplay-time" id="cpCurrent">${formatTime(pos)}</span>
              <input type="range" class="carplay-seek carplay-range" id="cpSeek" min="0" max="${dur > 0 ? dur : 100}" value="${dur > 0 ? Math.min(pos, dur) : 0}" step="0.1" ${dur > 0 ? "" : "disabled"} />
              <span class="carplay-time end" id="cpDuration">${dur > 0 ? formatTime(dur) : "--:--"}</span>
            </div>
          </div>
        </div>
        <div class="carplay-transport">
          <button type="button" class="carplay-icon-btn" id="cpSkip" title="Kitas">${ICONS.skip}</button>
          <button type="button" class="carplay-icon-btn play-main" id="cpPlay" title="${playing ? "Pauzė" : "Leisti"}">${playing ? ICONS.pause : ICONS.play}</button>
          <button type="button" class="carplay-icon-btn" id="cpStop" title="Sustabdyti">${ICONS.stop}</button>
        </div>
        <div class="neon-card carplay-volume">
          <span class="carplay-icon-inline">${ICONS.volume}</span>
          <input type="range" class="carplay-range" id="cpVolume" min="0" max="100" step="1" value="${vol}" />
          <span class="carplay-vol-lbl" id="cpVolLbl">${vol}%</span>
        </div>
        <div class="neon-card carplay-url-box">
          <label class="carplay-label">${window.t("carplay.addUrl", "Pridėti nuorodą")}</label>
          <input type="text" id="cpUrl" placeholder="${window.t("carplay.urlPlaceholder", "Spotify / YouTube nuoroda")}" value="${window.PhoneEsc(s.url || "")}" />
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

    const seekEl = content.querySelector("#cpSeek");
    if (seekEl) {
      seekEl.classList.add("carplay-range");
      syncRangeFill(seekEl);
    }
    seekEl?.addEventListener("pointerdown", () => {
      carplay.isSeeking = true;
    });
    seekEl?.addEventListener("pointerup", () => {
      carplay.isSeeking = false;
    });
    seekEl?.addEventListener("input", () => {
      const val = Number(seekEl.value) || 0;
      const curEl = content.querySelector("#cpCurrent");
      if (curEl) curEl.textContent = formatTime(val);
      syncRangeFill(seekEl);
    });
    seekEl?.addEventListener("change", async () => {
      carplay.isSeeking = false;
      const seconds = Number(seekEl.value) || 0;
      seekMedia(seconds);
      await window.PhoneNui("carplayControl", { action: "seek", seconds }).catch(() => {});
    });

    const volEl = content.querySelector("#cpVolume");
    bindRangeControl(volEl);
    volEl?.addEventListener("pointerdown", () => {
      carplay.isVolumeDragging = true;
    });
    volEl?.addEventListener("pointerup", () => {
      carplay.isVolumeDragging = false;
    });
    volEl?.addEventListener("input", async (e) => {
      const pct = Number(e.target.value) || 0;
      content.querySelector("#cpVolLbl").textContent = `${pct}%`;
      syncRangeFill(volEl);
      const v = pct / 100;
      applyVolume(v);
      await window.PhoneNui("carplayControl", { action: "volume", volume: v }).catch(() => {});
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

    if (playing && s.stream && s.stream !== carplay.activeStream) {
      playAudio({
        command: "play",
        stream: s.stream,
        url: s.url,
        mediaType: s.mediaType,
        volume: s.volume,
      });
    } else {
      applyVolume(s.volume);
    }

    updateProgressUi();
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
      if (!content || title?.textContent !== "CarPlay") return;

      const sameStream = payload.session.stream && payload.session.stream === carplay.activeStream;
      if (sameStream) {
        syncSessionMeta(content, payload.session);
        applyVolume(payload.session.volume);
        if (payload.session.duration) carplay.duration = payload.session.duration;
        updateProgressUi();
      } else {
        renderCarPlayUi(content, payload);
      }
    }
  });
})();
