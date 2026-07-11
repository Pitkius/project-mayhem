(function () {
    const RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'mrp_jobs';
    const $ = (id) => document.getElementById(id);

    let currentView = 'cashier';   // 'cashier' | 'kitchen'
    let orders = [];

    const STATUS_LABEL = {
        pending: 'Laukia', cooking: 'Gaminama', ready: 'Paruošta', served: 'Priduota',
    };

    function post(name, data) {
        return fetch(`https://${RES}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {}),
        }).catch(() => {});
    }

    function itemRows(order, editable) {
        const names = Object.keys(order.items || {});
        return names.map((n) => {
            const need = order.items[n];
            const made = (order.produced && order.produced[n]) || 0;
            const doneCls = made >= need ? 'item__done' : 'item__count';
            let action = '';
            if (currentView === 'kitchen' && order.status === 'cooking' && made < need) {
                action = `<button class="btn btn--accent btn--sm" data-produce="${order.id}" data-item="${n}">Gaminti</button>`;
            }
            return `<div class="item">
                <span class="item__name">${labelFor(n)}</span>
                <span class="${doneCls}">${made}/${need}</span>
                ${action}
            </div>`;
        }).join('');
    }

    function labelFor(item) {
        return (window.ITEM_LABELS && window.ITEM_LABELS[item]) || item;
    }

    function footActions(order) {
        if (currentView === 'cashier') {
            if (order.status === 'pending') {
                return `<button class="btn btn--blue btn--sm" data-confirm="${order.id}">Perduoti virtuvei</button>`;
            }
            if (order.status === 'ready') {
                return `<button class="btn btn--green btn--sm" data-serve="${order.id}">Priduoti klientui</button>`;
            }
        }
        return '';
    }

    function render() {
        const list = $('burgerList');
        const empty = $('burgerEmpty');

        let shown = orders;
        if (currentView === 'kitchen') {
            shown = orders.filter((o) => o.status === 'cooking' || o.status === 'ready');
        }

        if (!shown.length) {
            empty.classList.remove('hidden');
            list.innerHTML = '';
            return;
        }
        empty.classList.add('hidden');

        list.innerHTML = shown.map((o) => `
            <div class="order">
                <div class="order__top">
                    <div>
                        <div class="order__id">Užsakymas #${o.id}</div>
                        <div class="order__label">${o.label || ''}</div>
                    </div>
                    <span class="badge badge--${o.status}">${STATUS_LABEL[o.status] || o.status}</span>
                </div>
                ${o.line ? `<div class="line">„${o.line}"</div>` : ''}
                <div class="items">${itemRows(o)}</div>
                <div class="order__foot">
                    <span class="wait">Laukia ${o.waitSec || 0}s</span>
                    <div class="actions">${footActions(o)}</div>
                </div>
            </div>
        `).join('');

        list.querySelectorAll('[data-confirm]').forEach((b) =>
            b.addEventListener('click', () => post('burger:confirm', { orderId: Number(b.dataset.confirm) })));
        list.querySelectorAll('[data-serve]').forEach((b) =>
            b.addEventListener('click', () => post('burger:serve', { orderId: Number(b.dataset.serve) })));
        list.querySelectorAll('[data-produce]').forEach((b) =>
            b.addEventListener('click', () => post('burger:produce', { orderId: Number(b.dataset.produce), item: b.dataset.item })));
    }

    function openPanel(data) {
        currentView = data.view || 'cashier';
        orders = data.orders || [];
        $('burgerHeading').textContent = data.jointId ? 'Burger Shot' : 'Burger Shot';
        $('burgerSub').textContent = currentView === 'kitchen' ? 'Virtuvė' : 'Kasa';
        $('burgerIcon').textContent = currentView === 'kitchen' ? '🔥' : '🧾';
        $('burger').classList.remove('hidden');
        render();
    }

    function closePanel() {
        $('burger').classList.add('hidden');
    }

    window.addEventListener('message', (e) => {
        const msg = e.data || {};
        switch (msg.action) {
            case 'burgerOpen': openPanel(msg.data || {}); break;
            case 'burgerOrders':
                orders = msg.data || [];
                if (!$('burger').classList.contains('hidden')) render();
                break;
            case 'burgerKitchen':
                if (currentView === 'kitchen') { orders = msg.data || []; if (!$('burger').classList.contains('hidden')) render(); }
                break;
            case 'burgerClose': closePanel(); break;
            case 'burgerVoice': playVoice(msg.data); break;
            case 'itemLabels': window.ITEM_LABELS = msg.data || {}; break;
        }
    });

    function playVoice(data) {
        // Neprivaloma: jei yra iš anksto įrašytas audio failas — paleidžiam.
        if (!data || !data.orderId) return;
        const el = $('voice');
        const variation = 1 + Math.floor(Math.random() * 2);
        el.src = `audio/${data.orderId}_${variation}.ogg`;
        el.play().catch(() => { /* nėra failo → tekstas jau rodomas 3D pasaulyje */ });
    }

    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && !$('burger').classList.contains('hidden')) {
            closePanel();
            post('burger:close', {});
        }
    });

    $('burgerClose').addEventListener('click', () => {
        closePanel();
        post('burger:close', {});
    });
})();
