/* Unikalūs narkotikų mini-žaidimai — naudoja schedule.js helperius (btn, setStep, postSchedule, …) */
window.DrugGameModes = (() => {
  const modes = {};

  function runGaugeHold(data, label, opts = {}) {
    const speed = opts.speed || 1.6;
    const need = opts.need || 55 + (data.difficulty || 1) * 8;
    const timeout = opts.timeout || 14000;
    schBoard.innerHTML = "";
    setStep(1, opts.steps || 1, label);
    const track = document.createElement("div");
    track.className = "sch-gauge-track";
    const zone = document.createElement("div");
    zone.className = "sch-gauge-zone";
    const zoneLeft = (opts.zoneLeft != null ? opts.zoneLeft : 25 + Math.random() * 40);
    zone.style.left = `${zoneLeft}%`;
    const needle = document.createElement("div");
    needle.className = "sch-gauge-needle";
    track.appendChild(zone);
    track.appendChild(needle);
    schBoard.appendChild(track);

    let pos = 10;
    let dir = speed;
    let hold = 0;
    const iv = setInterval(() => {
      pos += dir;
      if (pos >= 98) dir = -speed;
      if (pos <= 2) dir = speed;
      needle.style.left = `${pos}%`;
      const inZone = pos >= zoneLeft && pos <= zoneLeft + 22;
      if (inZone) hold += 1;
      if (schHint) schHint.textContent = `Stabilizuok: ${Math.min(100, Math.floor((hold / need) * 100))}%`;
      if (hold >= need) {
        clearInterval(iv);
        postSchedule(true);
      }
    }, 40);

    const onKey = (ev) => {
      if (ev.code === "Space") {
        ev.preventDefault();
        const inZone = pos >= zoneLeft && pos <= zoneLeft + 22;
        if (!inZone) {
          clearInterval(iv);
          window.removeEventListener("keydown", onKey);
          failSchedule();
        }
      }
    };
    window.addEventListener("keydown", onKey);
    scheduleTimer = setTimeout(() => {
      clearInterval(iv);
      window.removeEventListener("keydown", onKey);
      failSchedule();
    }, timeout);
  }

  function clickPointsBoard(stepHint, total, positions, onDone) {
    schBoard.innerHTML = "";
    setStep(1, 1, stepHint);
    const wrap = document.createElement("div");
    wrap.className = "sch-trim-wrap dg-click-board";
    const bg = document.createElement("div");
    bg.className = "dg-board-bg";
    bg.innerHTML = `<span>${dataIcon}</span>`;
    wrap.appendChild(bg);
    const points = document.createElement("div");
    points.className = "sch-trim-points";
    let done = 0;
    positions.slice(0, total).forEach((pos, i) => {
      const p = document.createElement("button");
      p.type = "button";
      p.className = "sch-trim-point dg-spot";
      p.style.top = pos.top;
      p.style.left = pos.left;
      p.title = `Taškas ${i + 1}`;
      p.onclick = () => {
        if (p.classList.contains("done")) return;
        p.classList.add("done");
        done += 1;
        if (done >= total) onDone();
      };
      points.appendChild(p);
    });
    wrap.appendChild(points);
    schBoard.appendChild(wrap);
  }

  let dataIcon = "🌿";

  /* THC — dervos nuskynimas */
  modes.thc_scrape = (data) => {
    dataIcon = data.icon || "🍃";
    let phase = 0;
    const need = data.steps || 4;
    const spots = [
      { top: "20%", left: "40%" },
      { top: "35%", left: "52%" },
      { top: "50%", left: "38%" },
      { top: "65%", left: "50%" },
      { top: "42%", left: "62%" },
    ];
    function renderScrape() {
      clickPointsBoard("Nuskink dervą — spausk žalius taškus ant lapo", need, spots, () => {
        schBoard.innerHTML = "";
        setStep(2, 2, "Surink dervą į indą");
        const jar = document.createElement("button");
        jar.type = "button";
        jar.className = "dg-jar-btn";
        jar.innerHTML = "<span>🫙</span><small>Surink dervą</small>";
        jar.onclick = () => postSchedule(true, { score: 88 });
        schBoard.appendChild(jar);
      });
    }
    renderScrape();
  };

  /* THC vape kasetė */
  modes.thc_cartridge = (data) =>
    runGaugeHold(data, "Pildyk kasetę — SPACE žalioje zonoje", { speed: 1.3, need: 48, steps: 3 });

  modes.moonshine_still = (data) =>
    runGaugeHold(data, "Distiliatorius — laikyk temperatūrą žalioje zonoje", { speed: 1.2, need: 60 });

  modes.moonshine_jar = (data) => {
    let pours = 0;
    schBoard.innerHTML = "";
    setStep(1, 3, "Supilk samogoną į stiklainį");
    const jar = document.createElement("div");
    jar.className = "sch-bottle dg-jar";
    jar.innerHTML = "<span>🫙</span><div class='sch-fill'></div>";
    schBoard.appendChild(jar);
    schBoard.appendChild(
      btn("Supilti", "primary", () => {
        pours = 1;
        jar.querySelector(".sch-fill").style.height = "75%";
        setStep(2, 3, "Užkorkuok — spausk 3 kartus");
        schBoard.innerHTML = "";
        let corks = 0;
        const corkBtn = document.createElement("button");
        corkBtn.className = "sch-press dg-cork";
        corkBtn.innerHTML = "<span>🍾</span><small>Užkorkuoti</small>";
        corkBtn.onclick = () => {
          corks += 1;
          corkBtn.classList.add("pulse");
          setTimeout(() => corkBtn.classList.remove("pulse"), 150);
          if (corks >= 3) postSchedule(true);
        };
        schBoard.appendChild(corkBtn);
      })
    );
  };

  modes.vape_blend = (data) => {
    schBoard.innerHTML = "";
    setStep(1, 2, "Sulygink mišinio spalvas (slankikliai)");
    const target = 35 + Math.floor(Math.random() * 30);
    const row = document.createElement("div");
    row.className = "dg-blend-row";
    const a = document.createElement("input");
    a.type = "range"; a.min = 0; a.max = 100; a.value = 10; a.className = "dg-range";
    const b = document.createElement("input");
    b.type = "range"; b.min = 0; b.max = 100; b.value = 80; b.className = "dg-range";
    const preview = document.createElement("div");
    preview.className = "dg-blend-preview";
    const sync = () => {
      const av = Number(a.value), bv = Number(b.value);
      preview.style.background = `linear-gradient(135deg, hsl(${av * 2},70%,45%), hsl(${bv * 2},60%,50%))`;
    };
    a.oninput = sync; b.oninput = sync; sync();
    row.append(a, preview, b);
    schBoard.appendChild(row);
    schBoard.appendChild(
      btn("Patvirtinti mišinį", "primary", () => {
        const mid = (Number(a.value) + Number(b.value)) / 2;
        if (Math.abs(mid - target) > 18) return failSchedule();
        setStep(2, 2, "Mišinys paruoštas");
        postSchedule(true);
      })
    );
  };

  modes.vape_dropper = (data) => {
    let drops = 0;
    const need = data.steps || 3;
    schBoard.innerHTML = "";
    setStep(1, need, "Lašink tiksliai į buteliuką");
    const bottle = document.createElement("div");
    bottle.className = "sch-bottle";
    bottle.innerHTML = "<span>🧴</span><div class='sch-fill' id='dgVapeFill'></div>";
    schBoard.appendChild(bottle);
    const dropBtn = btn("Lašas", "primary", () => {
      drops += 1;
      const fill = document.getElementById("dgVapeFill");
      if (fill) fill.style.height = `${Math.min(85, drops * (80 / need))}%`;
      if (drops >= need) postSchedule(true);
      else if (schHint) schHint.textContent = `Lašai ${drops}/${need}`;
    });
    schBoard.appendChild(dropBtn);
  };

  modes.heroin_cook = (data) => {
    schBoard.innerHTML = "";
    setStep(1, 2, "Faza 1 — kaitink tirpalą (laikyk adatą žalioje zonoje)");
    let hold = 0;
    const need = 50;
    const track = document.createElement("div");
    track.className = "sch-gauge-track";
    const zone = document.createElement("div");
    zone.className = "sch-gauge-zone";
    zone.style.left = "30%";
    const needle = document.createElement("div");
    needle.className = "sch-gauge-needle";
    track.append(zone, needle);
    schBoard.appendChild(track);
    let pos = 15;
    let dir = 1.5;
    const iv = setInterval(() => {
      pos += dir;
      if (pos >= 95) dir = -1.5;
      if (pos <= 5) dir = 1.5;
      needle.style.left = `${pos}%`;
      if (pos >= 30 && pos <= 52) hold += 1;
      if (schHint) schHint.textContent = `Kaitinimas ${Math.min(100, Math.floor((hold / need) * 100))}%`;
      if (hold >= need) {
        clearInterval(iv);
        setStep(2, 2, "Faza 2 — maišyk mentoliu (spausk 4×)");
        schBoard.innerHTML = "";
        let stirs = 0;
        const stir = document.createElement("button");
        stir.className = "sch-press";
        stir.innerHTML = "<span>⚗️</span><small>Maišyti 0/4</small>";
        stir.onclick = () => {
          stirs += 1;
          stir.querySelector("small").textContent = `Maišyti ${stirs}/4`;
          if (stirs >= 4) postSchedule(true);
        };
        schBoard.appendChild(stir);
      }
    }, 45);
    scheduleTimer = setTimeout(() => {
      clearInterval(iv);
      failSchedule();
    }, 16000);
  };

  modes.heroin_fold = (data) => {
    let folds = 0;
    const need = data.steps || 3;
    schBoard.innerHTML = "";
    setStep(1, need, "Sulankstyk foliją su produktu");
    const foil = document.createElement("button");
    foil.type = "button";
    foil.className = "dg-foil";
    foil.innerHTML = "<span>📄</span><small>Sulankstyti</small>";
    foil.onclick = () => {
      folds += 1;
      foil.style.transform = `rotate(${folds * 4}deg) scale(${1 - folds * 0.04})`;
      foil.querySelector("small").textContent = `Lankstymas ${folds}/${need}`;
      if (folds >= need) {
        setStep(need, need, "Įdėk į maišelį ir užlydink");
        schBoard.innerHTML = "";
        let seals = 0;
        const bag = document.createElement("button");
        bag.className = "sch-bag seal";
        bag.innerHTML = "<span>👜</span><small>Užlydinti</small>";
        bag.onclick = () => {
          seals += 1;
          if (seals >= 3) postSchedule(true);
        };
        schBoard.appendChild(bag);
      }
    };
    schBoard.appendChild(foil);
  };

  modes.meth_crush_pack = (data) => {
    let crushes = 0;
    schBoard.innerHTML = "";
    setStep(1, 3, "Sutraišk kristalus pestle");
    const crush = document.createElement("button");
    crush.className = "sch-press";
    crush.innerHTML = "<span>🔨</span><small>Sutraiškyti</small>";
    crush.onclick = () => {
      crushes += 1;
      if (crushes >= 4) {
        setStep(2, 3, "Sverti ir supakuoti");
        schBoard.innerHTML = "";
        if (typeof runPackBagGame === "function") {
          const d = { ...data, icon: data.icon || "❄️", steps: 3 };
          runPackBagGame(d);
        } else postSchedule(true);
      } else crush.querySelector("small").textContent = `Traškymas ${crushes}/4`;
    };
    schBoard.appendChild(crush);
  };

  modes.pills_blister = (data) => {
    const slots = data.steps || 3;
    let filled = 0;
    schBoard.innerHTML = "";
    setStep(1, 2, "Įspausk tabletes į blisterį");
    const blister = document.createElement("div");
    blister.className = "dg-blister";
    for (let i = 0; i < slots; i++) {
      const slot = document.createElement("button");
      slot.type = "button";
      slot.className = "dg-blister-slot";
      slot.innerHTML = "💊";
      slot.onclick = () => {
        if (slot.classList.contains("done")) return;
        slot.classList.add("done");
        filled += 1;
        if (filled >= slots) {
          setStep(2, 2, "Užlenk apsauginę plėvelę");
          schBoard.appendChild(btn("Užlenkti", "primary", () => postSchedule(true)));
        }
      };
      blister.appendChild(slot);
    }
    schBoard.appendChild(blister);
  };

  modes.mushroom_brush = (data) => {
    dataIcon = "🍄";
    const need = data.steps || 4;
    const spots = [
      { top: "25%", left: "35%" },
      { top: "40%", left: "55%" },
      { top: "55%", left: "42%" },
      { top: "48%", left: "28%" },
      { top: "62%", left: "58%" },
    ];
    clickPointsBoard("Nušveisk purvą nuo grybo — spausk taškus", need, spots, () =>
      postSchedule(true, { score: 85 })
    );
  };

  modes.mushroom_jar = (data) => {
    schBoard.innerHTML = "";
    setStep(1, 3, "Supilk džiovintus grybus į stiklainį");
    const jar = document.createElement("div");
    jar.className = "dg-jar dg-jar-fill";
    jar.innerHTML = "<span>🫙</span><div class='sch-fill' id='dgMushFill'></div>";
    schBoard.appendChild(jar);
    schBoard.appendChild(
      btn("Supilti", "primary", () => {
        const f = document.getElementById("dgMushFill");
        if (f) f.style.height = "70%";
        setStep(2, 3, "Užsukuvok dangtelį — 3 paspaudimai");
        schBoard.innerHTML = "";
        let caps = 0;
        const cap = document.createElement("button");
        cap.className = "sch-press";
        cap.innerHTML = "<span>🔩</span><small>Užsukti</small>";
        cap.onclick = () => {
          caps += 1;
          if (caps >= 3) postSchedule(true);
        };
        schBoard.appendChild(cap);
      })
    );
  };

  modes.mushroom_harvest = (data) => {
    const need = data.steps || 5;
    let picked = 0;
    schBoard.innerHTML = "";
    setStep(1, 1, "Surink grybus į krepšį — spausk kai pasirodo");
    const basket = document.createElement("div");
    basket.className = "dg-basket";
    const spawnMush = () => {
      if (picked >= need) return;
      const m = document.createElement("button");
      m.type = "button";
      m.className = "dg-mush-spawn";
      m.textContent = "🍄";
      m.style.left = `${15 + Math.random() * 70}%`;
      m.style.top = `${20 + Math.random() * 55}%`;
      m.onclick = () => {
        m.remove();
        picked += 1;
        if (schHint) schHint.textContent = `Surinkta ${picked}/${need}`;
        if (picked >= need) postSchedule(true, { score: 90 });
        else setTimeout(spawnMush, 400 + Math.random() * 500);
      };
      basket.appendChild(m);
    };
    basket.appendChild(document.createElement("div")).className = "dg-basket-base";
    schBoard.appendChild(basket);
    spawnMush();
  };

  modes.coca_harvest = (data) => {
    const need = data.steps || 5;
    let stripped = 0;
    schBoard.innerHTML = "";
    setStep(1, 1, "Nuimk lapus nuo šakos — spausk kiekvieną lapą");
    const branch = document.createElement("div");
    branch.className = "dg-coca-branch";
    const positions = ["12%", "28%", "44%", "60%", "76%"];
    positions.forEach((top, i) => {
      const leaf = document.createElement("button");
      leaf.type = "button";
      leaf.className = "dg-coca-leaf";
      leaf.style.top = top;
      leaf.innerHTML = "🍃";
      leaf.onclick = () => {
        if (leaf.classList.contains("done")) return;
        leaf.classList.add("done");
        stripped += 1;
        if (stripped >= need) postSchedule(true, { score: 88 });
        else if (schHint) schHint.textContent = `Lapai ${stripped}/${need}`;
      };
      branch.appendChild(leaf);
    });
    schBoard.appendChild(branch);
  };

  modes.cocaine_brick = (data) => {
    let presses = 0;
    schBoard.innerHTML = "";
    setStep(1, 3, "Presuok masę į bloką");
    const press = document.createElement("button");
    press.className = "sch-press dg-brick-press";
    press.innerHTML = "<span>🧱</span><small>Presuoti</small>";
    press.onclick = () => {
      presses += 1;
      if (presses >= 4) {
        setStep(2, 3, "Apvyniok plėvele");
        schBoard.innerHTML = "";
        let wraps = 0;
        const wrap = document.createElement("button");
        wrap.className = "dg-foil";
        wrap.innerHTML = "<span>📦</span><small>Apvynioti</small>";
        wrap.onclick = () => {
          wraps += 1;
          if (wraps >= 3) postSchedule(true);
        };
        schBoard.appendChild(wrap);
      } else press.querySelector("small").textContent = `Presas ${presses}/4`;
    };
    schBoard.appendChild(press);
  };

  modes.amp_stamp = (data) => {
    schBoard.innerHTML = "";
    setStep(1, 3, "Užlydink maišelį");
    let seals = 0;
    const bag = document.createElement("button");
    bag.className = "sch-bag seal";
    bag.innerHTML = "<span>👜</span><small>Užlydinti</small>";
    bag.onclick = () => {
      seals += 1;
      if (seals >= 2) {
        setStep(2, 3, "Antspauduok maišelį");
        schBoard.innerHTML = "";
        const stamp = document.createElement("button");
        stamp.className = "sch-press dg-stamp";
        stamp.innerHTML = "<span>⚡</span><small>Antspaudas</small>";
        stamp.onclick = () => postSchedule(true);
        schBoard.appendChild(stamp);
      }
    };
    schBoard.appendChild(bag);
  };

  modes.cocaine_wash = (data) => {
    if (typeof runWashGame === "function") runWashGame(data);
    else failSchedule();
  };

  modes.meth_crystal = (data) => {
    if (typeof runCrystalGame === "function") runCrystalGame(data);
    else failSchedule();
  };

  modes.pills_press = (data) => {
    if (typeof runPressGame === "function") runPressGame(data);
    else failSchedule();
  };

  return modes;
})();
