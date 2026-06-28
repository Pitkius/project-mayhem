const root = document.getElementById('root');
let state = null;
let editingRank = null;
let editingDivision = null;

function post(name, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
    });
}

function money(n) {
    return '$' + (Number(n) || 0).toLocaleString('lt-LT');
}

function setTab(tab) {
    document.querySelectorAll('.bm-tab').forEach((b) => b.classList.toggle('active', b.dataset.tab === tab));
    document.querySelectorAll('.bm-panel').forEach((p) => p.classList.toggle('active', p.dataset.panel === tab));
}

function fillGradeSelect(sel, grades) {
    sel.innerHTML = '';
    (grades || []).forEach((g) => {
        const o = document.createElement('option');
        o.value = g.level;
        o.textContent = `[${g.level}] ${g.name} — ${money(g.payment)}`;
        sel.appendChild(o);
    });
}

function fillDivisionSelect(sel, divisions) {
    sel.innerHTML = '';
    (divisions || []).filter((d) => d.choosable).forEach((d) => {
        const o = document.createElement('option');
        o.value = d.id;
        o.textContent = `${d.abbr} — ${d.label}`;
        sel.appendChild(o);
    });
}

function renderMembers() {
    const list = document.getElementById('membersList');
    list.innerHTML = '';
    (state.members || []).forEach((m) => {
        const row = document.createElement('div');
        row.className = 'bm-row';
        row.innerHTML = `
            <div class="bm-row-main">
                <div class="bm-row-title">${m.name.trim() || 'Nežinomas'}</div>
                <div class="bm-row-sub">ID ${m.id} · [${m.grade}] ${m.gradeName}</div>
            </div>
            <span class="bm-badge ${m.onduty ? 'on' : 'off'}">${m.onduty ? 'Tarnyboje' : 'Ne tarnyboje'}</span>`;
        row.addEventListener('click', () => {
            document.getElementById('memberId').value = m.id;
        });
        list.appendChild(row);
    });
    if (!state.members.length) {
        list.innerHTML = '<p class="bm-muted">Nėra prisijungusių narių.</p>';
    }
}

function renderRanks() {
    const list = document.getElementById('ranksList');
    list.innerHTML = '';
    const sorted = [...(state.grades || [])].sort((a, b) => b.level - a.level);
    sorted.forEach((g) => {
        const row = document.createElement('div');
        row.className = 'bm-row';
        const tags = [];
        if (g.isboss) tags.push('Vadas');
        if (g.isdeputy) tags.push('Pavad.');
        row.innerHTML = `
            <div class="bm-row-main">
                <div class="bm-row-title">[${g.level}] ${g.name}</div>
                <div class="bm-row-sub">${money(g.payment)} ${tags.length ? '· ' + tags.join(', ') : ''}</div>
            </div>
            <span class="bm-badge">${g.level}</span>`;
        if (state.canManageRanks && (state.isBoss || g.level < state.playerGrade)) {
            row.addEventListener('click', () => openRankEditor(g));
        }
        list.appendChild(row);
    });
}

function renderDivisions() {
    const list = document.getElementById('divisionsList');
    list.innerHTML = '';
    (state.divisions || []).forEach((d) => {
        const row = document.createElement('div');
        row.className = 'bm-row';
        row.innerHTML = `
            <div class="bm-row-main">
                <div class="bm-row-title">${d.abbr} — ${d.label}</div>
                <div class="bm-row-sub">${d.description || ''} · min. rangas ${d.minGrade}</div>
            </div>
            <span class="bm-badge">${d.id}</span>`;
        if (state.canManageRanks) {
            row.addEventListener('click', () => openDivisionEditor(d));
        }
        list.appendChild(row);
    });
}

function openRankEditor(grade) {
    editingRank = grade;
    document.getElementById('rankEditor').classList.remove('hidden');
    document.getElementById('rankEditorTitle').textContent = `Redaguoti rangą [${grade.level}]`;
    document.getElementById('rankName').value = grade.name || '';
    document.getElementById('rankPayment').value = grade.payment || 0;
    document.getElementById('rankIsBoss').checked = !!grade.isboss;
    document.getElementById('rankIsDeputy').checked = !!grade.isdeputy;
    const permsBox = document.getElementById('rankPerms');
    permsBox.innerHTML = '';
    (state.permissionKeys || []).forEach((p) => {
        const val = grade.permissions && grade.permissions[p.key] != null ? grade.permissions[p.key] : '';
        const row = document.createElement('div');
        row.className = 'bm-perm-row';
        row.innerHTML = `<span>${p.label}</span>`;
        const inp = document.createElement('input');
        inp.type = 'number';
        inp.min = 0;
        inp.placeholder = '—';
        inp.dataset.key = p.key;
        inp.value = val === '' ? '' : val;
        row.appendChild(inp);
        permsBox.appendChild(row);
    });
}

function openDivisionEditor(div) {
    editingDivision = div || {};
    document.getElementById('divisionEditor').classList.remove('hidden');
    document.getElementById('divId').value = div?.id || '';
    document.getElementById('divId').disabled = !!div?.id;
    document.getElementById('divLabel').value = div?.label || '';
    document.getElementById('divAbbr').value = div?.abbr || '';
    document.getElementById('divDesc').value = div?.description || '';
    document.getElementById('divMinGrade').value = div?.minGrade ?? 4;
    document.getElementById('divChoosable').checked = div?.choosable !== false;
}

function applyState(data) {
    state = data;
    document.getElementById('jobLabel').textContent = data.jobLabel || 'Frakcijos vadovybė';
    document.getElementById('jobSub').textContent = data.jobName || '';
    document.getElementById('fundBalance').textContent = money(data.balance);
    document.getElementById('overviewFund').textContent = money(data.balance);
    document.getElementById('onlineCount').textContent = String((data.members || []).length);
    document.getElementById('overviewOnline').textContent = String((data.members || []).length);
    document.getElementById('overviewSalary').textContent = data.salaryEnabled ? 'Aktyvios' : 'Išjungtos';
    document.getElementById('overviewMultiplier').textContent = `Koeficientas: ${Number(data.salaryMultiplier || 1).toFixed(2)}×`;
    document.getElementById('overviewGrade').textContent = String(data.playerGrade);

    const divTab = document.getElementById('tabDivisions');
    divTab.classList.toggle('hidden', !data.divisionsEnabled);
    document.getElementById('memberDivisionWrap').classList.toggle('hidden', !data.divisionsEnabled);
    document.getElementById('btnSetDivision').classList.toggle('hidden', !data.divisionsEnabled);

    fillGradeSelect(document.getElementById('memberGrade'), data.grades);
    fillDivisionSelect(document.getElementById('memberDivision'), data.divisions);

    document.getElementById('salaryEnabled').checked = !!data.salaryEnabled;
    document.getElementById('salaryMultiplier').value = data.salaryMultiplier ?? 1;

    const locked = !data.canManageFunds;
    document.getElementById('fundLocked').classList.toggle('hidden', !locked);
    ['btnDeposit', 'btnWithdraw', 'btnSaveSalary', 'btnAddGrade', 'btnAddDivision'].forEach((id) => {
        const el = document.getElementById(id);
        if (el) {
            el.classList.toggle('hidden', locked && (id === 'btnDeposit' || id === 'btnWithdraw'));
            if (id === 'btnSaveSalary' || id === 'btnAddGrade' || id === 'btnAddDivision') {
                el.classList.toggle('hidden', !data.canManageRanks);
            }
            el.disabled = locked && (id === 'btnDeposit' || id === 'btnWithdraw');
        }
    });
    document.getElementById('salaryEnabled').disabled = !data.canManageFunds;
    document.getElementById('salaryMultiplier').disabled = !data.canManageFunds;

    renderMembers();
    renderRanks();
    if (data.divisionsEnabled) renderDivisions();
}

document.querySelectorAll('.bm-tab').forEach((btn) => {
    btn.addEventListener('click', () => setTab(btn.dataset.tab));
});

document.getElementById('btnClose').addEventListener('click', () => post('close'));
document.getElementById('btnRefresh').addEventListener('click', () => post('refresh'));
document.getElementById('btnDuty').addEventListener('click', () => post('toggleDuty'));

document.getElementById('btnDeposit').addEventListener('click', () => {
    post('fundDeposit', { amount: document.getElementById('fundAmount').value });
});
document.getElementById('btnWithdraw').addEventListener('click', () => {
    post('fundWithdraw', { amount: document.getElementById('fundAmount').value });
});
document.getElementById('btnSaveSalary').addEventListener('click', () => {
    post('setSalarySettings', {
        enabled: document.getElementById('salaryEnabled').checked,
        multiplier: document.getElementById('salaryMultiplier').value,
    });
});

document.getElementById('btnHire').addEventListener('click', () => {
    post('hire', {
        targetId: document.getElementById('memberId').value,
        grade: document.getElementById('memberGrade').value,
        divisionId: document.getElementById('memberDivision').value,
    });
});
document.getElementById('btnFire').addEventListener('click', () => {
    post('fire', { targetId: document.getElementById('memberId').value });
});
document.getElementById('btnSetGrade').addEventListener('click', () => {
    post('setGrade', {
        targetId: document.getElementById('memberId').value,
        grade: document.getElementById('memberGrade').value,
    });
});
document.getElementById('btnSetDivision').addEventListener('click', () => {
    post('setMemberDivision', {
        targetId: document.getElementById('memberId').value,
        divisionId: document.getElementById('memberDivision').value,
    });
});

document.getElementById('btnAddGrade').addEventListener('click', () => post('addGrade'));
document.getElementById('btnSaveRank').addEventListener('click', () => {
    if (!editingRank) return;
    const permissions = {};
    document.querySelectorAll('#rankPerms input[data-key]').forEach((inp) => {
        if (inp.value !== '') permissions[inp.dataset.key] = Number(inp.value);
    });
    post('saveGrade', {
        level: editingRank.level,
        name: document.getElementById('rankName').value,
        payment: document.getElementById('rankPayment').value,
        isboss: document.getElementById('rankIsBoss').checked,
        isdeputy: document.getElementById('rankIsDeputy').checked,
        permissions,
    });
    document.getElementById('rankEditor').classList.add('hidden');
});
document.getElementById('btnCancelRank').addEventListener('click', () => {
    document.getElementById('rankEditor').classList.add('hidden');
});

document.getElementById('btnAddDivision').addEventListener('click', () => openDivisionEditor(null));
document.getElementById('btnSaveDivision').addEventListener('click', () => {
    post('saveDivision', {
        id: document.getElementById('divId').value,
        label: document.getElementById('divLabel').value,
        abbr: document.getElementById('divAbbr').value,
        description: document.getElementById('divDesc').value,
        minGrade: document.getElementById('divMinGrade').value,
        choosable: document.getElementById('divChoosable').checked,
    });
    document.getElementById('divisionEditor').classList.add('hidden');
});
document.getElementById('btnCancelDivision').addEventListener('click', () => {
    document.getElementById('divisionEditor').classList.add('hidden');
});

window.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') post('close');
});

window.addEventListener('message', (ev) => {
    const msg = ev.data;
    if (msg.action === 'open') {
        root.classList.remove('hidden');
        applyState(msg.data);
        setTab('overview');
    } else if (msg.action === 'sync') {
        applyState(msg.data);
    } else if (msg.action === 'close') {
        root.classList.add('hidden');
        state = null;
    }
});
