/* Schedule-1 stiliaus narkotikų mini-žaidimai — kiekviena rūšis unikali */
window.DrugGameModes = (() => {
  const U = () => window.MiniGameUI;
  const modes = {};
  const win = (extra) => postSchedule(true, extra || { score: 88 });
  const fail = () => failSchedule();

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

  function finishSuccess(msg) {
    U().successScreen(msg || 'Etapas baigtas', () => win({ score: 92 }));
  }

  /* ═══ L1 THC ═══ */
  modes.thc_scrape = (data) => {
    const steps = data.steps || 4;
    setStep(1, 3, 'Paruošk trim medžiagą');
    U().scrapeTrim({
      toolIcon: '✂️',
      targetIcon: '🌿',
      cuts: steps,
      positions: SPOTS.scrape,
      onComplete: () => {
        setStep(2, 3, 'Surink distiliatą');
        U().clickBoard({
          title: 'Pažymėk aktyvius taškus ant masės',
          total: steps,
          icon: '🧪',
          positions: SPOTS.scrape,
          onComplete: () => {
            setStep(3, 3, 'Stabilizuok distiliatą');
            U().gaugeHold({
              label: 'Distiliacija',
              speed: 1.25,
              need: 48,
              hintEl: schHint,
              onSuccess: () => finishSuccess('THC distiliatas paruoštas'),
              onFail: fail,
            });
          },
        });
      },
    });
  };

  modes.thc_cartridge = (data) => {
    setStep(1, 2, 'Užpildyk kasetę — laikyk slėgį');
    U().gaugeHold({
      label: 'Kasetės pildymas',
      speed: 1.35,
      need: 50,
      hintEl: schHint,
      onSuccess: () => {
        setStep(2, 2, 'Užsandarink kasetę');
        U().sealZones({ need: 2, onDone: () => win({ score: 90 }) });
      },
      onFail: fail,
    });
  };

  /* ═══ L1 Alkoholis ═══ */
  modes.moonshine_still = (data) => {
    setStep(1, 2, 'Kaitink distiliatorių');
    U().stillGauge({
      label: 'Samagono distiliacija',
      speed: 1.15,
      need: 58,
      hintEl: schHint,
      onSuccess: () => {
        setStep(2, 2, 'Surink distiliatą');
        U().pourHold({
          label: 'Supilti į indą',
          target: 100,
          icon: '🥃',
          hintEl: schHint,
          onSuccess: () => win({ score: 86 }),
          onFail: fail,
        });
      },
      onFail: fail,
    });
  };

  modes.moonshine_jar = (data) => {
    setStep(1, 3, 'Supilk į stiklainį');
    U().pourHold({
      label: 'Pilti samagoną',
      target: 100,
      icon: '🫙',
      hintEl: schHint,
      onSuccess: () => {
        setStep(2, 3, 'Užkorkuok');
        U().multiTap({
          icon: '🍾',
          label: 'Užsukti kamštį',
          need: 3,
          onDone: () => {
            setStep(3, 3, 'Užlydink apsaugą');
            U().sealZones({ need: 2, onDone: () => win({ score: 88 }) });
          },
        });
      },
      onFail: fail,
    });
  };

  /* ═══ L1 Vape ═══ */
  modes.vape_blend = (data) => {
    const target = 35 + Math.floor(Math.random() * 30);
    setStep(1, 2, 'Sulygink skysčio mišinį');
    U().sliderBlend({
      target,
      onConfirm: () => {
        setStep(2, 2, 'Patikrink mišinį');
        U().gaugeHold({
          label: 'Mišinio stabilizacija',
          speed: 1.2,
          need: 40,
          hintEl: schHint,
          onSuccess: () => win({ score: 85 }),
          onFail: fail,
        });
      },
    });
  };

  modes.vape_dropper = (data) => {
    const need = data.steps || 3;
    setStep(1, need + 1, 'Lašink tiksliai į buteliuką');
    U().timedDrops({
      need,
      icon: '💧',
      onComplete: () => {
        setStep(2, need + 1, 'Užsandarink buteliuką');
        U().sealZones({ need: 2, onDone: () => win({ score: 87 }) });
      },
      onFail: fail,
    });
  };

  /* ═══ L2 Heroinas ═══ */
  modes.heroin_cook = (data) => {
    setStep(1, 3, 'Kaitink tirpalą');
    U().gaugeHold({
      label: 'Kaitinimas',
      speed: 1.55,
      need: 52,
      hintEl: schHint,
      onSuccess: () => {
        setStep(2, 3, 'Maišyk su mentoliu');
        U().multiTap({ icon: '⚗️', label: 'Maišyti', need: 4, onDone: () => {
          setStep(3, 3, 'Stabilizuok redukciją');
          U().keySequence({
            keys: ['W', 'A', 'S', 'D'],
            rounds: 3,
            onSuccess: () => win({ score: 84 }),
            onFail: fail,
          });
        }});
      },
      onFail: fail,
    });
  };

  modes.heroin_fold = (data) => {
    const need = data.steps || 3;
    setStep(1, need + 1, 'Sulankstyk foliją');
    U().foilFold({
      need,
      onFolded: () => {
        setStep(2, need + 1, 'Užlydink maišelį');
        U().sealZones({ need: 3, onDone: () => win({ score: 86 }) });
      },
    });
  };

  /* ═══ L2 Metas ═══ */
  modes.meth_crystal = (data) => {
    setStep(1, 3, 'Kristalizacijos procesas');
    U().crystalPipeline({
      difficulty: data.difficulty || 2,
      hintEl: schHint,
      onSuccess: () => finishSuccess('Kristalai suformuoti'),
      onFail: fail,
    });
  };

  modes.meth_crush_pack = (data) => {
    setStep(1, 3, 'Sutraišk kristalus');
    U().multiTap({
      icon: '🔨',
      label: 'Sutraiškyti',
      need: 4,
      onDone: () => {
        setStep(2, 3, 'Sverti ir supakuoti');
        U().packBagFlow({
          icon: data.icon || '❄️',
          onDone: () => win({ score: 90 }),
        });
      },
    });
  };

  /* ═══ L2 Tabletės ═══ */
  modes.pills_press = (data) => {
    const need = data.steps || 4;
    setStep(1, 2, 'Presuok tabletes — tikslus ritmas');
    U().pressRhythm({
      need,
      icon: '💊',
      label: 'Presuoti',
      onDone: () => {
        setStep(2, 2, 'Patikrink tabletes');
        U().multiTap({ icon: '💊', label: 'Kontrolė', need: 2, onDone: () => win({ score: 88 }) });
      },
      onFail: fail,
    });
  };

  modes.pills_blister = (data) => {
    const slots = data.steps || 3;
    setStep(1, 2, 'Įspausk tabletes į blisterį');
    U().blisterPack(slots, () => {
      setStep(2, 2, 'Užlenk apsauginę plėvelę');
      U().sealZones({ need: 3, onDone: () => win({ score: 89 }) });
    });
  };

  /* ═══ L2 Grybai ═══ */
  modes.mushroom_brush = (data) => {
    setStep(1, 2, 'Nuvalyk grybus');
    U().clickBoard({
      title: 'Nušveisk purvą nuo grybo',
      total: data.steps || 4,
      icon: '🍄',
      positions: SPOTS.brush,
      onComplete: () => {
        setStep(2, 2, 'Paruošk džiovinimui');
        U().dryRack({
          need: 3,
          icon: '🍄',
          onComplete: () => win({ score: 85 }),
        });
      },
    });
  };

  modes.mushroom_jar = (data) => {
    setStep(1, 3, 'Supilk į stiklainį');
    U().pourHold({
      label: 'Supilti grybus',
      target: 95,
      icon: '🫙',
      hintEl: schHint,
      onSuccess: () => {
        setStep(2, 3, 'Užsukuvok dangtelį');
        U().multiTap({ icon: '🔩', label: 'Užsukti', need: 3, onDone: () => {
          setStep(3, 3, 'Užsandarink');
          U().sealZones({ need: 2, onDone: () => win({ score: 87 }) });
        }});
      },
      onFail: fail,
    });
  };

  modes.mushroom_harvest = (data) => {
    setStep(1, 1, 'Surink grybus laiku');
    U().spawnCatcher({
      icon: '🍄',
      need: data.steps || 5,
      spawnInterval: 400,
      onComplete: () => win({ score: 90 }),
    });
  };

  /* ═══ L3 Kokainas ═══ */
  modes.coca_harvest = (data) => {
    setStep(1, 1, 'Nuimk lapus nuo šakos');
    U().stripRow({
      icon: '🍃',
      need: data.steps || 5,
      onComplete: () => win({ score: 88 }),
    });
  };

  modes.cocaine_wash = (data) => {
    setStep(1, 2, 'Cheminis plovimas');
    U().chemistryWash({
      need: data.steps || 4,
      hintEl: schHint,
      onDone: () => win({ score: 86 }),
    });
  };

  modes.cocaine_brick = (data) => {
    setStep(1, 3, 'Presuok į bloką');
    U().pressRhythm({
      need: 4,
      icon: '🧱',
      label: 'Presuoti',
      onDone: () => {
        setStep(2, 3, 'Apvyniok plėvele');
        U().multiTap({ icon: '📦', label: 'Apvynioti', need: 3, onDone: () => {
          setStep(3, 3, 'Užlydink siuntą');
          U().sealZones({ need: 3, onDone: () => win({ score: 91 }) });
        }});
      },
      onFail: fail,
    });
  };

  /* ═══ L3 Amfetaminas (pack) ═══ */
  modes.amp_stamp = (data) => {
    setStep(1, 3, 'Užlydink maišelį');
    U().multiTap({
      icon: '👜',
      label: 'Užlydinti',
      need: 2,
      onDone: () => {
        setStep(2, 3, 'Antspauduok');
        U().pressRhythm({
          need: 3,
          icon: '⚡',
          label: 'Antspaudas',
          onDone: () => {
            setStep(3, 3, 'Kontrolinis ženklas');
            U().sealZones({ need: 2, onDone: () => win({ score: 90 }) });
          },
          onFail: fail,
        });
      },
    });
  };

  /* ═══ Kanapės — grow / dry / pack (Schedule-1 workbench iš schedule.js) ═══ */
  const weed = (fn) => (data) => {
    if (typeof fn === 'function') return fn(data);
    fail();
  };
  modes.weed_soil = weed(typeof runWeedSoilGame === 'function' ? runWeedSoilGame : null);
  modes.weed_seed = weed(typeof runWeedSeedGame === 'function' ? runWeedSeedGame : null);
  modes.weed_water = weed(typeof runWeedWaterGame === 'function' ? runWeedWaterGame : null);
  modes.weed_harvest = weed(typeof runWeedHarvestGame === 'function' ? runWeedHarvestGame : null);
  modes.weed_dry = weed(typeof runWeedDryGame === 'function' ? runWeedDryGame : null);
  modes.weed_pack = weed(typeof runWeedPackGame === 'function' ? runWeedPackGame : null);

  return modes;
})();
