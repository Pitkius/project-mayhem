/* Unikalūs narkotikų mini-žaidimai — SVG ikonos, atskiri ekranai, jokio emoji */
window.DrugGameModes = (() => {
  const U = () => window.MiniGameUI;
  const modes = {};
  const win = (extra) => postSchedule(true, extra || { score: 88 });
  const fail = () => failSchedule();

  function screen(drug, mode) {
    const m = mode || window.__schCurrentMode;
    if (U() && U().prepareDrugScreen) U().prepareDrugScreen(drug, m);
  }

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

  /* ═══ THC — premium Canvas distiliacija + kasetė ═══ */
  function thcHooks() {
    return {
      setStep,
      hint: schHint,
      onWin: (extra) => win(extra || { score: 90 }),
      onFail: fail,
    };
  }

  function thcMode(runFn, fallback) {
    return (data) => {
      screen('thc');
      if (window.MgThc && typeof MgThc[runFn] === 'function') {
        MgThc[runFn](data, thcHooks());
        return;
      }
      if (typeof fallback === 'function') return fallback(data);
      fail();
    };
  }

  modes.thc_scrape = thcMode('runScrape', (data) => {
    const steps = data.steps || 4;
    setStep(1, 3, 'Paruošk trim medžiagą');
    U().scrapeTrim({
      toolIcon: 'scissors',
      targetIcon: 'cannabisLeaf',
      cuts: steps,
      positions: SPOTS.scrape,
      onComplete: () => {
        setStep(2, 3, 'Surink distiliatą');
        U().clickBoard({
          title: 'Pažymėk aktyvius taškus ant masės',
          total: steps,
          icon: 'thcVial',
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
  });

  modes.thc_cartridge = thcMode('runCartridge', (data) => {
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
  });

  /* ═══ Alkoholis — varinis distiliatorius ═══ */
  modes.moonshine_still = (data) => {
    screen('alcohol');
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
          icon: 'moonshineJar',
          hintEl: schHint,
          onSuccess: () => win({ score: 86 }),
          onFail: fail,
        });
      },
      onFail: fail,
    });
  };

  modes.moonshine_jar = (data) => {
    screen('alcohol');
    setStep(1, 3, 'Supilk į stiklainį');
    U().pourHold({
      label: 'Pilti samagoną',
      target: 100,
      icon: 'moonshineJar',
      hintEl: schHint,
      onSuccess: () => {
        setStep(2, 3, 'Užkorkuok');
        U().multiTap({
          icon: 'moonshineJar',
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

  /* ═══ Vape — premium Canvas laboratorija ═══ */
  modes.vape_blend = (data) => {
    screen('vape');
    if (window.MgVape) {
      MgVape.runBlend(data, {
        setStep,
        hint: schHint,
        onWin: (extra) => {
          finishSuccess('Vape mišinys stabilizuotas');
          win(extra || { score: 88 });
        },
        onFail: fail,
      });
      return;
    }
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
    screen('vape');
    if (window.MgVape) {
      MgVape.runDropper(data, {
        setStep,
        hint: schHint,
        onWin: (extra) => win(extra || { score: 90 }),
        onFail: fail,
      });
      return;
    }
    const need = data.steps || 3;
    setStep(1, need + 1, 'Lašink tiksliai į buteliuką');
    U().timedDrops({
      need,
      icon: 'waterDrop',
      onComplete: () => {
        setStep(2, need + 1, 'Užsandarink buteliuką');
        U().sealZones({ need: 2, onDone: () => win({ score: 87 }) });
      },
      onFail: fail,
    });
  };

  /* ═══ Heroinas — premium Canvas medicininė virtuvė ═══ */
  function heroinHooks() {
    return {
      setStep,
      hint: schHint,
      onWin: (extra) => win(extra || { score: 86 }),
      onFail: fail,
    };
  }

  function heroinMode(runFn, fallback) {
    return (data) => {
      screen('heroin');
      if (window.MgHeroin && typeof MgHeroin[runFn] === 'function') {
        MgHeroin[runFn](data, heroinHooks());
        return;
      }
      if (typeof fallback === 'function') return fallback(data);
      fail();
    };
  }

  modes.heroin_cook = heroinMode('runCook', (data) => {
    setStep(1, 3, 'Kaitink tirpalą');
    U().gaugeHold({
      label: 'Kaitinimas',
      speed: 1.55,
      need: 52,
      hintEl: schHint,
      onSuccess: () => {
        setStep(2, 3, 'Maišyk su mentoliu');
        U().multiTap({ icon: 'beaker', label: 'Maišyti', need: 4, onDone: () => {
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
  });

  modes.heroin_fold = heroinMode('runFold', (data) => {
    const need = data.steps || 3;
    setStep(1, need + 1, 'Sulankstyk foliją');
    U().foilFold({
      need,
      onFolded: () => {
        setStep(2, need + 1, 'Užlydink maišelį');
        U().sealZones({ need: 3, onDone: () => win({ score: 86 }) });
      },
    });
  });

  /* ═══ Metas — premium Canvas kristalų laboratorija ═══ */
  function methHooks() {
    return {
      setStep,
      hint: schHint,
      onWin: (extra) => win(extra || { score: 90 }),
      onFail: fail,
    };
  }

  function methMode(runFn, fallback) {
    return (data) => {
      screen('meth');
      if (window.MgMeth && typeof MgMeth[runFn] === 'function') {
        MgMeth[runFn](data, methHooks());
        return;
      }
      if (typeof fallback === 'function') return fallback(data);
      fail();
    };
  }

  modes.meth_crystal = methMode('runCrystal', (data) => {
    setStep(1, 3, 'Kristalizacijos procesas');
    U().crystalPipeline({
      difficulty: data.difficulty || 2,
      hintEl: schHint,
      onSuccess: () => finishSuccess('Kristalai suformuoti'),
      onFail: fail,
    });
  });

  modes.meth_crush_pack = methMode('runCrushPack', (data) => {
    setStep(1, 3, 'Sutraišk kristalus');
    U().multiTap({
      icon: 'hammer',
      label: 'Sutraiškyti',
      need: 4,
      onDone: () => {
        setStep(2, 3, 'Sverti ir supakuoti');
        U().packBagFlow({
          icon: 'methCrystal',
          onDone: () => win({ score: 90 }),
        });
      },
    });
  });

  /* ═══ Tabletės — premium Canvas farmacijos linija ═══ */
  function pillsHooks() {
    return {
      setStep,
      hint: schHint,
      onWin: (extra) => win(extra || { score: 88 }),
      onFail: fail,
    };
  }

  function pillsMode(runFn, fallback) {
    return (data) => {
      screen('pills');
      if (window.MgPills && typeof MgPills[runFn] === 'function') {
        MgPills[runFn](data, pillsHooks());
        return;
      }
      if (typeof fallback === 'function') return fallback(data);
      fail();
    };
  }

  modes.pills_press = pillsMode('runPress', (data) => {
    const need = data.steps || 4;
    setStep(1, 2, 'Presuok tabletes — tikslus ritmas');
    U().pressRhythm({
      need,
      icon: 'pillPress',
      label: 'Presuoti',
      onDone: () => {
        setStep(2, 2, 'Patikrink tabletes');
        U().multiTap({ icon: 'pill', label: 'Kontrolė', need: 2, onDone: () => win({ score: 88 }) });
      },
      onFail: fail,
    });
  });

  modes.pills_blister = pillsMode('runBlister', (data) => {
    const slots = data.steps || 3;
    setStep(1, 2, 'Įspausk tabletes į blisterį');
    U().blisterPack(slots, () => {
      setStep(2, 2, 'Užlenk apsauginę plėvelę');
      U().sealZones({ need: 3, onDone: () => win({ score: 89 }) });
    });
  });

  /* ═══ Grybai — premium Canvas miško laboratorija ═══ */
  function mushroomHooks() {
    return {
      setStep,
      hint: schHint,
      onWin: (extra) => win(extra || { score: 88 }),
      onFail: fail,
    };
  }

  function mushroomMode(runFn, fallback) {
    return (data) => {
      screen('mushroom');
      if (window.MgMushroom && typeof MgMushroom[runFn] === 'function') {
        MgMushroom[runFn](data, mushroomHooks());
        return;
      }
      if (typeof fallback === 'function') return fallback(data);
      fail();
    };
  }

  modes.mushroom_brush = mushroomMode('runBrush', (data) => {
    setStep(1, 2, 'Nuvalyk grybus');
    U().clickBoard({
      title: 'Nušveisk purvą nuo grybo',
      total: data.steps || 4,
      icon: 'mushroom',
      positions: SPOTS.brush,
      onComplete: () => {
        setStep(2, 2, 'Paruošk džiovinimui');
        U().dryRack({
          need: 3,
          icon: 'mushroom',
          onComplete: () => win({ score: 85 }),
        });
      },
    });
  });

  modes.mushroom_jar = mushroomMode('runJar', (data) => {
    setStep(1, 3, 'Supilk į stiklainį');
    U().pourHold({
      label: 'Supilti grybus',
      target: 95,
      icon: 'moonshineJar',
      hintEl: schHint,
      onSuccess: () => {
        setStep(2, 3, 'Užsukuvok dangtelį');
        U().multiTap({ icon: 'moonshineJar', label: 'Užsukti', need: 3, onDone: () => {
          setStep(3, 3, 'Užsandarink');
          U().sealZones({ need: 2, onDone: () => win({ score: 87 }) });
        }});
      },
      onFail: fail,
    });
  });

  modes.mushroom_harvest = mushroomMode('runHarvest', (data) => {
    setStep(1, 1, 'Surink grybus laiku');
    U().spawnCatcher({
      icon: 'mushroom',
      need: data.steps || 5,
      spawnInterval: 400,
      onComplete: () => win({ score: 90 }),
    });
  });

  /* ═══ Kokainas — premium Canvas lux lab + džiunglės ═══ */
  function cocaineHooks() {
    return {
      setStep,
      hint: schHint,
      onWin: (extra) => win(extra || { score: 88 }),
      onFail: fail,
    };
  }

  function cocaineMode(runFn, fallback) {
    return (data) => {
      screen('cocaine');
      if (window.MgCocaine && typeof MgCocaine[runFn] === 'function') {
        MgCocaine[runFn](data, cocaineHooks());
        return;
      }
      if (typeof fallback === 'function') return fallback(data);
      fail();
    };
  }

  modes.coca_harvest = cocaineMode('runHarvest', (data) => {
    setStep(1, 1, 'Nuimk lapus nuo šakos');
    U().stripRow({
      icon: 'cocaLeaf',
      need: data.steps || 5,
      onComplete: () => win({ score: 88 }),
    });
  });

  modes.cocaine_wash = cocaineMode('runWash', (data) => {
    setStep(1, 2, 'Cheminis plovimas');
    U().chemistryWash({
      need: data.steps || 4,
      hintEl: schHint,
      onDone: () => win({ score: 86 }),
    });
  });

  modes.cocaine_brick = cocaineMode('runBrick', (data) => {
    setStep(1, 3, 'Presuok į bloką');
    U().pressRhythm({
      need: 4,
      icon: 'cocaineBrick',
      label: 'Presuoti',
      onDone: () => {
        setStep(2, 3, 'Apvyniok plėvele');
        U().multiTap({ icon: 'foil', label: 'Apvynioti', need: 3, onDone: () => {
          setStep(3, 3, 'Užlydink siuntą');
          U().sealZones({ need: 3, onDone: () => win({ score: 91 }) });
        }});
      },
      onFail: fail,
    });
  });

  /* ═══ Amfetaminas — premium Canvas pakavimo stalas ═══ */
  function ampHooks() {
    return {
      setStep,
      hint: schHint,
      onWin: (extra) => win(extra || { score: 90 }),
      onFail: fail,
    };
  }

  function ampMode(runFn, fallback) {
    return (data) => {
      screen('amp');
      if (window.MgAmp && typeof MgAmp[runFn] === 'function') {
        MgAmp[runFn](data, ampHooks());
        return;
      }
      if (typeof fallback === 'function') return fallback(data);
      fail();
    };
  }

  modes.amp_stamp = ampMode('runStamp', (data) => {
    setStep(1, 3, 'Užlydink maišelį');
    U().multiTap({
      icon: 'bag',
      label: 'Užlydinti',
      need: 2,
      onDone: () => {
        setStep(2, 3, 'Antspauduok');
        U().pressRhythm({
          need: 3,
          icon: 'pillPress',
          label: 'Antspaudas',
          onDone: () => {
            setStep(3, 3, 'Kontrolinis ženklas');
            U().sealZones({ need: 2, onDone: () => win({ score: 90 }) });
          },
          onFail: fail,
        });
      },
    });
  });

  /* ═══ Kanapės — premium Canvas grow + lab ═══ */
  function weedHooks() {
    return {
      setStep,
      hint: schHint,
      onWin: (extra) => win(extra || { score: 88 }),
      onFail: fail,
    };
  }

  function weedMode(runFn, fallbackFn) {
    return (data) => {
      screen('weed');
      if (window.MgWeed && typeof MgWeed[runFn] === 'function') {
        MgWeed[runFn](data, weedHooks());
        return;
      }
      if (typeof fallbackFn === 'function') return fallbackFn(data);
      fail();
    };
  }

  modes.weed_soil = weedMode('runSoil', typeof runWeedSoilGame === 'function' ? runWeedSoilGame : null);
  modes.weed_seed = weedMode('runSeed', typeof runWeedSeedGame === 'function' ? runWeedSeedGame : null);
  modes.weed_water = weedMode('runWater', typeof runWeedWaterGame === 'function' ? runWeedWaterGame : null);
  modes.weed_harvest = weedMode('runHarvest', typeof runWeedHarvestGame === 'function' ? runWeedHarvestGame : null);
  modes.weed_dry = weedMode('runDry', typeof runWeedDryGame === 'function' ? runWeedDryGame : null);
  modes.weed_pack = weedMode('runPack', typeof runWeedPackGame === 'function' ? runWeedPackGame : null);

  return modes;
})();
