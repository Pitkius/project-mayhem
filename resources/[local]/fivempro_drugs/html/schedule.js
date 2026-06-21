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

/* --- PLANT: Schedule-1 sodinimas — žemė → sėkla → laistymas → uždenk --- */
function runPlantGame(data) {
  let phase = 0;
  let soilClicks = 0;
  let seedPlaced = false;
  let waters = 0;
  const watersNeeded = 3;
  const soilNeeded = 4;

  function renderSoil() {
    schBoard.innerHTML = "";
    setStep(1, 4, "Užpildyk vazoną žeme — spausk krūvą");
    const row = document.createElement("div");
    row.className = "sch-plant-row";
    const pile = document.createElement("button");
    pile.type = "button";
    pile.className = "sch-soil-pile sch-clickable";
    pile.innerHTML = "<span>🪨</span><small>Žemė</small>";
    const pot = document.createElement("div");
    pot.className = "sch-pot";
    pot.innerHTML = `<span>🪴</span><div class="sch-pot-fill" style="height:${(soilClicks / soilNeeded) * 100}%"></div><small>Vazonas ${soilClicks}/${soilNeeded}</small>`;
    pile.onclick = () => {
      soilClicks += 1;
      pot.querySelector(".sch-pot-fill").style.height = `${(soilClicks / soilNeeded) * 100}%`;
      pot.querySelector("small").textContent = `Vazonas ${soilClicks}/${soilNeeded}`;
      if (soilClicks >= soilNeeded) {
        phase = 1;
        renderSeed();
      }
    };
    row.appendChild(pile);
    row.appendChild(pot);
    schBoard.appendChild(row);
  }

  function renderSeed() {
    schBoard.innerHTML = "";
    setStep(2, 4, "Paspausk sėklą, tada vazoną");
    const row = document.createElement("div");
    row.className = "sch-plant-row";
    const seed = document.createElement("button");
    seed.type = "button";
    seed.className = `sch-seed sch-clickable${seedPlaced ? " active" : ""}`;
    seed.innerHTML = "<span>🌰</span><small>Sėkla</small>";
    const pot = document.createElement("button");
    pot.type = "button";
    pot.className = "sch-pot sch-clickable";
    pot.innerHTML = `<span>🪴</span><small>${seedPlaced ? "Įdėk čia" : "Pirma pasirink sėklą"}</small>`;
    seed.onclick = () => {
      seedPlaced = true;
      seed.classList.add("active");
      pot.querySelector("small").textContent = "Spausk vazoną";
    };
    pot.onclick = () => {
      if (!seedPlaced) return;
      phase = 2;
      renderWater();
    };
    row.appendChild(seed);
    row.appendChild(pot);
    schBoard.appendChild(row);
  }

  function renderWater() {
    schBoard.innerHTML = "";
    setStep(3, 4, "Laistyklė — spausk, kai indikatorius žalias");
    const wrap = document.createElement("div");
    wrap.className = "sch-water-wrap";
    const pot = document.createElement("div");
    pot.className = "sch-pot";
    pot.innerHTML = "<span>🪴🌱</span>";
    wrap.appendChild(pot);

    const track = document.createElement("div");
    track.className = "sch-gauge-track";
    const zone = document.createElement("div");
    zone.className = "sch-gauge-zone";
    zone.style.left = "38%";
    const needle = document.createElement("div");
    needle.className = "sch-gauge-needle";
    needle.style.left = "0%";
    track.appendChild(zone);
    track.appendChild(needle);
    wrap.appendChild(track);

    const waterBtn = btn("💧 Laistyti", "primary", () => {
      const pos = parseFloat(needle.style.left) || 0;
      if (pos >= 34 && pos <= 62) {
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
    let pos = 10;
    if (scheduleTimer) clearInterval(scheduleTimer);
    scheduleTimer = setInterval(() => {
      pos += dir * (4 + (data.difficulty || 1));
      if (pos >= 92) dir = -1;
      if (pos <= 4) dir = 1;
      needle.style.left = `${pos}%`;
    }, 80);
  }

  function renderCover() {
    if (scheduleTimer) clearInterval(scheduleTimer);
    schBoard.innerHTML = "";
    setStep(4, 4, "Uždenk sėklą plonu žemės sluoksniu");
    const done = document.createElement("div");
    done.className = "sch-done";
    done.innerHTML = "<p>🌱 Paruošta sodinimui</p>";
    done.appendChild(btn("Uždenk žeme", "primary", () => postSchedule(true)));
    schBoard.appendChild(done);
  }

  renderSoil();
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
