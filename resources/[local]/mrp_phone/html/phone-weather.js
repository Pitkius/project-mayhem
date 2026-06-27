(function () {
  const ICONS = {
    sun: '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="5"/><path d="M12 2v2M12 20v2M4.2 4.2l1.4 1.4M18.4 18.4l1.4 1.4M2 12h2M20 12h2M4.2 19.8l1.4-1.4M18.4 5.6l1.4-1.4"/></svg>',
    cloud: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M7 18h11a4 4 0 0 0 .3-8 5.5 5.5 0 0 0-10.7 1.5A3.5 3.5 0 0 0 7 18z"/></svg>',
    rain: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M7 16h11a4 4 0 0 0 .3-8 5.5 5.5 0 0 0-10.7 1.5A3.5 3.5 0 0 0 7 16z"/><path d="M9 19l-1 2M13 19l-1 2M17 19l-1 2"/></svg>',
    storm: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M7 15h11a4 4 0 0 0 .3-8 5.5 5.5 0 0 0-10.7 1.5A3.5 3.5 0 0 0 7 15z"/><path d="M13 16l-3 5h3l-2 4"/></svg>',
    fog: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 14h16M3 17h14M5 11h12"/></svg>',
    partly: '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="8" cy="9" r="3"/><path d="M7 17h12a4 4 0 0 0 .2-8 4.5 4.5 0 0 0-8.6 1.2A3 3 0 0 0 7 17z"/></svg>',
    smog: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 15h16M3 18h12M6 12h10a3 3 0 0 0 .2-6 3.5 3.5 0 0 0-6.8 1A2.5 2.5 0 0 0 6 12z"/></svg>',
    snow: '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 2v20M4 6l16 12M20 6L4 18M2 12h20"/></svg>',
  };

  const ui = {
    region: "los_santos",
    regions: [],
    data: null,
    selectedDay: 0,
    loading: false,
  };

  function esc(s) {
    return window.PhoneEsc ? window.PhoneEsc(s) : String(s || "");
  }

  function nui(action, data) {
    return window.PhoneNui ? window.PhoneNui(action, data) : Promise.resolve({ ok: false });
  }

  function icon(name) {
    return ICONS[name] || ICONS.cloud;
  }

  function padHour(h) {
    return `${String(h).padStart(2, "0")}:00`;
  }

  function regionLabel(id) {
    const hit = ui.regions.find((r) => r.id === id);
    return hit ? hit.label : id;
  }

  function renderCurrent() {
    const cur = ui.data?.current;
    if (!cur) return `<p class="muted small">Kraunama…</p>`;
    return `
      <div class="wx-now">
        <div class="wx-now-icon">${icon(cur.icon)}</div>
        <div class="wx-now-meta">
          <div class="wx-now-temp">${cur.tempC}°C</div>
          <div class="wx-now-label">${esc(cur.label)}</div>
          <div class="wx-now-time muted small">Dabar · ${padHour(ui.data.gameHour)} (žaidimo laikas)</div>
        </div>
      </div>`;
  }

  function renderDayTabs() {
    const days = ui.data?.days || [];
    return `<div class="wx-days">${days
      .map(
        (d, i) =>
          `<button type="button" class="wx-day-tab${ui.selectedDay === i ? " active" : ""}" data-day="${i}">${esc(d.label)}</button>`
      )
      .join("")}</div>`;
  }

  function renderHourly() {
    const day = ui.data?.days?.[ui.selectedDay];
    if (!day) return "";
    const nowDay = ui.data?.gameDay;
    const nowHour = ui.data?.gameHour;
    return `<div class="wx-hourly">${day.hours
      .map((h) => {
        const isNow = day.gameDay === nowDay && h.hour === nowHour;
        return `<div class="wx-hour${isNow ? " now" : ""}">
          <span class="wx-hour-time">${padHour(h.hour)}</span>
          <span class="wx-hour-icon">${icon(h.icon)}</span>
          <span class="wx-hour-temp">${h.tempC}°</span>
          <span class="wx-hour-label">${esc(h.label)}</span>
        </div>`;
      })
      .join("")}</div>`;
  }

  function renderCities() {
    return `<div class="wx-cities">${ui.regions
      .map(
        (r) =>
          `<button type="button" class="wx-city${ui.region === r.id ? " active" : ""}" data-region="${esc(r.id)}">
            <strong>${esc(r.label)}</strong>
            <span>${esc(r.hint || "")}</span>
          </button>`
      )
      .join("")}</div>`;
  }

  function renderShell() {
    return `
      <div class="wx-app">
        <div class="wx-head">
          <h2>Orų prognozė</h2>
          <p class="muted small">7 žaidimo dienos · sinchronizuota su realiu oru žaidime</p>
        </div>
        ${renderCities()}
        <div class="wx-card neon-card">${renderCurrent()}</div>
        ${ui.data ? renderDayTabs() : ""}
        ${ui.data ? renderHourly() : `<p class="muted small wx-loading">Kraunama prognozė…</p>`}
      </div>`;
  }

  async function loadForecast(regionId) {
    ui.loading = true;
    ui.region = regionId || ui.region;
    const content = document.getElementById("weatherAppRoot");
    if (content) content.innerHTML = renderShell();
    bindEvents();
    try {
      const res = await nui("getWeatherForecast", { region: ui.region });
      if (res?.ok) {
        ui.data = res;
        if (res.regions?.length) ui.regions = res.regions;
      }
    } catch (_) {
      /* ignore */
    }
    ui.loading = false;
    if (content) content.innerHTML = renderShell();
    bindEvents();
  }

  async function loadRegions() {
    try {
      const res = await nui("getWeatherRegions", {});
      if (res?.ok && res.regions?.length) ui.regions = res.regions;
    } catch (_) {
      ui.regions = [
        { id: "los_santos", label: "Los Santos", hint: "Miesto centras" },
        { id: "sandy_shores", label: "Sandy Shores", hint: "Dykrų regionas" },
        { id: "paleto_bay", label: "Paleto Bay", hint: "Šiaurinis miestelis" },
      ];
    }
  }

  function bindEvents() {
    document.querySelectorAll(".wx-city").forEach((btn) => {
      btn.onclick = () => loadForecast(btn.dataset.region);
    });
    document.querySelectorAll(".wx-day-tab").forEach((btn) => {
      btn.onclick = () => {
        ui.selectedDay = Number(btn.dataset.day) || 0;
        const root = document.getElementById("weatherAppRoot");
        if (root) {
          root.innerHTML = renderShell();
          bindEvents();
        }
      };
    });
  }

  window.PhoneWeather = {
    async render(content) {
      content.innerHTML = `<div id="weatherAppRoot" class="scroll-body weather-body"></div>`;
      const root = document.getElementById("weatherAppRoot");
      if (!ui.regions.length) await loadRegions();
      root.innerHTML = renderShell();
      bindEvents();
      await loadForecast(ui.region);
    },
  };

  window.renderWeatherApp = (content) => {
    if (window.PhoneWeather) window.PhoneWeather.render(content);
  };
})();
