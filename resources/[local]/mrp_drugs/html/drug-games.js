/* Unikalūs narkotikų mini-žaidimai — modernus MRP UI (minigame-ui.js) */
window.DrugGameModes = (() => {
  const U = () => window.MiniGameUI;
  const modes = {};

  const SPOTS = {
    scrape: [
      { top: '18%', left: '38%' }, { top: '32%', left: '52%' },
      { top: '48%', left: '36%' }, { top: '62%', left: '50%' }, { top: '44%', left: '64%' },
    ],
    brush: [
      { top: '22%', left: '34%' }, { top: '38%', left: '54%' },
      { top: '52%', left: '40%' }, { top: '46%', left: '26%' }, { top: '64%', left: '58%' },
    ],
  };

  /* ── L1 THC ── */
  modes.thc_scrape = (data) => {
    setStep(1, 2, 'Surink techninės kanapės trim masę');
    U().clickBoard({
      title: 'Pažymėk aktyvius taškus ant trim medžiagos',
      total: data.steps || 4,
      icon: '🧪',
      positions: SPOTS.scrape,
      onComplete: () => {
        setStep(2, 2, 'Surink distiliatą į indą');
        const root = U().scene('mg-scene-thc');
        root.append(U().iconHero('🧪', 'THC distiliatas paruoštas'));
        root.append(U().actionBtn('Surinkti distiliatą', {
          icon: '🫙', large: true, variant: 'primary',
          onClick: () => postSchedule(true, { score: 88 }),
        }));
        U().mount(root);
      },
    });
  };

  modes.thc_cartridge = (data) => {
    setStep(1, 1, 'Pildyk vape kasetę — stabilizuok slėgį');
    U().gaugeHold({ label: 'Kasetės pildymas', speed: 1.3, need: 48, hintEl: schHint, onSuccess: () => postSchedule(true) });
  };

  /* ── L1 Alkoholis ── */
  modes.moonshine_still = (data) => {
    setStep(1, 1, 'Distiliatorius — kontroliuok temperatūrą');
    U().gaugeHold({ label: 'Distiliacija', speed: 1.2, need: 60, hintEl: schHint, onSuccess: () => postSchedule(true) });
  };

  modes.moonshine_jar = (data) => {
    setStep(1, 3, 'Supilk samogoną į stiklainį');
    U().vesselFill({
      icon: '🫙', label: 'Supilti', steps: 1,
      onComplete: () => {
        setStep(2, 3, 'Užkorkuok stiklainį');
        U().multiTap({ icon: '🍾', label: 'Užkorkuoti', need: 3, onDone: () => postSchedule(true) });
      },
    });
  };

  /* ── L1 Vape ── */
  modes.vape_blend = (data) => {
    const target = 35 + Math.floor(Math.random() * 30);
    setStep(1, 2, 'Sulygink skysčio mišinio spalvas');
    U().sliderBlend({
      target,
      onConfirm: () => { setStep(2, 2, 'Mišinys paruoštas'); postSchedule(true); },
    });
  };

  modes.vape_dropper = (data) => {
    const need = data.steps || 3;
    setStep(1, need, 'Lašink tiksliai į buteliuką');
    U().vesselFill({
      icon: '🧴', label: 'Lašas', steps: need,
      onStep: (step, total) => { if (schHint) schHint.textContent = `Lašai ${step}/${total}`; },
      onComplete: () => postSchedule(true),
    });
  };

  /* ── L2 Heroinas ── */
  modes.heroin_cook = (data) => {
    setStep(1, 2, 'Faza 1 — kaitink tirpalą');
    U().gaugeHold({
      label: 'Kaitinimas', speed: 1.5, need: 50, hintEl: schHint,
      onSuccess: () => {
        setStep(2, 2, 'Faza 2 — maišyk mentoliu');
        U().multiTap({ icon: '⚗️', label: 'Maišyti', need: 4, onDone: () => postSchedule(true) });
      },
    });
  };

  modes.heroin_fold = (data) => {
    const need = data.steps || 3;
    setStep(1, need + 1, 'Sulankstyk foliją su produktu');
    U().foilFold({
      need,
      onFolded: () => {
        setStep(need, need + 1, 'Užlydink maišelį');
        U().multiTap({ icon: '👜', label: 'Užlydinti', need: 3, onDone: () => postSchedule(true) });
      },
    });
  };

  /* ── L2 Metas ── */
  modes.meth_crush_pack = (data) => {
    setStep(1, 3, 'Sutraišk kristalus');
    U().multiTap({
      icon: '🔨', label: 'Sutraiškyti', need: 4,
      onDone: () => {
        setStep(2, 3, 'Sverti ir supakuoti');
        if (typeof runPackBagGame === 'function') runPackBagGame({ ...data, icon: data.icon || '❄️' });
        else postSchedule(true);
      },
    });
  };

  modes.meth_crystal = (data) => {
    if (typeof runCrystalGame === 'function') runCrystalGame(data);
    else failSchedule();
  };

  /* ── L2 Tabletės ── */
  modes.pills_press = (data) => {
    if (typeof runPressGame === 'function') runPressGame(data);
    else failSchedule();
  };

  modes.pills_blister = (data) => {
    const slots = data.steps || 3;
    setStep(1, 2, 'Įspausk tabletes į blisterį');
    U().blisterPack(slots, () => {
      setStep(2, 2, 'Užlenk apsauginę plėvelę');
      const root = U().scene('mg-scene-pills');
      root.append(U().actionBtn('Užlenkti plėvelę', {
        icon: '💊', variant: 'primary', large: true,
        onClick: () => postSchedule(true),
      }));
      U().mount(root);
    });
  };

  /* ── L2 Grybai ── */
  modes.mushroom_brush = (data) => {
    setStep(1, 1, 'Nuvalyk grybą');
    U().clickBoard({
      title: 'Nušveisk purvą nuo grybo',
      total: data.steps || 4,
      icon: '🍄',
      positions: SPOTS.brush,
      onComplete: () => postSchedule(true, { score: 85 }),
    });
  };

  modes.mushroom_jar = (data) => {
    setStep(1, 3, 'Supilk džiovintus grybus');
    U().vesselFill({
      icon: '🫙', label: 'Supilti', steps: 1,
      onComplete: () => {
        setStep(2, 3, 'Užsukuvok dangtelį');
        U().multiTap({ icon: '🔩', label: 'Užsukti', need: 3, onDone: () => postSchedule(true) });
      },
    });
  };

  modes.mushroom_harvest = (data) => {
    setStep(1, 1, 'Surink grybus — spausk kai pasirodo');
    U().spawnCatcher({
      icon: '🍄', need: data.steps || 5, spawnInterval: 420,
      onComplete: () => postSchedule(true, { score: 90 }),
    });
  };

  /* ── L3 Kokainas ── */
  modes.coca_harvest = (data) => {
    setStep(1, 1, 'Nuimk lapus nuo šakos');
    U().stripRow({
      icon: '🍃', need: data.steps || 5,
      onComplete: () => postSchedule(true, { score: 88 }),
    });
  };

  modes.cocaine_wash = (data) => {
    if (typeof runWashGame === 'function') runWashGame(data);
    else failSchedule();
  };

  modes.cocaine_brick = (data) => {
    setStep(1, 3, 'Presuok masę į bloką');
    U().multiTap({
      icon: '🧱', label: 'Presuoti', need: 4,
      onDone: () => {
        setStep(2, 3, 'Apvyniok plėvele');
        U().multiTap({ icon: '📦', label: 'Apvynioti', need: 3, onDone: () => postSchedule(true) });
      },
    });
  };

  /* ── L3 Amfetaminas (pack) ── */
  modes.amp_stamp = (data) => {
    setStep(1, 3, 'Užlydink maišelį');
    U().multiTap({
      icon: '👜', label: 'Užlydinti', need: 2,
      onDone: () => {
        setStep(2, 3, 'Antspauduok maišelį');
        const root = U().scene('mg-scene-amp');
        root.append(U().iconHero('⚡', 'Galutinis antspaudas'));
        root.append(U().actionBtn('Antspaudas', {
          icon: '⚡', large: true, variant: 'primary',
          onClick: () => postSchedule(true),
        }));
        U().mount(root);
      },
    });
  };

  return modes;
})();
