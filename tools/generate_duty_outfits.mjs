import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const EXTRACT = path.join(ROOT, '_clothing_extract');

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

function parseShopMeta(filePath) {
  const text = fs.readFileSync(filePath, 'utf8');
  const dlcMatch = text.match(/<dlcName>([^<]+)<\/dlcName>/);
  const dlc = dlcMatch ? dlcMatch[1].trim() : path.basename(filePath);
  const items = [];
  for (const block of text.matchAll(/<Item>([\s\S]*?)<\/Item>/g)) {
    const b = block[1];
    const tag = (name, def = '0') => {
      const m = b.match(new RegExp(`<${name}\\s+value="([^"]*)"`));
      if (m) return m[1];
      const m2 = b.match(new RegExp(`<${name}>([^<]*)</${name}>`));
      return m2 ? m2[1].trim() : def;
    };
    const compType = tag('eCompType', '');
    if (!COMP_MAP[compType]) continue;
    items.push({
      comp: COMP_MAP[compType],
      draw: parseInt(tag('localDrawableIndex', '0'), 10),
      tex: parseInt(tag('textureIndex', '0'), 10),
    });
  }
  return { dlc, items };
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

function buildPackOutfits(packLabel, dlc, items, gender) {
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
  const seenUniform = new Set();

  for (const j of jbibItems) {
    const [ld, lt] = pickLowrTex(lowrItems, j.tex);
    const [fd, ft] = pickFeet(feetItems);
    const spec = { 11: [j.draw, j.tex], 4: [ld, lt], 6: [fd, ft] };
    const acc = pickAccs(accsItems, j.tex);
    if (acc) spec[8] = acc;
    if (upprItems.length) {
      const u = [...upprItems].sort((a, b) => a.draw - b.draw || a.tex - b.tex)[0];
      spec[3] = [u.draw, u.tex];
    }
    const key = `u-j-${j.draw}-${j.tex}-${ld}-${lt}`;
    if (seenUniform.has(key)) continue;
    seenUniform.add(key);
    outfits.push({
      label: `${packLabel} uniforma – viršus #${j.draw + 1} (${texLabel(j.tex)})`,
      description: `${gender} · be liemenės`,
      category: 'uniform',
      minGrade: 0,
      armour: 0,
      components: makeComponents(dlc, spec),
    });
  }

  for (const l of [...lowrItems].sort((a, b) => a.draw - b.draw || a.tex - b.tex)) {
    if (!jbibItems.length) continue;
    const j0 = [...jbibItems].sort((a, b) => a.draw - b.draw || a.tex - b.tex)[0];
    const [fd, ft] = pickFeet(feetItems);
    const spec = { 11: [j0.draw, j0.tex], 4: [l.draw, l.tex], 6: [fd, ft] };
    const acc = pickAccs(accsItems, j0.tex);
    if (acc) spec[8] = acc;
    const key = `u-l-${l.draw}-${l.tex}`;
    if (seenUniform.has(key)) continue;
    seenUniform.add(key);
    outfits.push({
      label: `${packLabel} uniforma – kelnės #${l.draw + 1} (${texLabel(l.tex)})`,
      description: `${gender} · be liemenės`,
      category: 'uniform',
      minGrade: 0,
      armour: 0,
      components: makeComponents(dlc, spec),
    });
  }

  for (const a of [...accsItems].sort((x, y) => x.draw - y.draw || x.tex - y.tex)) {
    if (!jbibItems.length) continue;
    const j0 = [...jbibItems].sort((x, y) => x.draw - y.draw || x.tex - y.tex)[0];
    const [ld, lt] = pickLowrTex(lowrItems, j0.tex);
    const [fd, ft] = pickFeet(feetItems);
    const spec = { 11: [j0.draw, j0.tex], 4: [ld, lt], 6: [fd, ft], 8: [a.draw, a.tex] };
    const key = `u-a-${a.draw}-${a.tex}`;
    if (seenUniform.has(key)) continue;
    seenUniform.add(key);
    outfits.push({
      label: `${packLabel} uniforma – marškinėliai #${a.draw + 1} (${texLabel(a.tex)})`,
      description: `${gender} · be liemenės`,
      category: 'uniform',
      minGrade: 0,
      armour: 0,
      components: makeComponents(dlc, spec),
    });
  }

  for (const t of teefItems) {
    if (!jbibItems.length) continue;
    const j0 = [...jbibItems].sort((a, b) => a.draw - b.draw || a.tex - b.tex)[0];
    const [ld, lt] = pickLowrTex(lowrItems, j0.tex);
    const [fd, ft] = pickFeet(feetItems);
    const spec = { 11: [j0.draw, j0.tex], 4: [ld, lt], 6: [fd, ft], 7: [t.draw, t.tex] };
    const key = `u-t-${t.draw}-${t.tex}`;
    if (seenUniform.has(key)) continue;
    seenUniform.add(key);
    outfits.push({
      label: `${packLabel} uniforma – aksesuaras #${t.draw + 1} (${texLabel(t.tex)})`,
      description: `${gender} · be liemenės`,
      category: 'uniform',
      minGrade: 0,
      armour: 0,
      components: makeComponents(dlc, spec),
    });
  }

  for (const v of taskItems) {
    outfits.push({
      label: `${packLabel} liemenė #${v.draw + 1} (${texLabel(v.tex)})`,
      description: `${gender} · balistinė liemenė (uždėk ant uniformos)`,
      category: 'vest',
      minGrade: 0,
      armour: 100,
      components: makeComponents(dlc, { 9: [v.draw, v.tex] }),
    });
  }

  return outfits;
}

function mergeGenderOutfits(packs) {
  const merged = new Map();
  for (const [packLabel, metaPath, gender] of packs) {
    if (!fs.existsSync(metaPath)) continue;
    const { dlc, items } = parseShopMeta(metaPath);
    for (const o of buildPackOutfits(packLabel, dlc, items, gender)) {
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
      merged.get(sig)[gender] = o.components;
    }
  }
  return [...merged.values()].sort((a, b) => {
    const ca = a.category === 'uniform' ? 0 : 1;
    const cb = b.category === 'uniform' ? 0 : 1;
    return ca - cb || a.label.localeCompare(b.label, 'lt');
  });
}

function luaStr(s) {
  return `'${s.replace(/\\/g, '\\\\').replace(/'/g, "\\'")}'`;
}

function luaComponentsTable(comps) {
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
    if (hasM) {
      lines.push('        male = {');
      lines.push(luaComponentsTable(o.male));
      lines.push('        },');
    }
    if (hasF) {
      lines.push('        female = {');
      lines.push(luaComponentsTable(o.female));
      lines.push('        },');
    }
    lines.push('    },');
  }
  lines.push('}');
  lines.push('');
  return lines.join('\n');
}

const pdPacks = [
  ['PD V2', path.join(EXTRACT, 'pdv2', 'PDV2', 'mp_m_freemode_01_mp_m_pdv2_shop.meta'), 'male'],
  ['PD Vyrai', path.join(EXTRACT, 'pdvyrai', 'pdvyrai', 'mp_m_freemode_01_mp_m_pdvyrai_shop.meta'), 'male'],
  ['PD V2', path.join(EXTRACT, 'pdv2', 'PDV2', 'mp_f_freemode_01_mp_f_pdv2_shop.meta'), 'female'],
  ['PD Vyrai', path.join(EXTRACT, 'pdvyrai', 'pdvyrai', 'mp_f_freemode_01_mp_f_pdvyrai_shop.meta'), 'female'],
  ['PD Moterys', path.join(EXTRACT, 'pdmot', 'pdmot', 'mp_f_freemode_01_mp_f_pdmot_shop.meta'), 'female'],
];

const gmpPacks = [
  ['GMP', path.join(EXTRACT, 'gmp', 'medikai', 'mp_m_freemode_01_mp_m_eimas25medikai_shop.meta'), 'male'],
  ['GMP', path.join(EXTRACT, 'gmp', 'medikai', 'mp_f_freemode_01_mp_f_eimas25medikai_shop.meta'), 'female'],
];

const pdOutfits = mergeGenderOutfits(pdPacks);
const gmpOutfits = mergeGenderOutfits(gmpPacks);

const pdCfg = path.join(ROOT, 'resources', '[local]', 'fivempro_ltpd', 'config_duty_outfits.lua');
const gmpCfg = path.join(ROOT, 'resources', '[local]', 'fivempro_ambulance', 'config_duty_outfits.lua');

fs.writeFileSync(pdCfg, emitLua(pdOutfits));
fs.writeFileSync(gmpCfg, emitLua(gmpOutfits));

console.log(`PD outfits: ${pdOutfits.length} -> ${pdCfg}`);
console.log(`GMP outfits: ${gmpOutfits.length} -> ${gmpCfg}`);
console.log(
  `  PD uniform=${pdOutfits.filter((o) => o.category === 'uniform').length} vest=${pdOutfits.filter((o) => o.category === 'vest').length}`,
);
console.log(
  `  GMP uniform=${gmpOutfits.filter((o) => o.category === 'uniform').length} vest=${gmpOutfits.filter((o) => o.category === 'vest').length}`,
);
