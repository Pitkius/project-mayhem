const indicator = document.getElementById('ghostpeek-indicator');

window.addEventListener('message', (event) => {
    const data = event.data;
    if (!data || data.action !== 'ghostpeek') {
        return;
    }

    indicator.classList.toggle('visible', data.active === true);
    indicator.setAttribute('aria-hidden', data.active ? 'false' : 'true');
});
