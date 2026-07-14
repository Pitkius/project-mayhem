(function () {
    "use strict";

    const root = document.getElementById("radial-root");
    const wheel = document.getElementById("radial-wheel");
    const segmentsEl = document.getElementById("radial-segments");
    const centerBtn = document.getElementById("radial-center");
    const centerIcon = document.getElementById("radial-center-icon");
    const centerLabel = document.getElementById("radial-center-label");
    const centerAction = document.getElementById("radial-center-action");
    const hint = document.getElementById("radial-hint");

    const CATEGORY_ICONS = {
        "Bendrauti su žaidėju": "fas fa-user",
        "Transporto priemonė": "fas fa-car",
        Bankas: "fas fa-university",
        Bankomatas: "fas fa-credit-card",
        Parduotuvė: "fas fa-store",
        Garažas: "fas fa-warehouse",
        Sandėlis: "fas fa-box",
        Durys: "fas fa-door-open",
        "Darbo stotis": "fas fa-hammer",
        "Mechaniko įranga": "fas fa-wrench",
        "Mechaniko veiksmai": "fas fa-wrench",
        "Policijos įranga": "fas fa-shield-halved",
        "Policijos veiksmai": "fas fa-shield-halved",
        "Medicinos įranga": "fas fa-kit-medical",
        "Medicinos veiksmai": "fas fa-kit-medical",
        NPC: "fas fa-user",
        Objektas: "fas fa-cube",
        Sąveika: "fas fa-hand-pointer",
        Žaidėjas: "fas fa-user",
    };

    const JOB_CATEGORIES = {
        mechanic: "Mechaniko veiksmai",
        police: "Policijos veiksmai",
        ambulance: "Medicinos veiksmai",
        ems: "Medicinos veiksmai",
    };

    let state = {
        mode: "closed",
        context: { title: "Sąveika", icon: "fas fa-eye" },
        rawOptions: {},
        menuStack: [],
        currentItems: [],
        hoveredIndex: -1,
        segmentNodes: [],
    };

    function post(name, body) {
        return fetch(`https://${GetParentResourceName()}/${name}`, {
            method: "POST",
            headers: { "Content-Type": "application/json; charset=UTF-8" },
            body: body === undefined ? "" : JSON.stringify(body),
        }).catch(() => {});
    }

    function normalizeOptions(data) {
        if (!data) return {};
        if (Array.isArray(data)) {
            const out = {};
            data.forEach((item, i) => {
                if (item) out[i + 1] = item;
            });
            return out;
        }
        return data;
    }

    function resolveCategory(option, context) {
        if (option.category && String(option.category).trim()) {
            return String(option.category).trim();
        }
        const job = (option.jobHint || "").toLowerCase();
        if (job && JOB_CATEGORIES[job]) return JOB_CATEGORIES[job];
        if (context.isPlayer) return "Bendrauti su žaidėju";
        if (context.entityType === 2) return "Transporto priemonė";
        if (context.title) return context.title;
        return "Sąveika";
    }

    function categoryIcon(name, items, context) {
        if (CATEGORY_ICONS[name]) return CATEGORY_ICONS[name];
        if (items && items[0] && items[0].icon) return items[0].icon;
        if (context && context.icon) return context.icon;
        return "fas fa-hand-pointer";
    }

    function actionItem(entry) {
        return {
            type: "action",
            slot: entry.slot,
            label: entry.label || "Veiksmas",
            icon: entry.icon || "fas fa-hand-pointer",
            sublabel: entry.jobHint || "",
        };
    }

    function categoryItem(name, entries, context) {
        return {
            type: "category",
            label: name,
            icon: categoryIcon(name, entries, context),
            sublabel: "Atidaryti",
            children: entries.map((e) => actionItem({ ...e, slot: e.slot })),
        };
    }

    function buildMenuTree(options, context) {
        const entries = [];
        for (const [slot, opt] of Object.entries(options)) {
            if (!opt) continue;
            entries.push({ slot: Number(slot), ...opt });
        }
        entries.sort((a, b) => a.slot - b.slot);

        if (entries.length === 0) {
            return { root: [], needsSubmenu: false };
        }
        if (entries.length === 1) {
            return { root: [actionItem(entries[0])], needsSubmenu: false };
        }

        const groups = new Map();
        for (const entry of entries) {
            const cat = resolveCategory(entry, context);
            if (!groups.has(cat)) groups.set(cat, []);
            groups.get(cat).push(entry);
        }

        if (groups.size === 1) {
            const [name, items] = [...groups.entries()][0];
            if (items.length === 1) {
                return { root: [actionItem(items[0])], needsSubmenu: false };
            }
            return { root: [categoryItem(name, items, context)], needsSubmenu: true };
        }

        const root = [...groups.entries()].map(([name, items]) => categoryItem(name, items, context));
        return { root, needsSubmenu: true };
    }

    function setCenter(ctx, inSubmenu) {
        const title = inSubmenu
            ? state.menuStack[state.menuStack.length - 1]?.label || ctx.title
            : ctx.title || "Sąveika";
        centerIcon.className = inSubmenu
            ? state.menuStack[state.menuStack.length - 1]?.icon || ctx.icon || "fas fa-hand-pointer"
            : ctx.icon || "fas fa-eye";
        centerLabel.textContent = title;
        centerAction.className = inSubmenu ? "fas fa-arrow-left" : "fas fa-xmark";
        centerAction.style.display = state.mode === "interactive" ? "block" : "none";
    }

    function layoutSegments(items) {
        segmentsEl.innerHTML = "";
        state.segmentNodes = [];
        const count = items.length;
        if (!count) return;

        const radius = Math.min(wheel.clientWidth, wheel.clientHeight) * 0.36;

        items.forEach((item, index) => {
            const angle = (2 * Math.PI * index) / count - Math.PI / 2;
            const x = Math.cos(angle) * radius;
            const y = Math.sin(angle) * radius;
            const rot = (angle * 180) / Math.PI + 90;

            const btn = document.createElement("button");
            btn.type = "button";
            btn.className = "radial-seg";
            btn.dataset.index = String(index);
            btn.style.transform = `translate(${x}px, ${y}px) rotate(${rot}deg)`;
            btn.style.transitionDelay = `${index * 25}ms`;

            const inner = document.createElement("div");
            inner.className = "radial-seg__inner";
            inner.style.transform = `rotate(${-rot}deg)`;

            const icon = document.createElement("i");
            icon.className = `${item.icon || "fas fa-hand-pointer"} radial-seg__icon`;

            const label = document.createElement("span");
            label.className = "radial-seg__label";
            label.textContent = item.label;

            const sub = document.createElement("span");
            sub.className = "radial-seg__sub";
            sub.textContent = item.type === "category" ? item.sublabel || "Atidaryti" : item.sublabel || "Pasirinkti";

            inner.appendChild(icon);
            inner.appendChild(label);
            inner.appendChild(sub);
            btn.appendChild(inner);

            btn.addEventListener("mouseenter", () => setHovered(index));
            btn.addEventListener("mouseleave", () => {
                if (state.hoveredIndex === index) setHovered(-1);
            });
            btn.addEventListener("click", (e) => {
                e.stopPropagation();
                if (state.mode !== "interactive") return;
                activateItem(index);
            });

            segmentsEl.appendChild(btn);
            state.segmentNodes.push(btn);
        });
    }

    function renderCurrentMenu(animate) {
        layoutSegments(state.currentItems);
        setCenter(state.context, state.menuStack.length > 0);
        if (animate) {
            root.classList.remove("opening");
            void root.offsetWidth;
            root.classList.add("opening");
        }
    }

    function setHovered(index) {
        state.hoveredIndex = index;
        state.segmentNodes.forEach((node, i) => {
            node.classList.toggle("active", i === index);
        });
    }

    function pushMenu(categoryItem) {
        state.menuStack.push(categoryItem);
        state.currentItems = categoryItem.children || [];
        state.hoveredIndex = -1;
        renderCurrentMenu(true);
        hint.textContent = "Centras — grįžti · ESC — atgal";
    }

    function popMenu() {
        if (state.menuStack.length === 0) return false;
        state.menuStack.pop();
        if (state.menuStack.length === 0) {
            const tree = buildMenuTree(state.rawOptions, state.context);
            state.currentItems = tree.root;
        } else {
            state.currentItems = state.menuStack[state.menuStack.length - 1].children || [];
        }
        state.hoveredIndex = -1;
        renderCurrentMenu(true);
        hint.textContent = state.menuStack.length > 0
            ? "Centras — grįžti · ESC — atgal"
            : "Pasirinkite segmentą · ESC — uždaryti";
        return true;
    }

    function activateItem(index) {
        const item = state.currentItems[index];
        if (!item) return;

        if (item.type === "category") {
            pushMenu(item);
            return;
        }

        if (item.type === "action" && item.slot != null) {
            const node = state.segmentNodes[index];
            if (node) node.classList.add("active");
            closeRadial(false);
            post("selectTarget", item.slot);
        }
    }

    function showRadial(mode) {
        state.mode = mode;
        root.classList.remove("hidden", "closing");
        root.classList.add("visible");
        root.classList.toggle("interactive", mode === "interactive");
        centerAction.style.display = mode === "interactive" ? "block" : "none";
        hint.textContent =
            mode === "interactive"
                ? state.menuStack.length > 0
                    ? "Centras — grįžti · ESC — atgal"
                    : "Pasirinkite segmentą · ESC — uždaryti"
                : "Dešinis pelės — atidaryti meniu";
    }

    function closeRadial(sendClose) {
        root.classList.add("closing");
        root.classList.remove("interactive", "opening");
        state.hoveredIndex = -1;
        state.menuStack = [];
        state.currentItems = [];
        state.rawOptions = {};
        state.segmentNodes = [];
        segmentsEl.innerHTML = "";

        window.setTimeout(() => {
            root.classList.add("hidden");
            root.classList.remove("visible", "closing");
            state.mode = "closed";
        }, 180);

        if (sendClose) post("closeTarget");
    }

    function openIdle() {
        state.mode = "open";
        state.menuStack = [];
        state.currentItems = [];
        state.rawOptions = {};
        state.context = { title: "Sąveika", icon: "fas fa-eye" };
        segmentsEl.innerHTML = "";
        setCenter(state.context, false);
        showRadial("open");
    }

    function foundTarget(payload) {
        state.context = payload.context || { title: "Sąveika", icon: payload.data || "fas fa-eye" };
        if (payload.data && typeof payload.data === "string" && payload.data.startsWith("fa")) {
            state.context.icon = payload.data;
        }
        state.rawOptions = normalizeOptions(payload.options);
        const tree = buildMenuTree(state.rawOptions, state.context);
        state.menuStack = [];
        state.currentItems = tree.root;
        showRadial("preview");
        renderCurrentMenu(true);
    }

    function validTarget(payload) {
        state.context = payload.context || state.context;
        state.rawOptions = normalizeOptions(payload.data);
        const tree = buildMenuTree(state.rawOptions, state.context);
        state.menuStack = [];
        state.currentItems = tree.root;
        showRadial("interactive");
        renderCurrentMenu(true);
    }

    function leftTarget() {
        state.menuStack = [];
        state.hoveredIndex = -1;
        if (state.mode === "interactive") {
            state.mode = "preview";
            root.classList.remove("interactive");
            const tree = buildMenuTree(state.rawOptions, state.context);
            state.currentItems = tree.root;
            renderCurrentMenu(false);
            hint.textContent = "Dešinis pelės — atidaryti meniu";
            return;
        }
        openIdle();
    }

    function onCenterClick() {
        if (state.mode !== "interactive") return;
        if (state.menuStack.length > 0) {
            popMenu();
            return;
        }
        post("closeTarget");
        closeRadial(false);
    }

    function onMouseMove(e) {
        if (state.mode !== "interactive" || !state.currentItems.length) return;
        const rect = wheel.getBoundingClientRect();
        const cx = rect.left + rect.width / 2;
        const cy = rect.top + rect.height / 2;
        const dx = e.clientX - cx;
        const dy = e.clientY - cy;
        const dist = Math.hypot(dx, dy);
        const minR = rect.width * 0.14;
        const maxR = rect.width * 0.52;
        if (dist < minR || dist > maxR) {
            setHovered(-1);
            return;
        }
        let angle = Math.atan2(dy, dx) + Math.PI / 2;
        if (angle < 0) angle += 2 * Math.PI;
        const count = state.currentItems.length;
        const slice = (2 * Math.PI) / count;
        const index = Math.floor((angle + slice / 2) / slice) % count;
        setHovered(index);
    }

    function onMouseDown(e) {
        if (e.button === 2) {
            leftTarget();
            post("leftTarget");
        }
    }

    function onKeyDown(e) {
        if (e.key !== "Escape" && e.key !== "Backspace") return;
        if (state.mode === "interactive" && state.menuStack.length > 0) {
            popMenu();
            return;
        }
        post("closeTarget");
        closeRadial(false);
    }

    centerBtn.addEventListener("click", onCenterClick);
    window.addEventListener("mousemove", onMouseMove);
    window.addEventListener("mousedown", onMouseDown);
    window.addEventListener("keydown", onKeyDown);

    window.addEventListener("message", (event) => {
        const msg = event.data;
        if (!msg || !msg.response) return;
        switch (msg.response) {
            case "openTarget":
                openIdle();
                break;
            case "closeTarget":
                closeRadial(false);
                break;
            case "foundTarget":
                foundTarget(msg);
                break;
            case "validTarget":
                validTarget(msg);
                break;
            case "leftTarget":
                leftTarget();
                break;
            default:
                break;
        }
    });
})();
