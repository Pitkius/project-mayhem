const root = document.getElementById('root');
const plateLabel = document.getElementById('plateLabel');
const navEl = document.getElementById('nav');
const panelEl = document.getElementById('panel');
const hintText = document.getElementById('hintText');

let state = {
    bayIndex: null,
    plate: '',
    tab: 'paint',
    paintType: 0,
    paintTypes: [],
    windowTints: [],
    bodyMods: [],
    perfMods: [],
    turboOn: false,
    modView: null, // { modType, label, returnTab, variants }
};

const TABS = [
    { id: 'paint', icon: '🎨', label: 'Dažymas' },
    { id: 'tint', icon: '🪟', label: 'Langų tamsinimas' },
    { id: 'perf', icon: '⚡', label: 'Patobulinimai' },
    { id: 'body', icon: '🔧', label: 'Kėbulo detalės' },
];

/** Apytikslės GTA spalvų peržiūros (vizualiai, ne tiksliai 1:1) */
function colorForIndex(i) {
    const h = (i * 2.27) % 360;
    const s = i < 20 ? 8 : (i < 40 ? 15 : 55 + (i % 30));
    const l = i < 10 ? 92 : (i < 20 ? 18 : 35 + (i % 25));
    return `hsl(${h}, ${s}%, ${l}%)`;
}

function post(name, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
    });
}

function setHint(text) {
    hintText.textContent = text || 'Peržiūra ant transporto — išsaugok tik užbaigus darbą.';
}

function renderNav() {
    navEl.innerHTML = TABS.map(t => `
        <button type="button" class="nav__item ${state.tab === t.id ? 'active' : ''}" data-tab="${t.id}">
            <span class="nav__icon">${t.icon}</span>
            <span>${t.label}</span>
        </button>
    `).join('');
    navEl.querySelectorAll('[data-tab]').forEach(btn => {
        btn.addEventListener('click', () => {
            state.tab = btn.dataset.tab;
            state.modView = null;
            render();
        });
    });
}

function renderPaint() {
    const type = state.paintTypes.find(p => p.paintType === state.paintType) || state.paintTypes[0];
    const pills = state.paintTypes.map(pt => `
        <button type="button" class="pill ${pt.paintType === state.paintType ? 'active' : ''}" data-pt="${pt.paintType}">
            ${pt.label}
        </button>
    `).join('');

    const swatches = Array.from({ length: 160 }, (_, i) => `
        <button type="button" class="swatch" data-ci="${i}" style="background:${colorForIndex(i)}" title="Indeksas ${i}">
            <span>${i}</span>
        </button>
    `).join('');

    panelEl.innerHTML = `
        <div class="section__title">Dažymas</div>
        <div class="section__sub">${type ? type.txt : 'Pasirink dažų tipą ir spalvos indeksą (0–159).'}</div>
        <div class="pills">${pills}</div>
        <div class="color-grid">${swatches}</div>
    `;

    panelEl.querySelectorAll('[data-pt]').forEach(btn => {
        btn.addEventListener('click', () => {
            state.paintType = Number(btn.dataset.pt);
            render();
        });
    });
    panelEl.querySelectorAll('[data-ci]').forEach(btn => {
        btn.addEventListener('click', () => {
            const ci = Number(btn.dataset.ci);
            post('applyPaint', { paintType: state.paintType, colorIndex: ci });
            panelEl.querySelectorAll('.swatch').forEach(s => s.classList.remove('active'));
            btn.classList.add('active');
            setHint(`Peržiūra: ${type ? type.label : ''}, indeksas ${ci}`);
        });
    });
}

function renderTint() {
    const rows = state.windowTints.map(t => `
        <button type="button" class="tint-row" data-tint="${t.idx}">
            <span class="tint-row__label">${t.label}</span>
            <span class="tint-row__meta">ID ${t.idx}</span>
        </button>
    `).join('');

    panelEl.innerHTML = `
        <div class="section__title">Langų tamsinimas</div>
        <div class="section__sub">Pasirink tamsinimo lygį — iškart matysi ant transporto.</div>
        <div class="tint-list">${rows}</div>
    `;

    panelEl.querySelectorAll('[data-tint]').forEach(btn => {
        btn.addEventListener('click', () => {
            post('applyTint', { idx: Number(btn.dataset.tint) });
            panelEl.querySelectorAll('.tint-row').forEach(r => r.classList.remove('active'));
            btn.classList.add('active');
        });
    });
}

function renderModCategories(list, title, sub, returnTab) {
    if (state.modView) {
        renderModVariants();
        return;
    }

    const rows = list.map(m => `
        <button type="button" class="mod-row" data-mod="${m.id}" data-label="${m.label}" data-count="${m.count}">
            <span class="mod-row__label">${m.label}</span>
            <span class="mod-row__meta">${m.count > 0 ? `${m.count} variantų` : 'Netinka šiai mašinai'}</span>
        </button>
    `).join('');

    let extra = '';
    if (returnTab === 'perf') {
        extra = `
            <button type="button" class="mod-row" id="turboToggle">
                <span class="mod-row__label">Turbo</span>
                <span class="mod-row__meta">${state.turboOn ? 'Įjungtas' : 'Išjungtas'}</span>
            </button>
        `;
    }

    panelEl.innerHTML = `
        <div class="section__title">${title}</div>
        <div class="section__sub">${sub}</div>
        <div class="mod-list">${rows}${extra}</div>
    `;

    panelEl.querySelectorAll('[data-mod]').forEach(btn => {
        btn.addEventListener('click', () => {
            const count = Number(btn.dataset.count);
            if (count <= 0) return;
            post('requestVariants', {
                modType: Number(btn.dataset.mod),
                label: btn.dataset.label,
                returnTab,
            });
        });
    });

    const turboBtn = document.getElementById('turboToggle');
    if (turboBtn) {
        turboBtn.addEventListener('click', () => {
            post('toggleTurbo', {});
        });
    }
}

function renderModVariants() {
    const mv = state.modView;
    const variants = mv.variants || [];
    const btns = [
        `<button type="button" class="variant-btn variant-btn--stock" data-idx="-1">Gamyklinis</button>`,
        ...variants.map(v => `
            <button type="button" class="variant-btn" data-idx="${v.idx}">${v.label}</button>
        `),
    ].join('');

    panelEl.innerHTML = `
        <div class="back-row">
            <button type="button" class="btn btn--ghost" id="btnBackMods">← Atgal</button>
        </div>
        <div class="section__title">${mv.label}</div>
        <div class="section__sub">Pasirink dalį — rodoma ant transporto.</div>
        ${variants.length === 0 ? '<div class="empty">Nėra variantų šiai kategorijai.</div>' : `<div class="variant-grid">${btns}</div>`}
    `;

    document.getElementById('btnBackMods')?.addEventListener('click', () => {
        state.modView = null;
        render();
    });

    panelEl.querySelectorAll('[data-idx]').forEach(btn => {
        btn.addEventListener('click', () => {
            post('installMod', {
                modType: mv.modType,
                idx: Number(btn.dataset.idx),
                label: mv.label,
            });
        });
    });
}

function render() {
    renderNav();
    if (state.tab === 'paint') renderPaint();
    else if (state.tab === 'tint') renderTint();
    else if (state.tab === 'perf') renderModCategories(state.perfMods, 'Patobulinimai', 'Variklis, stabdžiai, pavarų dėžė, pakaba, šarvai, turbo.', 'perf');
    else if (state.tab === 'body') renderModCategories(state.bodyMods, 'Kėbulo detalės', 'Spoileriai, buferiai, gaubtas ir kt.', 'body');
}

function open(data) {
    state.bayIndex = data.bayIndex;
    state.plate = data.plate || '—';
    state.paintTypes = data.paintTypes || [];
    state.windowTints = data.windowTints || [];
    state.bodyMods = data.bodyMods || [];
    state.perfMods = data.perfMods || [];
    state.turboOn = !!data.turboOn;
    state.paintType = state.paintTypes[0]?.paintType ?? 0;
    state.tab = 'paint';
    state.modView = null;

    plateLabel.textContent = state.plate;
    setHint();
    root.classList.remove('hidden');
    render();
}

function close() {
    root.classList.add('hidden');
    state.modView = null;
}

document.getElementById('btnClose').addEventListener('click', () => post('close'));
document.getElementById('btnSave').addEventListener('click', () => post('save'));
document.getElementById('btnRepair').addEventListener('click', () => post('repair'));

window.addEventListener('message', (e) => {
    const msg = e.data || {};
    if (msg.action === 'open') open(msg);
    if (msg.action === 'close') close();
    if (msg.action === 'variants') {
        state.modView = {
            modType: msg.modType,
            label: msg.label,
            returnTab: msg.returnTab,
            variants: msg.variants || [],
        };
        render();
    }
    if (msg.action === 'turboState') {
        state.turboOn = !!msg.on;
        if (state.tab === 'perf' && !state.modView) render();
    }
    if (msg.action === 'hint') setHint(msg.text);
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !root.classList.contains('hidden')) {
        post('close');
    }
});
