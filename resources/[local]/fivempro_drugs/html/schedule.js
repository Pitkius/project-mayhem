/* Schedule-1 stiliaus narkotikų mini-žaidimai */
const mgSchedule = document.getElementById("mgSchedule");
const schTitle = document.getElementById("schTitle");
const schStep = document.getElementById("schStep");
const schBoard = document.getElementById("schBoard");
const schHint = document.getElementById("schHint");

let scheduleActive = false;
let scheduleTimer = null;

function postSchedule(success, extra = {}) {
  if (!scheduleActive) return;
  scheduleActive = false;
  if (scheduleTimer) {
    clearInterval(scheduleTimer);
    scheduleTimer = null;
  }
  if (mgSchedule) mgSchedule.classList.add("hidden");
  if (schBoard) schBoard.innerHTML = "";
  fetch(`https://${GetParentResourceName()}/scheduleResult`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ success: !!success, ...extra }),
  });
}

function setStep(current, total, hint) {
  if (schStep) schStep.textContent = `Žingsnis ${current}/${total}`;
  if (schHint) schHint.textContent = hint || "";
}

function failSchedule() {
  postSchedule(false, { mistakes: 99 });
}

function btn(label, cls, onClick) {
  const b = document.createElement("button");
  b.type = "button";
  b.className = `sch-btn ${cls || ""}`.trim();
  b.textContent = label;
  b.onclick = onClick;
  return b;
}

/* --- TRIM: pasirink lapus → kirpk žirklėmis --- */
function runTrimGame(data) {
  const cutsNeeded = data.steps || 5;
  let phase = 0;
  let selected = 0;
  let cuts = 0;
  const leaves = 3;

  function renderPick() {
    schBoard.innerHTML = "";
    setStep(1, 3, "Pasirink lapus ant stalo (qb-target stilius)");
    const table = document.createElement("div");
    table.className = "sch-table";
    for (let i = 0; i < leaves; i++) {
      const leaf = document.createElement("button");
      leaf.type = "button";
      leaf.className = "sch-leaf";
      leaf.innerHTML = `<span>🍃</span><small>Lapas ${i + 1}</small>`;
      leaf.onclick = () => {
        if (leaf.classList.contains("picked")) return;
        leaf.classList.add("picked");
        selected += 1;
        if (selected >= leaves) {
          phase = 1;
          renderTrim();
        }
      };
      table.appendChild(leaf);
    }
    schBoard.appendChild(table);
  }

  function renderTrim() {
    schBoard.innerHTML = "";
    setStep(2, 3, "Kirpk žirklėmis — spausk žalius taškus ant lapo");
    const wrap = document.createElement("div");
    wrap.className = "sch-trim-wrap";
    const leaf = document.createElement("div");
    leaf.className = "sch-leaf-big";
    leaf.innerHTML = "<span>🌿</span>";
    wrap.appendChild(leaf);

    const scissors = document.createElement("div");
    scissors.className = "sch-tool";
    scissors.textContent = "✂️ Žirklės";
    wrap.appendChild(scissors);

    const points = document.createElement("div");
    points.className = "sch-trim-points";
    const positions = [
      { top: "18%", left: "42%" },
      { top: "32%", left: "55%" },
      { top: "48%", left: "38%" },
      { top: "62%", left: "52%" },
      { top: "75%", left: "44%" },
    ];
    for (let i = 0; i < cutsNeeded; i++) {
      const p = document.createElement("button");
      p.type = "button";
      p.className = "sch-trim-point";
      const pos = positions[i % positions.length];
      p.style.top = pos.top;
      p.style.left = pos.left;
      p.onclick = () => {
        if (p.classList.contains("done")) return;
        p.classList.add("done");
        cuts += 1;
        if (cuts >= cutsNeeded) {
          phase = 2;
          renderDone();
        }
      };
      points.appendChild(p);
    }
    wrap.appendChild(points);
    schBoard.appendChild(wrap);

    let timeLeft = 12 + (data.difficulty || 1) * 2;
    scheduleTimer = setInterval(() => {
      timeLeft -= 1;
      if (schHint) schHint.textContent = `Kirpk žirklėmis — liko ${timeLeft}s`;
      if (timeLeft <= 0) failSchedule();
    }, 1000);
  }

  function renderDone() {
    if (scheduleTimer) clearInterval(scheduleTimer);
    schBoard.innerHTML = "";
    setStep(3, 3, "Surink apdorotus žiedus");
    const done = document.createElement("div");
    done.className = "sch-done";
    done.innerHTML = "<p>🌸 Žiedai paruošti</p>";
    done.appendChild(
      btn("Baigti", "primary", () => postSchedule(true, { mistakes: Math.max(0, cutsNeeded - cuts) }))
    );
    schBoard.appendChild(done);
  }

  renderPick();
}

/* --- PACK BAG: sverti → į maišelį → užlydinti --- */
function runPackBagGame(data) {
  let step = 1;
  const icon = data.icon || "🌿";

  function renderWeigh() {
    schBoard.innerHTML = "";
    setStep(1, 3, "Padėk produktą ant svarstyklių");
    const row = document.createElement("div");
    row.className = "sch-pack-row";
    row.innerHTML = `
      <div class="sch-scale"><span>⚖️</span><p id="schWeight">0.00 g</p></div>
      <div class="sch-product">${icon}</div>
    `;
    schBoard.appendChild(row);
    schBoard.appendChild(
      btn("Sverti", "primary", () => {
        const w = document.getElementById("schWeight");
        if (w) w.textContent = (1.8 + Math.random() * 0.4).toFixed(2) + " g";
        step = 2;
        setTimeout(renderFill, 500);
      })
    );
  }

  function renderFill() {
    schBoard.innerHTML = "";
    setStep(2, 3, "Paspausk produktą, tada atidarytą maišelį");
    let picked = false;
    const row = document.createElement("div");
    row.className = "sch-pack-row";

    const prod = document.createElement("button");
    prod.type = "button";
    prod.className = "sch-product sch-clickable";
    prod.textContent = icon;
    prod.onclick = () => {
      picked = true;
      prod.classList.add("active");
    };

    const bag = document.createElement("button");
    bag.type = "button";
    bag.className = "sch-bag open";
    bag.innerHTML = "<span>👜</span><small>Atidarytas maišelis</small>";
    bag.onclick = () => {
      if (!picked) {
        if (schHint) schHint.textContent = "Pirma pasirink produktą!";
        return;
      }
      step = 3;
      renderSeal();
    };

    row.appendChild(prod);
    row.appendChild(bag);
    schBoard.appendChild(row);
  }

  function renderSeal() {
    schBoard.innerHTML = "";
    setStep(3, 3, "Užlydink maišelį — spausk 3 kartus");
    let seals = 0;
    const bag = document.createElement("button");
    bag.type = "button";
    bag.className = "sch-bag seal";
    bag.innerHTML = `<span>👜</span><small>Užlydinimas ${seals}/3</small>`;
    bag.onclick = () => {
      seals += 1;
      bag.querySelector("small").textContent = `Užlydinimas ${seals}/3`;
      bag.classList.add("pulse");
      setTimeout(() => bag.classList.remove("pulse"), 200);
      if (seals >= 3) postSchedule(true, { mistakes: 0 });
    };
    schBoard.appendChild(bag);
  }

  renderWeigh();
}

/* --- PACK BOTTLE --- */
function runPackBottleGame(data) {
  let poured = false;
  schBoard.innerHTML = "";
  setStep(1, 2, "Supilk skystį į butelį");
  const row = document.createElement("div");
  row.className = "sch-pack-row";
  const bottle = document.createElement("div");
  bottle.className = "sch-bottle";
  bottle.innerHTML = "<span>🍾</span><div class='sch-fill'></div>";
  row.appendChild(bottle);
  schBoard.appendChild(row);
  schBoard.appendChild(
    btn("Supilti", "primary", () => {
      poured = true;
      bottle.querySelector(".sch-fill").style.height = "72%";
      setStep(2, 2, "Uždaryk kamštį");
      schBoard.innerHTML = "";
      schBoard.appendChild(bottle);
      schBoard.appendChild(btn("Uždaryti kamštį", "primary", () => postSchedule(true)));
    })
  );
}

/* --- DISTILL / COOK: laikyk indikatorių žalioje zonoje --- */
function runGaugeGame(data, label) {
  schBoard.innerHTML = "";
  setStep(1, 1, label || "Laikyk temperatūrą žalioje zonoje ir spausk SPACE");
  const track = document.createElement("div");
  track.className = "sch-gauge-track";
  const zone = document.createElement("div");
  zone.className = "sch-gauge-zone";
  const zoneLeft = 25 + Math.random() * 40;
  zone.style.left = `${zoneLeft}%`;
  const needle = document.createElement("div");
  needle.className = "sch-gauge-needle";
  track.appendChild(zone);
  track.appendChild(needle);
  schBoard.appendChild(track);

  let pos = 10;
  let dir = 1.6;
  let hold = 0;
  const need = 55 + (data.difficulty || 1) * 8;

  const iv = setInterval(() => {
    pos += dir;
    if (pos >= 98) dir = -1.6;
    if (pos <= 2) dir = 1.6;
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
  }, 14000);
}

/* --- CRYSTAL: paspaudimų seka --- */
function runCrystalGame(data) {
  const rounds = 3 + (data.difficulty || 1);
  const keys = ["Q", "W", "E"];
  const seq = [];
  for (let i = 0; i < rounds; i++) seq.push(keys[Math.floor(Math.random() * keys.length)]);
  let idx = 0;
  schBoard.innerHTML = "";
  setStep(1, 1, "Stabilizuok kristalizaciją — spausk rodyklę laiku");
  const seqEl = document.createElement("div");
  seqEl.className = "sch-seq";
  seqEl.textContent = seq.join(" → ");
  schBoard.appendChild(seqEl);
  const keysRow = document.createElement("div");
  keysRow.className = "sch-keys";
  keys.forEach((k) => {
    const b = btn(k, "", () => {
      if (k !== seq[idx]) return failSchedule();
      idx += 1;
      if (idx >= seq.length) postSchedule(true);
    });
    keysRow.appendChild(b);
  });
  schBoard.appendChild(keysRow);
}

/* --- PRESS: tabletės presas --- */
function runPressGame(data) {
  let presses = 0;
  const need = data.steps || 4;
  schBoard.innerHTML = "";
  setStep(1, 1, "Presuok tabletes — spausk svirtį");
  const press = document.createElement("button");
  press.type = "button";
  press.className = "sch-press";
  press.innerHTML = `<span>💊</span><small>Presas ${presses}/${need}</small>`;
  press.onclick = () => {
    presses += 1;
    press.querySelector("small").textContent = `Presas ${presses}/${need}`;
    press.classList.add("pulse");
    setTimeout(() => press.classList.remove("pulse"), 150);
    if (presses >= need) postSchedule(true);
  };
  schBoard.appendChild(press);
}

/* --- WASH: kokaino lapų plovimas --- */
function runWashGame(data) {
  let washed = 0;
  const need = data.steps || 4;
  schBoard.innerHTML = "";
  setStep(1, 2, "Suberk lapus į tirpalą");
  const tub = document.createElement("div");
  tub.className = "sch-tub";
  tub.innerHTML = "<span>🧪</span>";
  for (let i = 0; i < need; i++) {
    const leaf = document.createElement("button");
    leaf.type = "button";
    leaf.className = "sch-wash-leaf";
    leaf.textContent = "🍃";
    leaf.onclick = () => {
      if (leaf.classList.contains("done")) return;
      leaf.classList.add("done");
      washed += 1;
      if (washed >= need) {
        setStep(2, 2, "Maišyk tirpalą");
        schBoard.innerHTML = "";
        schBoard.appendChild(tub);
        schBoard.appendChild(
          btn("Maišyti", "primary", () => postSchedule(true))
        );
      }
    };
    tub.appendChild(leaf);
  }
  schBoard.appendChild(tub);
}

/* --- PLANT: sodinimas su juodu vazonu --- */
function blackPotHtml(label) {
  return `<div class="sch-pot-black" title="Vazonas"><div class="sch-pot-rim"></div><div class="sch-pot-body"></div><small>${label || ""}</small></div>`;
}

function toolCard(icon, label, extraClass) {
  const el = document.createElement("button");
  el.type = "button";
  el.className = `sch-tool-card sch-clickable${extraClass ? " " + extraClass : ""}`;
  el.innerHTML = `<span class="sch-tool-icon">${icon}</span><small>${label}</small>`;
  return el;
}

function runWeedHarvestGame(data) {
  let phase = 0;
  let glovesOn = false;
  let trimmed = 0;
  const need = data.steps || 3;

  function renderGloves() {
    schBoard.innerHTML = "";
    setStep(1, 3, "Užsimaok pirštines");
    const row = document.createElement("div");
    row.className = "sch-plant-row";
    row.appendChild(blackPotHtml("🌿 Brandu"));
    const gloves = toolCard("🧤", "Pirštinės", glovesOn ? "active" : "");
    gloves.onclick = () => {
      glovesOn = true;
      gloves.classList.add("active");
      if (schHint) schHint.textContent = "Gerai — imkis žirklčių";
      setTimeout(() => { phase = 1; renderTrim(); }, 450);
    };
    row.appendChild(gloves);
    const scissors = toolCard("✂️", "Žirklės");
    scissors.style.opacity = "0.45";
    row.appendChild(scissors);
    schBoard.appendChild(row);
  }

  function renderTrim() {
    schBoard.innerHTML = "";
    setStep(2, 3, "Kirpk žirklėmis pažymėtus lapus");
    const wrap = document.createElement("div");
    wrap.className = "sch-trim-wrap";
    wrap.innerHTML = `<div class="sch-leaf-big">🌿</div><div class="sch-tool sch-tool-float">✂️</div>`;
    const points = document.createElement("div");
    points.className = "sch-trim-points";
    const positions = [[38, 28], [62, 34], [48, 58], [70, 52]];
    positions.slice(0, need).forEach(([x, y]) => {
      const p = document.createElement("button");
      p.type = "button";
      p.className = "sch-trim-point";
      p.style.left = `${x}%`;
      p.style.top = `${y}%`;
      p.onclick = () => {
        if (p.classList.contains("done")) return;
        p.classList.add("done");
        trimmed += 1;
        if (trimmed >= need) {
          phase = 2;
          renderScale();
        } else if (schHint) {
          schHint.textContent = `${trimmed}/${need} lapų`;
        }
      };
      points.appendChild(p);
    });
    wrap.appendChild(points);
    schBoard.appendChild(wrap);
  }

  function renderScale() {
    schBoard.innerHTML = "";
    setStep(3, 3, "Pasvęsk derlių svarstyklėmis");
    const row = document.createElement("div");
    row.className = "sch-pack-row";
    const pile = document.createElement("button");
    pile.type = "button";
    pile.className = "sch-product sch-clickable";
    pile.innerHTML = "<span>🌿</span><small>Lapai</small>";
    const scale = document.createElement("button");
    scale.type = "button";
    scale.className = "sch-scale sch-clickable";
    scale.innerHTML = "<span>⚖️</span><p>Svarstyklės</p>";
    let onScale = false;
    pile.onclick = () => {
      onScale = true;
      pile.classList.add("active");
      scale.classList.add("pulse");
      if (schHint) schHint.textContent = "Spausk svarstykles";
    };
    scale.onclick = () => {
      if (!onScale) return;
      postSchedule(true);
    };
    row.appendChild(pile);
    row.appendChild(scale);
    schBoard.appendChild(row);
  }

  renderGloves();
}

function runPlantGame(data) {
  let phase = 0;
  let soilClicks = 0;
  let seedPlaced = false;
  let glovesReady = false;
  let waters = 0;
  const watersNeeded = 2;
  const soilNeeded = 4;

  function renderSoil() {
    schBoard.innerHTML = "";
    setStep(1, 4, "Užpildyk juodą vazoną žeme");
    const row = document.createElement("div");
    row.className = "sch-plant-row";
    const pile = toolCard("🪨", "Žemė");
    const potWrap = document.createElement("div");
    potWrap.innerHTML = blackPotHtml(`Žemė ${soilClicks}/${soilNeeded}`);
    const fill = document.createElement("div");
    fill.className = "sch-pot-soil-fill";
    fill.style.height = `${(soilClicks / soilNeeded) * 72}%`;
    potWrap.querySelector(".sch-pot-body").appendChild(fill);
    pile.onclick = () => {
      soilClicks += 1;
      fill.style.height = `${(soilClicks / soilNeeded) * 72}%`;
      potWrap.querySelector("small").textContent = `Žemė ${soilClicks}/${soilNeeded}`;
      if (soilClicks >= soilNeeded) {
        phase = 1;
        renderTools();
      }
    };
    row.appendChild(pile);
    row.appendChild(potWrap);
    schBoard.appendChild(row);
  }

  function renderTools() {
    schBoard.innerHTML = "";
    setStep(2, 4, "Pasiruošk: pirštinės → sėkla → vazonas");
    const row = document.createElement("div");
    row.className = "sch-plant-row";
    const gloves = toolCard("🧤", "Pirštinės", glovesReady ? "active" : "");
    const seed = toolCard("🌰", "Sėkla", seedPlaced ? "active" : "");
    const potBtn = toolCard("🪴", "Vazonas");
    potBtn.className = "sch-tool-card sch-clickable";
    potBtn.innerHTML = blackPotHtml("Įdėk čia");
    gloves.onclick = () => {
      glovesReady = true;
      gloves.classList.add("active");
    };
    seed.onclick = () => {
      if (!glovesReady) {
        if (schHint) schHint.textContent = "Pirma užsimaok pirštines";
        return;
      }
      seedPlaced = true;
      seed.classList.add("active");
      if (schHint) schHint.textContent = "Spausk vazoną";
    };
    potBtn.onclick = () => {
      if (!seedPlaced) return;
      phase = 2;
      renderWater();
    };
    row.appendChild(gloves);
    row.appendChild(seed);
    row.appendChild(potBtn);
    schBoard.appendChild(row);
  }

  function renderWater() {
    schBoard.innerHTML = "";
    setStep(3, 4, "Laistytuvas — spausk žalioje zonoje");
    const wrap = document.createElement("div");
    wrap.className = "sch-water-wrap";
    const pot = document.createElement("div");
    pot.innerHTML = blackPotHtml("🌱 Sėkla");
    wrap.appendChild(pot.firstChild);

    const can = toolCard("🚿", "Laistytuvas");
    wrap.appendChild(can);

    const track = document.createElement("div");
    track.className = "sch-gauge-track";
    const zone = document.createElement("div");
    zone.className = "sch-gauge-zone";
    zone.style.left = "36%";
    const needle = document.createElement("div");
    needle.className = "sch-gauge-needle";
    needle.style.left = "0%";
    track.appendChild(zone);
    track.appendChild(needle);
    wrap.appendChild(track);

    const waterBtn = btn("💧 Laistyti", "primary", () => {
      const pos = parseFloat(needle.style.left) || 0;
      if (pos >= 32 && pos <= 64) {
        waters += 1;
        if (waters >= watersNeeded) {
          phase = 3;
          renderCover();
        } else if (schHint) schHint.textContent = `Gerai! ${waters}/${watersNeeded}`;
      } else {
        failSchedule();
      }
    });
    wrap.appendChild(waterBtn);
    schBoard.appendChild(wrap);

    let dir = 1;
    let pos = 8;
    if (scheduleTimer) clearInterval(scheduleTimer);
    scheduleTimer = setInterval(() => {
      pos += dir * (3 + (data.difficulty || 1));
      if (pos >= 92) dir = -1;
      if (pos <= 4) dir = 1;
      needle.style.left = `${pos}%`;
    }, 70);
  }

  function renderCover() {
    if (scheduleTimer) clearInterval(scheduleTimer);
    schBoard.innerHTML = "";
    setStep(4, 4, "Uždenk sėklą plonu žemės sluoksniu");
    const done = document.createElement("div");
    done.className = "sch-done";
    done.innerHTML = `<div class="sch-plant-row">${blackPotHtml("Paruošta")}</div>`;
    done.appendChild(btn("Užbaigti sodinimą", "primary", () => postSchedule(true)));
    schBoard.appendChild(done);
  }

  renderSoil();
}

/* --- WEED DRY: 2 lapai → džiovinimas → 1 žiedas --- */
function runWeedDryGame(data) {
  let hung = 0;
  let drySec = 0;
  const needDry = 5;

  function renderHang() {
    schBoard.innerHTML = "";
    setStep(1, 3, "Pakabink 2 lapus ant džiovinimo stovo");
    const rack = document.createElement("div");
    rack.className = "sch-dry-rack";
    rack.innerHTML = `
      <div class="sch-dry-frame"></div>
      <div class="sch-dry-hooks">
        <button type="button" class="sch-dry-hook" data-i="0"><span>🍃</span><small>Lapas 1</small></button>
        <button type="button" class="sch-dry-hook" data-i="1"><span>🍃</span><small>Lapas 2</small></button>
      </div>
      <div class="sch-dry-tray"><small>Surinkti lapai: <b id="schHung">0</b>/2</small></div>
    `;
    schBoard.appendChild(rack);
    rack.querySelectorAll(".sch-dry-hook").forEach((hook) => {
      hook.onclick = () => {
        if (hook.classList.contains("hung")) return;
        hook.classList.add("hung");
        hung += 1;
        const c = document.getElementById("schHung");
        if (c) c.textContent = String(hung);
        if (hung >= 2) setTimeout(renderDry, 450);
      };
    });
  }

  function renderDry() {
    schBoard.innerHTML = "";
    setStep(2, 3, "Reguliuok oro srautą — laikyk indikatorių žalioje zonoje");
    const wrap = document.createElement("div");
    wrap.className = "sch-dry-control";
    wrap.innerHTML = `
      <div class="sch-dry-fan">💨 Oro srautas</div>
      <div class="sch-gauge-track"><div class="sch-gauge-zone" style="left:38%"></div><div class="sch-gauge-needle" id="schDryNeedle"></div></div>
      <div class="sch-dry-meter">Džiovinimas: <b id="schDryPct">0</b>%</div>
      <div class="sch-dry-leaves-preview">🍃🍃 → 🌸</div>
    `;
    schBoard.appendChild(wrap);
    schBoard.appendChild(btn("Mažinti", "", () => adjust(-4)));
    schBoard.appendChild(btn("Didinti", "primary", () => adjust(4)));

    let pos = 22;
    let vel = 2.4;
    const needle = document.getElementById("schDryNeedle");
    const pctEl = document.getElementById("schDryPct");

    function adjust(delta) {
      vel = Math.max(-5, Math.min(5, vel + delta * 0.35));
    }

    if (scheduleTimer) clearInterval(scheduleTimer);
    scheduleTimer = setInterval(() => {
      pos += vel;
      if (pos <= 4 || pos >= 92) vel *= -1;
      pos = Math.max(2, Math.min(96, pos));
      if (needle) needle.style.left = `${pos}%`;
      if (pos >= 38 && pos <= 60) {
        drySec += 0.1;
        const pct = Math.min(100, Math.floor((drySec / needDry) * 100));
        if (pctEl) pctEl.textContent = String(pct);
        if (drySec >= needDry) {
          clearInterval(scheduleTimer);
          scheduleTimer = null;
          renderCollect();
        }
      }
      if (schHint) schHint.textContent = `Laikyk žalią zoną — progresas ${Math.min(100, Math.floor((drySec / needDry) * 100))}%`;
    }, 100);
  }

  function renderCollect() {
    if (scheduleTimer) clearInterval(scheduleTimer);
    schBoard.innerHTML = "";
    setStep(3, 3, "Surink išdžiovintą žiedą");
    const done = document.createElement("div");
    done.className = "sch-done sch-dry-done";
    done.innerHTML = `
      <div class="sch-dry-result">🌸</div>
      <p>Išdžiovintas kanapių žiedas</p>
    `;
    done.appendChild(btn("Surinkti žiedą", "primary", () => postSchedule(true)));
    schBoard.appendChild(done);
  }

  renderHang();
}

/* --- WEED PACK: 1 žiedas → svarstyklės → maišelis → užlydinimas --- */
function runWeedPackGame(data) {
  function renderWeigh() {
    schBoard.innerHTML = "";
    setStep(1, 3, "Padėk išdžiovintą žiedą ant svarstyklių");
    const row = document.createElement("div");
    row.className = "sch-pack-row";
    row.innerHTML = `
      <div class="sch-weed-scale">
        <span>⚖️</span>
        <p id="schPackWeight">0.00 g</p>
        <small>Digital scale</small>
      </div>
      <button type="button" class="sch-weed-bud sch-clickable" id="schPackBud">🌸</button>
    `;
    schBoard.appendChild(row);
    const bud = document.getElementById("schPackBud");
    if (bud) {
      bud.onclick = () => {
        bud.classList.add("active");
        const w = document.getElementById("schPackWeight");
        if (w) w.textContent = "1.00 g";
        setTimeout(renderBag, 500);
      };
    }
  }

  function renderBag() {
    schBoard.innerHTML = "";
    setStep(2, 3, "Perkelk žiedą į maišelį");
    let picked = false;
    const row = document.createElement("div");
    row.className = "sch-pack-row";

    const bud = document.createElement("button");
    bud.type = "button";
    bud.className = "sch-weed-bud sch-clickable";
    bud.textContent = "🌸";
    bud.onclick = () => {
      picked = true;
      bud.classList.add("active");
    };

    const bag = document.createElement("button");
    bag.type = "button";
    bag.className = "sch-weed-mylar";
    bag.innerHTML = "<span>📦</span><small>Mylar maišelis</small>";
    bag.onclick = () => {
      if (!picked) {
        if (schHint) schHint.textContent = "Pirma pasirink žiedą!";
        return;
      }
      bag.classList.add("filled");
      setTimeout(renderSeal, 400);
    };

    row.appendChild(bud);
    row.appendChild(bag);
    schBoard.appendChild(row);
  }

  function renderSeal() {
    schBoard.innerHTML = "";
    setStep(3, 3, "Užlydink maišelį — pritrauk slankiklį per 3 zonas");
    let seals = 0;
    const wrap = document.createElement("div");
    wrap.className = "sch-seal-wrap";
    wrap.innerHTML = `
      <div class="sch-weed-mylar filled seal-mode"><span>📦</span><small>Paruošta užlydinimui</small></div>
      <div class="sch-seal-bar">
        <button type="button" class="sch-seal-zone" data-i="0"></button>
        <button type="button" class="sch-seal-zone" data-i="1"></button>
        <button type="button" class="sch-seal-zone" data-i="2"></button>
      </div>
      <p class="sch-seal-label">Užlydinimas <b id="schSealCnt">0</b>/3</p>
    `;
    schBoard.appendChild(wrap);
    wrap.querySelectorAll(".sch-seal-zone").forEach((zone) => {
      zone.onclick = () => {
        if (zone.classList.contains("done")) return;
        zone.classList.add("done");
        seals += 1;
        const c = document.getElementById("schSealCnt");
        if (c) c.textContent = String(seals);
        if (seals >= 3) {
          const done = document.createElement("div");
          done.className = "sch-done";
          done.innerHTML = "<p>✅ Supakuota žolė paruošta</p>";
          done.appendChild(btn("Baigti", "primary", () => postSchedule(true)));
          schBoard.appendChild(done);
        }
      };
    });
  }

  renderWeigh();
}

function runScheduleGame(data) {
  if (!mgSchedule) return;
  scheduleActive = true;
  if (schTitle) schTitle.textContent = data.title || "Gamyba";
  mgSchedule.classList.remove("hidden");

  const mode = data.mode || "trim";
  if (mode === "trim") return runTrimGame(data);
  if (mode === "pack_bag" || mode === "pack_brick") return runPackBagGame(data);
  if (mode === "pack_bottle") return runPackBottleGame(data);
  if (mode === "distill") return runGaugeGame(data, "Distiliuok — laikyk temperatūrą žalioje zonoje");
  if (mode === "cook") return runGaugeGame(data, "Virimas — kontroliuok temperatūrą");
  if (mode === "crystal") return runCrystalGame(data);
  if (mode === "press") return runPressGame(data);
  if (mode === "wash") return runWashGame(data);
  if (mode === "mix") return runGaugeGame(data, "Maišyk komponentus");
  if (mode === "plant") return runPlantGame(data);
  if (mode === "weed_harvest") return runWeedHarvestGame(data);
  if (mode === "weed_dry") return runWeedDryGame(data);
  if (mode === "weed_pack") return runWeedPackGame(data);
  runTrimGame(data);
}

window.addEventListener("message", (e) => {
  if (e.data && e.data.action === "minigameSchedule") {
    runScheduleGame(e.data.data || {});
  }
});

document.addEventListener("keydown", (e) => {
  if (e.key === "Escape" && scheduleActive) {
    failSchedule();
  }
});
