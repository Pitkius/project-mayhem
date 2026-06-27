const root = document.getElementById('root');
const outerSegments = document.getElementById('outer-segments');
const innerSegments = document.getElementById('inner-segments');
const outerIcons = document.getElementById('outer-icons');
const innerIcons = document.getElementById('inner-icons');
const tooltip = document.getElementById('tooltip');
const btnRestoreAll = document.getElementById('btn-restore-all');
const btnClose = document.getElementById('btn-close');

const CX = 210;
const CY = 210;

const ICONS = {
    ear: '<svg viewBox="0 0 24 24"><path d="M12 3C8.5 3 6 5.2 6 8.5c0 2.2 1.2 4.1 3 5.2V20h6v-6.3c1.8-1.1 3-3 3-5.2C18 5.2 15.5 3 12 3zm0 2c2.2 0 4 1.6 4 3.7 0 1.5-.9 2.8-2.2 3.4l-.8.4V18h-2v-4.5l-.8-.4C9.9 12.5 9 11.2 9 9.7 9 7.6 10.8 5 12 5z"/></svg>',
    accessory: '<svg viewBox="0 0 24 24"><path d="M12 4c-3.3 0-6 2.2-6 5.2 0 1.8.9 3.4 2.3 4.4L8 20h8l-.3-6.4c1.4-1 2.3-2.6 2.3-4.4C18 6.2 15.3 4 12 4zm0 2c2 0 3.5 1.3 3.5 3.2 0 1.2-.7 2.3-1.8 2.9l-.7.4v5.5h-2v-5.5l-.7-.4C9.2 11.5 8.5 10.4 8.5 9.2 8.5 7.3 10 6 12 6z"/></svg>',
    watch: '<svg viewBox="0 0 24 24"><path d="M9 2h6l1 3h3v4h-2.1A7 7 0 0112 19a7 7 0 01-4.9-10H5V5h3l1-3zm3 6a5 5 0 100 10 5 5 0 000-10zm0 2.2v2.8l2.4 1.4-.8 1.4L11 14V10.2h1z"/></svg>',
    bracelet: '<svg viewBox="0 0 24 24"><path d="M7 8c0-2.8 2.2-5 5-5s5 2.2 5 5v1h2v3h-2v1c0 2.8-2.2 5-5 5s-5-2.2-5-5v-1H5v-3h2V8zm2 1v1h10V9c0-1.7-1.3-3-3-3S9 7.3 9 9zm1 4v1c0 1.7 1.3 3 3 3s3-1.3 3-3v-1H10z"/></svg>',
    vest: '<svg viewBox="0 0 24 24"><path d="M12 2l4 2v4l3 2v12H5V10l3-2V4l4-2zm-2 3.2V8l-2 1.3v10h8V9.3l-2-1.3V5.2L12 4.4l-2 .8z"/></svg>',
    torso2: '<svg viewBox="0 0 24 24"><path d="M8 3h8l1 4 3 2v12H4V9l3-2 1-4zm2 2l-.5 2H14l-.5-2h-3.5zM6 11v8h12v-8l-2-1.3H8L6 11z"/></svg>',
    arms: '<svg viewBox="0 0 24 24"><path d="M4 12c2-1 3-3 3-5h2c0 2.5 1.5 4.5 4 6v2H9v-2c-1.2-.8-2.2-2-2.8-3.4L4 12zm16 0l-2.2-2.4C17.2 11.5 16.2 12.7 15 13.5v2h-4v-2c2.5-1.5 4-3.5 4-6h2c0 2 1 4 3 5z"/></svg>',
    hat: '<svg viewBox="0 0 24 24"><path d="M4 14c0-4 3.6-7 8-7s8 3 8 7v1H4v-1zm2 3h12v2H6v-2zm1-5c0-2.8 2.5-5 5-5s5 2.2 5 5H7z"/></svg>',
    shoes: '<svg viewBox="0 0 24 24"><path d="M3 15h3l1 4h11l1-4h2v-2H3v2zm4.2-2l.8-3h9l.8 3H7.2zM6 10l1-4h10l1 4H6z"/></svg>',
    mask: '<svg viewBox="0 0 24 24"><path d="M12 4c-4 0-7 2-7 5v3c0 3 3 5 7 5s7-2 7-5V9c0-3-3-5-7-5zm-5 5c0-1.7 2.2-3 5-3s5 1.3 5 3v3c0 1.7-2.2 3-5 3s-5-1.3-5-3V9zm2 1.5c.6.8 1.8 1.5 3 1.5s2.4-.7 3-1.5v1c0 .8-1.3 1.5-3 1.5s-3-.7-3-1.5v-1z"/></svg>',
    bag: '<svg viewBox="0 0 24 24"><path d="M8 6V5a4 4 0 118 0v1h3v14H5V6h3zm2-1a2 2 0 114 0v1h-4V5zM7 8v10h10V8H7z"/></svg>',
    glass: '<svg viewBox="0 0 24 24"><path d="M4 8h16l-2 10H6L4 8zm2.2 2l1.4 7h8.8l1.4-7H6.2zM9 4h6v2H9V4z"/></svg>',
    decals: '<svg viewBox="0 0 24 24"><path d="M5 5h6v6H5V5zm8 0h6v6h-6V5zM5 13h6v6H5v-6zm8 3l5 3-5 3v-6z"/></svg>',
    pants: '<svg viewBox="0 0 24 24"><path d="M9 3h6l1 5 2 13h-5l-1-8-1 8H7L9 8l1-5zm1.4 2l-.6 3h4.4l-.6-3h-3.2z"/></svg>',
    't-shirt': '<svg viewBox="0 0 24 24"><path d="M7 4l3-2 2 2 2-2 3 2-2 3v13H9V7L7 4zm2.2 2.4L11 8.5V18h2v-9.5l1.8-2.1L13 5.6 12 6.8l-1-1.2-1.8 1.6z"/></svg>',
};

const OUTER_SLOTS = [
    'glass', 'ear', 'accessory', 'watch', 'bracelet', 'vest',
    'torso2', 'arms', 'hat', 'shoes', 'mask', 'bag', 'decals',
];

const INNER_SLOTS = ['pants', 't-shirt'];

let slotStates = {};
let hoveredKey = null;

function post(name, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    });
}

function polarToCartesian(cx, cy, radius, angleDeg) {
    const rad = (angleDeg - 90) * Math.PI / 180;
    return {
        x: cx + radius * Math.cos(rad),
        y: cy + radius * Math.sin(rad),
    };
}

function describeArc(cx, cy, innerR, outerR, startAngle, endAngle) {
    const startOuter = polarToCartesian(cx, cy, outerR, endAngle);
    const endOuter = polarToCartesian(cx, cy, outerR, startAngle);
    const startInner = polarToCartesian(cx, cy, innerR, startAngle);
    const endInner = polarToCartesian(cx, cy, innerR, endAngle);
    const largeArc = endAngle - startAngle <= 180 ? 0 : 1;
    return [
        'M', startOuter.x, startOuter.y,
        'A', outerR, outerR, 0, largeArc, 0, endOuter.x, endOuter.y,
        'L', startInner.x, startInner.y,
        'A', innerR, innerR, 0, largeArc, 1, endInner.x, endInner.y,
        'Z',
    ].join(' ');
}

function createRingSegments(container, slots, innerR, outerR, iconContainer) {
    container.innerHTML = '';
    iconContainer.innerHTML = '';
    const gap = 2.2;
    const slice = 360 / slots.length;

    slots.forEach((slotKey, index) => {
        const start = index * slice + gap / 2;
        const end = (index + 1) * slice - gap / 2;
        const path = document.createElementNS('http://www.w3.org/2000/svg', 'path');
        path.setAttribute('d', describeArc(CX, CY, innerR, outerR, start, end));
        path.classList.add('segment');
        path.dataset.slot = slotKey;
        if (slotStates[slotKey]?.removed) path.classList.add('removed');
        path.addEventListener('mouseenter', () => showTooltip(slotKey, path));
        path.addEventListener('mouseleave', hideTooltip);
        path.addEventListener('click', () => toggleSlot(slotKey));
        container.appendChild(path);

        const mid = start + (end - start) / 2;
        const radius = (innerR + outerR) / 2;
        const pos = polarToCartesian(CX, CY, radius, mid);
        const icon = document.createElement('div');
        icon.className = 'slot-icon' + (slotStates[slotKey]?.removed ? ' removed' : '');
        icon.style.left = `${(pos.x / 420) * 100}%`;
        icon.style.top = `${(pos.y / 420) * 100}%`;
        icon.innerHTML = ICONS[slotKey] || '';
        iconContainer.appendChild(icon);
    });
}

function showTooltip(slotKey, el) {
    hoveredKey = slotKey;
    const label = slotStates[slotKey]?.label || slotKey;
    const state = slotStates[slotKey]?.removed ? 'nusiimta — spausk uždėti' : 'uždėta — spausk nusiimti';
    tooltip.textContent = `${label} (${state})`;
    tooltip.classList.remove('hidden');
    document.querySelectorAll('.segment').forEach((seg) => seg.classList.remove('active'));
    el.classList.add('active');
}

function hideTooltip() {
    hoveredKey = null;
    tooltip.classList.add('hidden');
    document.querySelectorAll('.segment').forEach((seg) => seg.classList.remove('active'));
}

function renderMenu() {
    createRingSegments(outerSegments, OUTER_SLOTS, 108, 198, outerIcons);
    createRingSegments(innerSegments, INNER_SLOTS, 52, 102, innerIcons);
}

function toggleSlot(slotKey) {
    post('clothingRadial:toggle', { slotKey });
}

function openMenu(data) {
    slotStates = data.slots || {};
    root.classList.remove('hidden');
    renderMenu();
}

function updateStates(slots) {
    slotStates = slots || slotStates;
    renderMenu();
    if (hoveredKey && slotStates[hoveredKey]) {
        const el = document.querySelector(`.segment[data-slot="${hoveredKey}"]`);
        if (el) showTooltip(hoveredKey, el);
    }
}

function closeMenu() {
    root.classList.add('hidden');
    hideTooltip();
}

btnRestoreAll.addEventListener('click', () => post('clothingRadial:restoreAll'));
btnRestoreAll.addEventListener('mouseenter', () => {
    tooltip.textContent = 'Uždėti visus drabužius';
    tooltip.classList.remove('hidden');
});
btnRestoreAll.addEventListener('mouseleave', hideTooltip);
btnClose.addEventListener('click', () => post('clothingRadial:close'));
document.querySelector('.radial-backdrop').addEventListener('click', () => post('clothingRadial:close'));

window.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') post('clothingRadial:close');
});

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'open') openMenu(data);
    if (data.action === 'update') updateStates(data.slots);
    if (data.action === 'close') closeMenu();
});
