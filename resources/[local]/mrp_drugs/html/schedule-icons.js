/* Narkotikų mini-žaidimų ikonos — peradresuoja į DrugIcons SVG */
const SchIcons = (() => {
  const D = () => window.DrugIcons;

  function fillBar(pct, cls) {
    const fill = Math.max(0, Math.min(100, Number(pct) || 0));
    return `<div class="${cls}" style="--fill:${fill}%"><span></span></div>`;
  }

  function icon(name, cls = 'sch-png-icon') {
    const lib = D();
    if (!lib || !lib[name]) return lib ? lib.beaker() : '';
    const svg = lib[name]();
    return svg.replace('class="di', `class="di ${cls}`);
  }

  return {
    growPot(fillPct = 0) {
      return `<div class="sch-png-stack sch-png-pot">${icon('growPot', 'sch-png-pot__img')}${fillBar(fillPct, 'sch-png-pot__fill')}</div>`;
    },
    pot(fillPct = 0) { return this.growPot(fillPct); },
    digitalScale() { return icon('scale', 'sch-png-scale'); },
    scale() { return this.digitalScale(); },
    wateringCan(fillPct = 0, spoutOpen = false) {
      const openCls = spoutOpen ? ' sch-png-can--open' : '';
      return `<div class="sch-png-stack sch-png-can${openCls}">${D().wateringCan(fillPct, spoutOpen).replace('class="di', 'class="di sch-png-can__img')}${fillBar(fillPct, 'sch-png-can__fill')}</div>`;
    },
    soilBag(open = false) { return icon('soilBag', 'sch-svg-icon'); },
    trimScissors() { return icon('scissors', 'sch-png-scissors'); },
    scissors() { return this.trimScissors(); },
    gloves() { return icon('gloves', 'sch-png-gloves'); },
    cannabisLeaf() { return icon('cannabisLeaf', 'sch-png-leaf'); },
    hempTrim() { return icon('cannabisLeaf', 'sch-png-leaf sch-png-hemp'); },
    seedPacket() { return icon('seedPacket', 'sch-svg-icon'); },
    waterBottle() { return icon('waterBottle', 'sch-svg-icon'); },
    sprout() { return this.cannabisLeaf(); },
    waterDrop() { return icon('waterDrop', 'sch-svg-icon'); },
    soilMound() { return icon('soilMound', 'sch-svg-icon'); },
  };
})();
