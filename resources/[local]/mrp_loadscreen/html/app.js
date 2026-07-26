const SLIDES = [
  {
    image: 'assets/slide_taxi.jpg',
    tag: 'TAKSI',
    title: 'CIVILIO DIENA',
    desc: 'Vežk keleivius po miestą ir užsidirbk legaliai.',
  },
  {
    image: 'assets/slide_trucking.jpg',
    tag: 'PERVEŽIMAI',
    title: 'ILGAS REISAS',
    desc: 'Kroviniai, terminai ir kelias per visą San Andreas.',
  },
  {
    image: 'assets/slide_mining.jpg',
    tag: 'KASYKLA',
    title: 'KARJERA MIESTE',
    desc: 'Kasykla, sunkus darbas ir stabilūs pinigai.',
  },
  {
    image: 'assets/slide_mechanic.jpg',
    tag: 'MECHANIKAI',
    title: 'PO RATAS',
    desc: 'Remontas, tuningas ir patikimi meistrai.',
  },
  {
    image: 'assets/slide_burger.jpg',
    tag: 'MAISTAS',
    title: 'VIRTUVĖS RITMAS',
    desc: 'Restoranai ir greitas maistas — civilio ritmas.',
  },
  {
    image: 'assets/slide_fishing.jpg',
    tag: 'GAMTA',
    title: 'TYLA PRIE VANDENS',
    desc: 'Žvejyba ir lauko darbai — pailsėk nuo miesto triukšmo.',
  },
  {
    image: 'assets/slide_housing.jpg',
    tag: 'BŪSTAS',
    title: 'SAVO VIETA',
    desc: 'Butai, namai ir raktas nuo tavo erdvės.',
  },
  {
    image: 'assets/slide_racing.jpg',
    tag: 'TRANSPORTAS',
    title: 'GREITIS IR STILIUS',
    desc: 'Salonai, garažai, KMA — tavo mašina, tavo kelias.',
  },
  {
    image: 'assets/slide_casino.jpg',
    tag: 'KAZINO',
    title: 'AZARTAS',
    desc: 'Diamond Casino — dideli laimėjimai ar didelė rizika.',
  },
  {
    image: 'assets/slide_ems.jpg',
    tag: 'EMS',
    title: 'GYVYBĖS IŠGELBĖJIMAS',
    desc: 'Greita medicinos pagalba visame Los Santos.',
  },
  {
    image: 'assets/slide_police.jpg',
    tag: 'LTPD',
    title: 'TARNYBA GATVĖSE',
    desc: 'Patruliuok, reaguok į iškvietimus ir saugok miestą.',
  },
];

const MUSIC = {
  enabled: true,
  volume: 0.28,
  track: 'assets/gta_theme.mp3',
  label: 'Mayhem Roleplay',
};

function nuiPost(name, data = {}) {
  const res = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'mrp_loadscreen';
  return fetch(`https://${res}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  }).catch(() => {});
}

function initLoadscreenMusic() {
  const audio = document.getElementById('themeAudio');
  const toggle = document.getElementById('musicToggle');
  const volume = document.getElementById('musicVolume');
  const label = document.getElementById('musicLabel');
  if (!audio || !toggle || !volume) return;

  let muted = false;
  let hasFile = false;
  let nativeStarted = false;
  let nuiStarted = false;

  if (label) label.textContent = MUSIC.label || 'GTA V — Los Santos';
  volume.value = String(Math.round((MUSIC.volume || 0.28) * 100));
  audio.volume = MUSIC.volume || 0.28;
  if (MUSIC.track && !audio.getAttribute('src')) {
    audio.src = MUSIC.track;
    audio.load();
  }

  const syncUi = () => {
    toggle.classList.toggle('is-muted', muted);
    toggle.textContent = muted ? '🔇' : '♪';
    audio.muted = muted;
  };

  const startNativeMusic = () => {
    if (nativeStarted) return;
    nativeStarted = true;
    nuiPost('loadscreenReady');
    const retry = setInterval(() => {
      nuiPost('loadscreenReady');
    }, 200);
    setTimeout(() => clearInterval(retry), 60000);
  };

  const setNativeMusic = (enabled) => {
    if (enabled) {
      startNativeMusic();
      nuiPost('setLoadscreenMusic', { enabled: true });
      return;
    }
    nuiPost('setLoadscreenMusic', { enabled: false });
  };

  const playNuiAudio = () => {
    if (nuiStarted || muted || !MUSIC.enabled) return;
    const src = MUSIC.track || audio.getAttribute('src');
    if (!src) return;
    nuiStarted = true;
    if (!audio.getAttribute('src')) {
      audio.src = src;
      audio.load();
    }
    audio.play().then(() => {
      hasFile = true;
    }).catch(() => {
      hasFile = false;
      nuiStarted = false;
    });
  };

  const startAllMusic = () => {
    if (muted) return;
    setNativeMusic(true);
    playNuiAudio();
  };

  toggle.addEventListener('click', () => {
    muted = !muted;
    syncUi();
    if (muted) {
      audio.pause();
      setNativeMusic(false);
      nuiStarted = false;
      return;
    }
    startAllMusic();
  });

  volume.addEventListener('input', () => {
    audio.volume = Number(volume.value) / 100;
    if (audio.volume <= 0) {
      muted = true;
      syncUi();
      audio.pause();
      setNativeMusic(false);
      nuiStarted = false;
      return;
    }
    if (muted) {
      muted = false;
      syncUi();
    }
    startAllMusic();
    if (nuiStarted && hasFile) audio.play().catch(() => {});
  });

  syncUi();
  startAllMusic();
  setInterval(() => {
    if (!muted) startAllMusic();
  }, 400);
}

const slidesEl = document.getElementById('slides');
const slideTag = document.getElementById('slideTag');
const slideTitle = document.getElementById('slideTitle');
const slideDesc = document.getElementById('slideDesc');
const slideDots = document.getElementById('slideDots');
const progressFill = document.getElementById('progressFill');
const progressPct = document.getElementById('progressPct');
const progressDetail = document.getElementById('progressDetail');
const statusText = document.getElementById('statusText');

let slideIndex = 0;
let progress = 0;

function buildSlides() {
  SLIDES.forEach((s, i) => {
    const div = document.createElement('div');
    div.className = 'slide' + (i === 0 ? ' is-active' : '');
    div.style.backgroundImage = `url('${s.image}')`;
    slidesEl.appendChild(div);

    const dot = document.createElement('span');
    if (i === 0) dot.classList.add('is-active');
    slideDots.appendChild(dot);
  });
}

function setSlide(i) {
  const slides = slidesEl.querySelectorAll('.slide');
  const dots = slideDots.querySelectorAll('span');
  slides.forEach((el, idx) => el.classList.toggle('is-active', idx === i));
  dots.forEach((el, idx) => el.classList.toggle('is-active', idx === i));

  const s = SLIDES[i];
  slideTag.textContent = s.tag;
  slideTitle.textContent = s.title;
  slideDesc.textContent = s.desc;
}

function rotateSlides() {
  slideIndex = (slideIndex + 1) % SLIDES.length;
  setSlide(slideIndex);
}

function setProgress(fraction, detail) {
  progress = Math.max(progress, Math.min(1, fraction || 0));
  const pct = Math.round(progress * 100);
  progressFill.style.width = `${pct}%`;
  progressPct.textContent = `${pct}%`;
  if (detail) progressDetail.textContent = detail;
  if (pct >= 100) statusText.textContent = 'Beveik baigta...';
  else if (pct > 60) statusText.textContent = 'Kraunami resursai...';
  else if (pct > 20) statusText.textContent = 'Jungiamasi prie serverio...';
}

const handlers = {
  loadProgress(data) {
    setProgress(data.loadFraction, 'Kraunama...');
  },
  onLogLine(data) {
    if (data && data.message) {
      const msg = String(data.message).trim();
      if (msg.length > 3 && msg.length < 80) {
        progressDetail.textContent = msg;
      }
    }
  },
  startInitFunctionOrder(data) {
    setProgress(0.05, `Ruošiama: ${data.type || 'sistema'}...`);
  },
  initFunctionInvoking(data) {
    setProgress(progress + 0.02, data.name || 'Inicializuojama...');
  },
  startDataFileEntries(data) {
    setProgress(0.15, `Failai: ${data.count || '...'}`);
  },
  performMapLoadFunction() {
    setProgress(Math.max(progress, 0.35), 'Kraunamas žemėlapis...');
  },
  endInitFunction() {
    setProgress(Math.max(progress, 0.5), 'Baigiama inicializacija...');
  },
};

window.addEventListener('message', (e) => {
  const fn = handlers[e.data && e.data.eventName];
  if (fn) fn(e.data);
});

buildSlides();
setProgress(0, 'Inicializuojama...');
initLoadscreenMusic();
setInterval(rotateSlides, 6500);

// Fallback progress jei FiveM eventai vėluoja
let fake = 0;
const fakeTimer = setInterval(() => {
  if (progress >= 0.92) {
    clearInterval(fakeTimer);
    return;
  }
  fake += 0.004 + Math.random() * 0.006;
  setProgress(fake, progressDetail.textContent);
}, 400);
