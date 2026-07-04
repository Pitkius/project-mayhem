import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const CLOTHING = path.join(ROOT, 'resources', '[clothing]');

const COMP_MAP = {
  PV_COMP_LOWR: 4,
  PV_COMP_FEET: 6,
  PV_COMP_JBIB: 11,
  PV_COMP_ACCS: 8,
  PV_COMP_UPPR: 3,
  PV_COMP_TASK: 9,
  PV_COMP_TEEF: 7,
  PV_COMP_DECL: 10,
  PV_COMP_BERD: 1,
  PV_COMP_HAND: 5,
  PV_COMP_HAIR: 2,
  PV_COMP_HEAD: 0,
};

const TEX_LETTERS = 'abcdefghijklmnopqrstuvwxyz';
const CATEGORY_ORDER = { hat: 0, uniform_top: 1, vest: 2, uniform_pants: 3, belt: 4, extra: 5 };

function metaTag(block, name, def = '0') {
  const m = block.match(new RegExp(`<${name}\\s+value="([^"]*)"`));
  if (m) return m[1];
  const m2 = block.match(new RegExp(`<${name}>([^<]*)</${name}>`));
  return m2 ? m2[1].trim() : def;
}

function parseShopMeta(filePath) {
  const text = fs.readFileSync(filePath, 'utf8');
  const dlcMatch = text.match(/<dlcName>([^<]+)<\/dlcName>/);
  const dlc = dlcMatch ? dlcMatch[1].trim() : path.basename(filePath);
  const items = [];
  const componentsSection = text.match(/<pedComponents>([\s\S]*?)<\/pedComponents>/);
  if (componentsSection) {
    for (const block of componentsSection[1].matchAll(/<Item>([\s\S]*?)<\/Item>/g)) {
      const b = block[1];
      const compType = metaTag(b, 'eCompType', '');
      if (!COMP_MAP[compType]) continue;
      items.push({
        comp: COMP_MAP[compType],
        draw: parseInt(metaTag(b, 'localDrawableIndex', '0'), 10),
        tex: parseInt(metaTag(b, 'textureIndex', '0'), 10),
      });
    }
  }
  const props = [];
  const propsSection = text.match(/<pedProps>([\s\S]*?)<\/pedProps>/);
  if (propsSection) {
    for (const block of propsSection[1].matchAll(/<Item>([\s\S]*?)<\/Item>/g)) {
      const b = block[1];
      const anchor = metaTag(b, 'eAnchorPoint', '');
      if (anchor !== 'ANCHOR_HEAD') continue;
      props.push({
        slot: 0,
        draw: parseInt(metaTag(b, 'localPropIndex', '0'), 10),
        tex: parseInt(metaTag(b, 'textureIndex', '0'), 10),
      });
    }
  }
  return { dlc, items, props };
}

function texLabel(tex) {
  return tex < TEX_LETTERS.length ? TEX_LETTERS[tex].toUpperCase() : String(tex + 1);
}

function pickLowrTex(lowrItems, tex) {
  if (lowrItems.some((i) => i.draw === 0 && i.tex === tex)) return [0, tex];
  if (lowrItems.length) {
    const f = [...lowrItems].sort((a, b) => a.draw - b.draw || a.tex - b.tex)[0];
    return [f.draw, f.tex];
  }
  return [0, 0];
}

function pickFeet(feetItems) {
  if (feetItems.length) {
    const f = [...feetItems].sort((a, b) => a.draw - b.draw || a.tex - b.tex)[0];
    return [f.draw, f.tex];
  }
  return [0, 0];
}

function pickAccs(accsItems, tex) {
  if (accsItems.some((i) => i.draw === 0 && i.tex === tex)) return [0, tex];
  if (accsItems.length) {
    const a = [...accsItems].sort((x, y) => x.draw - y.draw || x.tex - y.tex)[0];
    return [a.draw, a.tex];
  }
  return null;
}

function compEntry(dlc, draw, tex) {
  return { collection: dlc, draw, tex };
}

function makeComponents(dlc, spec) {
  const out = {};
  for (const [comp, [d, t]] of Object.entries(spec)) {
    out[Number(comp)] = compEntry(dlc, d, t);
  }
  return out;
}

function makeProps(dlc, spec) {
  const out = {};
  for (const [slot, [d, t]] of Object.entries(spec)) {
    out[Number(slot)] = compEntry(dlc, d, t);
  }
  return out;
}

function pickArmsForJbib(j, upprItems) {
  const match = upprItems.find((i) => i.draw === j.draw && i.tex === j.tex);
  if (match) return [match.draw, match.tex];
  const matchDraw = upprItems.find((i) => i.draw === j.draw);
  if (matchDraw) return [matchDraw.draw, matchDraw.tex];
  if (upprItems.length) {
    const u = [...upprItems].sort((a, b) => a.draw - b.draw || a.tex - b.tex)[0];
    return [u.draw, u.tex];
  }
  return [j.draw, j.tex];
}

function buildPackOutfits(packLabel, dlc, items, props, gender) {
  const byComp = {};
  for (const it of items) {
    (byComp[it.comp] ||= []).push(it);
  }
  const outfits = [];
  const jbibItems = (byComp[11] || []).sort((a, b) => a.draw - b.draw || a.tex - b.tex);
  const lowrItems = byComp[4] || [];
  const feetItems = byComp[6] || [];
  const accsItems = byComp[8] || [];
  const upprItems = byComp[3] || [];
  const taskItems = (byComp[9] || []).sort((a, b) => a.draw - b.draw || a.tex - b.tex);
  const teefItems = (byComp[7] || []).sort((a, b) => a.draw - b.draw || a.tex - b.tex);
  const declItems = (byComp[10] || []).sort((a, b) => a.draw - b.draw || a.tex - b.tex);
  const handItems = (byComp[5] || []).sort((a, b) => a.draw - b.draw || a.tex - b.tex);
  const seenTop = new Set();
  const seenPants = new Set();
  const seenUndershirt = new Set();

  for (const j of jbibItems) {
    const [ad, at] = pickArmsForJbib(j, upprItems);
    const spec = { 11: [j.draw, j.tex], 3: [ad, at] };
    const acc = pickAccs(accsItems, j.tex);
    if (acc) spec[8] = acc;
    const key = `top-${j.draw}-${j.tex}-${ad}-${at}`;
    if (seenTop.has(key)) continue;
    seenTop.add(key);
    outfits.push({
      label: `${packLabel} viršus #${j.draw + 1} (${texLabel(j.tex)})`,
      description: `${gender} · viršutinė dalis (rankos suderintos)`,
      category: 'uniform_top',
      minGrade: 0,
      armour: 0,
      components: makeComponents(dlc, spec),
      props: null,
    });
  }

  for (const l of [...lowrItems].sort((a, b) => a.draw - b.draw || a.tex - b.tex)) {
    const [fd, ft] = pickFeet(feetItems);
    const spec = { 4: [l.draw, l.tex] };
    if (feetItems.length) spec[6] = [fd, ft];
    const key = `pants-${l.draw}-${l.tex}`;
    if (seenPants.has(key)) continue;
    seenPants.add(key);
    outfits.push({
      label: `${packLabel} kelnės #${l.draw + 1} (${texLabel(l.tex)})`,
      description: `${gender} · tik kelnės`,
      category: 'uniform_pants',
      minGrade: 0,
      armour: 0,
      components: makeComponents(dlc, spec),
      props: null,
    });
  }

  for (const a of [...accsItems].sort((x, y) => x.draw - y.draw || x.tex - y.tex)) {
    const key = `acc-${a.draw}-${a.tex}`;
    if (seenUndershirt.has(key)) continue;
    seenUndershirt.add(key);
    outfits.push({
      label: `${packLabel} marškinėliai #${a.draw + 1} (${texLabel(a.tex)})`,
      description: `${gender} · po uniforma (tik marškinėliai)`,
      category: 'uniform_top',
      minGrade: 0,
      armour: 0,
      components: makeComponents(dlc, { 8: [a.draw, a.tex] }),
      props: null,
    });
  }

  for (const t of teefItems) {
    outfits.push({
      label: `${packLabel} diržas #${t.draw + 1} (${texLabel(t.tex)})`,
      description: `${gender} · diržas (uždėk ant uniformos)`,
      category: 'belt',
      minGrade: 0,
      armour: 0,
      components: makeComponents(dlc, { 7: [t.draw, t.tex] }),
      props: null,
    });
  }

  for (const d of declItems) {
    outfits.push({
      label: `${packLabel} extra #${d.draw + 1} (${texLabel(d.tex)})`,
      description: `${gender} · emblema / aksesuaras ant uniformos`,
      category: 'extra',
      minGrade: 0,
      armour: 0,
      components: makeComponents(dlc, { 10: [d.draw, d.tex] }),
      props: null,
    });
  }

  for (const h of handItems) {
    outfits.push({
      label: `${packLabel} extra krepšys #${h.draw + 1} (${texLabel(h.tex)})`,
      description: `${gender} · krepšys / papildomas aksesuaras`,
      category: 'extra',
      minGrade: 0,
      armour: 0,
      components: makeComponents(dlc, { 5: [h.draw, h.tex] }),
      props: null,
    });
  }

  for (const v of taskItems) {
    outfits.push({
      label: `${packLabel} liemenė #${v.draw + 1} (${texLabel(v.tex)})`,
      description: `${gender} · balistinė liemenė (pilni šarvai)`,
      category: 'vest',
      minGrade: 0,
      armour: 100,
      components: makeComponents(dlc, { 9: [v.draw, v.tex] }),
      props: null,
    });
  }

  for (const p of [...props].sort((a, b) => a.draw - b.draw || a.tex - b.tex)) {
    outfits.push({
      label: `${packLabel} kepurė #${p.draw + 1} (${texLabel(p.tex)})`,
      description: `${gender} · galvos apdangalas`,
      category: 'hat',
      minGrade: 0,
      armour: 0,
      components: null,
      props: makeProps(dlc, { [p.slot]: [p.draw, p.tex] }),
    });
  }

  return outfits;
}

function mergeGenderOutfits(packs) {
  const merged = new Map();
  for (const [packLabel, metaPath, gender] of packs) {
    if (!fs.existsSync(metaPath)) {
      console.warn(`Missing meta: ${metaPath}`);
      continue;
    }
    const { dlc, items, props } = parseShopMeta(metaPath);
    for (const o of buildPackOutfits(packLabel, dlc, items, props, gender)) {
      const sig = `${gender}|${o.category}|${o.label}`;
      if (!merged.has(sig)) {
        merged.set(sig, {
          label: o.label,
          description: o.description,
          category: o.category,
          minGrade: 0,
          armour: o.armour,
          male: null,
          female: null,
        });
      }
      merged.get(sig)[gender] = {
        components: o.components,
        props: o.props,
      };
    }
  }
  return [...merged.values()].sort((a, b) => {
    const ca = CATEGORY_ORDER[a.category] ?? 9;
    const cb = CATEGORY_ORDER[b.category] ?? 9;
    return ca - cb || a.label.localeCompare(b.label, 'lt');
  });
}

function luaStr(s) {
  return `'${s.replace(/\\/g, '\\\\').replace(/'/g, "\\'")}'`;
}

function luaComponentsTable(comps) {
  if (!comps || !Object.keys(comps).length) return '';
  const lines = ['            components = {'];
  for (const compId of Object.keys(comps).map(Number).sort((a, b) => a - b)) {
    const c = comps[compId];
    lines.push(
      `                [${compId}] = { collection = '${c.collection}', draw = ${c.draw}, tex = ${c.tex} },`,
    );
  }
  lines.push('            },');
  return lines.join('\n');
}

function luaPropsTable(props) {
  if (!props || !Object.keys(props).length) return '';
  const lines = ['            props = {'];
  for (const slot of Object.keys(props).map(Number).sort((a, b) => a - b)) {
    const p = props[slot];
    lines.push(
      `                [${slot}] = { collection = '${p.collection}', draw = ${p.draw}, tex = ${p.tex} },`,
    );
  }
  lines.push('            },');
  return lines.join('\n');
}

function emitGender(genderKey, genderData) {
  const lines = [];
  if (!genderData) return lines;
  const compBlock = luaComponentsTable(genderData.components);
  const propBlock = luaPropsTable(genderData.props);
  if (!compBlock && !propBlock) return lines;
  lines.push(`        ${genderKey} = {`);
  if (compBlock) lines.push(compBlock);
  if (propBlock) lines.push(propBlock);
  lines.push('        },');
  return lines;
}

function emitLua(outfits) {
  const lines = [
    '--- Tarnybinė apranga (addon kolekcijos – regeneruoti: node tools/generate_duty_outfits.mjs)',
    'Config.DutyOutfits = {',
  ];
  for (const o of outfits) {
    const hasM = o.male != null;
    const hasF = o.female != null;
    if (!hasM && !hasF) continue;
    lines.push('    {');
    lines.push(`        label = ${luaStr(o.label)},`);
    if (o.description) lines.push(`        description = ${luaStr(o.description)},`);
    lines.push(`        category = ${luaStr(o.category)},`);
    lines.push('        minGrade = 0,');
    lines.push(`        armour = ${o.armour || 0},`);
    lines.push(...emitGender('male', o.male));
    lines.push(...emitGender('female', o.female));
    lines.push('    },');
  }
  lines.push('}');
  lines.push('');
  return lines.join('\n');
}

const pdUniforms = path.join(CLOTHING, 'mrp_pd_uniforms');
const gmpUniforms = path.join(CLOTHING, 'mrp_gmp_uniforms');

const pdPacks = [
  ['PD V2', path.join(pdUniforms, 'mp_m_freemode_01_mp_m_pdv2_shop.meta'), 'male'],
  ['PD Vyrai', path.join(pdUniforms, 'mp_m_freemode_01_mp_m_pdvyrai_shop.meta'), 'male'],
  ['PD V2', path.join(pdUniforms, 'mp_f_freemode_01_mp_f_pdv2_shop.meta'), 'female'],
  ['PD Vyrai', path.join(pdUniforms, 'mp_f_freemode_01_mp_f_pdvyrai_shop.meta'), 'female'],
  ['PD Moterys', path.join(pdUniforms, 'mp_f_freemode_01_mp_f_pdmot_shop.meta'), 'female'],
];

const gmpPacks = [
  ['GMP', path.join(gmpUniforms, 'mp_m_freemode_01_mp_m_eimas25medikai_shop.meta'), 'male'],
  ['GMP', path.join(gmpUniforms, 'mp_f_freemode_01_mp_f_eimas25medikai_shop.meta'), 'female'],
];

const pdOutfits = mergeGenderOutfits(pdPacks);
const gmpOutfits = mergeGenderOutfits(gmpPacks);

const pdCfg = path.join(ROOT, 'resources', '[local]', 'mrp_ltpd', 'config_duty_outfits.lua');
const gmpCfg = path.join(ROOT, 'resources', '[local]', 'mrp_ambulance', 'config_duty_outfits.lua');

fs.writeFileSync(pdCfg, emitLua(pdOutfits));
fs.writeFileSync(gmpCfg, emitLua(gmpOutfits));

function countCat(list, cat) {
  return list.filter((o) => o.category === cat).length;
}

console.log(`PD outfits: ${pdOutfits.length} -> ${pdCfg}`);
console.log(`GMP outfits: ${gmpOutfits.length} -> ${gmpCfg}`);
console.log(
  `  PD uniform_pants=${countCat(pdOutfits, 'uniform_pants')} uniform_top=${countCat(pdOutfits, 'uniform_top')} vest=${countCat(pdOutfits, 'vest')} belt=${countCat(pdOutfits, 'belt')} hat=${countCat(pdOutfits, 'hat')}`,
);
console.log(
  `  GMP uniform_pants=${countCat(gmpOutfits, 'uniform_pants')} uniform_top=${countCat(gmpOutfits, 'uniform_top')} vest=${countCat(gmpOutfits, 'vest')} belt=${countCat(gmpOutfits, 'belt')} hat=${countCat(gmpOutfits, 'hat')}`,
);
