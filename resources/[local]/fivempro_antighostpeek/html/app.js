const indicator = document.getElementById('ghostpeek-indicator');
const label = indicator.querySelector('.ghostpeek__label');

const LABELS = {
    clear: 'OK',
    blocked: 'COVER',
};

window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || data.action !== 'ghostpeek') {
        return;
    }

    const state = data.state || (data.active ? 'blocked' : 'hidden');
    const visible = state === 'clear' || state === 'blocked';

    indicator.dataset.state = state;
    indicator.classList.toggle('ghostpeek--visible', visible);
    indicator.classList.toggle('ghostpeek--hidden', !visible);
    indicator.setAttribute('aria-hidden', visible ? 'false' : 'true');
    label.textContent = LABELS[state] || '';
});
