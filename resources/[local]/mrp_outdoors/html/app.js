const wrap = document.getElementById('wrap');
const titleEl = document.getElementById('title');
const hintEl = document.getElementById('hint');
const fishingEl = document.getElementById('fishing');
const butcherEl = document.getElementById('butcher');
const fishZone = document.getElementById('fishZone');
const fishNeedle = document.getElementById('fishNeedle');
const seqDisplay = document.getElementById('seqDisplay');
const butcherBar = document.getElementById('butcherBar');
const cancelBtn = document.getElementById('cancelBtn');

let active = null;
let raf = null;

const ARROWS = ['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight'];
const ARROW_LABELS = { ArrowUp: '↑', ArrowDown: '↓', ArrowLeft: '←', ArrowRight: '→' };

function post(name, data) {
    fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data || {}),
    }).catch(() => {});
}

function finish(success) {
    if (!active) return;
    const mode = active.mode;
    stopLoop();
    active = null;
    wrap.classList.add('hidden');
    post('minigameResult', { success, mode });
}

function stopLoop() {
    if (raf) cancelAnimationFrame(raf);
    raf = null;
    window.removeEventListener('keydown', onKey);
}

function onKey(e) {
    if (!active) return;
    if (e.code === 'Escape') {
        e.preventDefault();
        post('minigameCancel', {});
        stopLoop();
        active = null;
        wrap.classList.add('hidden');
        return;
    }
    if (active.mode === 'fishing' && e.code === 'Space') {
        e.preventDefault();
        const needle = active.needlePos;
        const zStart = active.zoneStart;
        const zEnd = zStart + active.zoneWidth;
        finish(needle >= zStart && needle <= zEnd);
    }
    if (active.mode === 'butcher' && ARROWS.includes(e.code)) {
        e.preventDefault();
        const expected = active.sequence[active.step];
        if (e.code !== expected) {
            finish(false);
            return;
        }
        active.step += 1;
        seqDisplay.textContent = active.sequence.slice(active.step).map(k => ARROW_LABELS[k]).join(' ');
        butcherBar.style.width = `${(active.step / active.sequence.length) * 100}%`;
        if (active.step >= active.sequence.length) finish(true);
    }
}

function startFishing(data) {
    titleEl.textContent = 'Žvejyba';
    hintEl.textContent = data.label || 'Spausk SPACE žalioje zonoje';
    fishingEl.classList.remove('hidden');
    butcherEl.classList.add('hidden');

    const zoneWidth = 0.14 + Math.random() * 0.12;
    const zoneStart = 0.08 + Math.random() * (0.84 - zoneWidth);
    fishZone.style.left = `${zoneStart * 100}%`;
    fishZone.style.width = `${zoneWidth * 100}%`;

    active = {
        mode: 'fishing',
        needlePos: 0,
        dir: 1,
        speed: 0.012 + Math.random() * 0.012,
        zoneStart,
        zoneWidth,
    };

    const tick = () => {
        if (!active || active.mode !== 'fishing') return;
        active.needlePos += active.dir * active.speed;
        if (active.needlePos >= 1) { active.needlePos = 1; active.dir = -1; }
        if (active.needlePos <= 0) { active.needlePos = 0; active.dir = 1; }
        fishNeedle.style.left = `calc(${active.needlePos * 100}% - 2px)`;
        raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    window.addEventListener('keydown', onKey);
}

function startButcher(data) {
    titleEl.textContent = 'Skerdimas / apdorojimas';
    hintEl.textContent = data.label || 'Spausk rodykles teisinga tvarka';
    butcherEl.classList.remove('hidden');
    fishingEl.classList.add('hidden');

    const len = 4 + Math.floor(Math.random() * 3);
    const sequence = [];
    for (let i = 0; i < len; i++) sequence.push(ARROWS[Math.floor(Math.random() * ARROWS.length)]);

    seqDisplay.textContent = sequence.map(k => ARROW_LABELS[k]).join(' ');
    butcherBar.style.width = '0%';

    active = { mode: 'butcher', sequence, step: 0 };
    window.addEventListener('keydown', onKey);
}

window.addEventListener('message', (ev) => {
    const msg = ev.data;
    if (msg.action === 'open') {
        wrap.classList.remove('hidden');
        if (msg.mode === 'fishing') startFishing(msg.data || {});
        else if (msg.mode === 'butcher') startButcher(msg.data || {});
    }
});

cancelBtn.addEventListener('click', () => {
    post('minigameCancel', {});
    stopLoop();
    active = null;
    wrap.classList.add('hidden');
});
