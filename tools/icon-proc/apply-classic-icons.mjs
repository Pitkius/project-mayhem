/**
 * Atkuria QB klasikinį inventoriaus ikonų stilių (illustrated, be violetinio rimo).
 * 1) Git restore iš 2d937c37 (detalios ikonos)
 * 2) Alias į esamas kokybiškas ikonas projekte
 * 3) Normalizacija į 256px standartą
 * 4) Procedūrinių grybų / svarstyklių pergeneravimas
 */
import { execSync } from 'child_process';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const imagesDir = path.join(__dirname, '..', '..', 'resources', '[qb]', 'qb-inventory', 'html', 'images');

const TARGETS = [
  'weed_leaf', 'weed_buds', 'weed_resin', 'weed_seed', 'weed_baggy', 'weed_baggy_empty', 'weed_brick',
  'coca_leaf', 'cocaine_paste', 'cocaine_powder_loose', 'cocaine_baggy', 'coke_small_brick', 'coke_brick',
  'poppy_flower', 'heroin_powder_loose', 'heroin_bag', 'meth_crystal', 'meth_baggy',
  'mushroom_raw', 'mushroom_dried', 'mushroom_pack', 'joint', 'crack_baggy', 'xtc_baggy', 'oxy',
  'amp_precursor', 'amp_paste', 'pill_tablets', 'moonshine_spirit', 'alcohol_base', 'vodka',
  'vape_liquid_base', 'vape_mix', 'vape_liquid', 'thc_vape_bottle', 'chemical_mix', 'empty_bottle',
  'ocb_papers', 'filter_tip', 'lab_kit', 'drug_scale', 'gloves_item', 'lighter', 'plastic', 'metal_scrap',
  'gun_frame', 'gun_barrel', 'gun_spring', 'gun_trigger', 'weapon_parts', 'weapon_prototype', '3d_printer',
  'pistol_ammo', 'smg_ammo', 'rifle_ammo', 'shotgun_ammo',
  'cartel_pack', 'cartel_blend', 'heroin_paste', 'meth', 'meth_ingredient', 'rolling_paper', 'cokebaggy',
];

/** Esamos kokybiškos ikonos projekte (illustrated QB stilius) */
const LOCAL_ALIASES = {
  coca_leaf: 'cocaineleaf.png',
  metal_scrap: 'metalscrap.png',
  cartel_pack: 'coke_small_brick.png',
  meth: 'meth_baggy.png',
  meth_ingredient: 'chemical_mix.png',
  lab_kit: 'advancedkit.png',
  gloves_item: 'rubber.png',
  plastic: 'rubber.png',
  gun_frame: 'electronickit.png',
  weapon_parts: 'electronickit.png',
  weapon_prototype: 'printerdocument.png',
  alcohol_base: 'vodka.png',
  rolling_paper: 'rolling_paper.png',
  cokebaggy: 'cokebaggy.png',
};

const GIT_COMMITS = ['2d937c37', '6711cbd8', '3e7c9907'];

function tryGitShow(commit, name) {
  const gitPath = `resources/[qb]/qb-inventory/html/images/${name}.png`;
  try {
    return execSync(`git show ${commit}:"${gitPath}"`, { stdio: ['pipe', 'pipe', 'ignore'] });
  } catch {
    return null;
  }
}

function restoreFromGit(name) {
  for (const c of GIT_COMMITS) {
    const buf = tryGitShow(c, name);
    if (buf && buf.length > 8000) {
      return { buf, from: c };
    }
  }
  for (const c of GIT_COMMITS) {
    const buf = tryGitShow(c, name);
    if (buf && buf.length > 500) {
      return { buf, from: c };
    }
  }
  return null;
}

function copyLocalAlias(name, aliasFile) {
  const src = path.join(imagesDir, aliasFile);
  if (!fs.existsSync(src)) return false;
  fs.copyFileSync(src, path.join(imagesDir, `${name}.png`));
  return true;
}

// Pergeneruoti tik grybus / svarstykles (procedūrinis, be rimo)
function regenSmallIcons() {
  execSync('node unify-all-icons.mjs --only=mushroom_raw,mushroom_dried,mushroom_pack,drug_scale', {
    cwd: __dirname,
    stdio: 'inherit',
  });
}

const log = [];
for (const name of TARGETS) {
  const out = path.join(imagesDir, `${name}.png`);
  if (LOCAL_ALIASES[name]) {
    if (copyLocalAlias(name, LOCAL_ALIASES[name])) {
      log.push({ name, source: `alias:${LOCAL_ALIASES[name]}` });
      continue;
    }
  }
  const restored = restoreFromGit(name);
  if (restored) {
    fs.writeFileSync(out, restored.buf);
    log.push({ name, source: `git:${restored.from}`, size: restored.buf.length });
  } else {
    log.push({ name, source: 'missing' });
  }
}

regenSmallIcons();

// Normalizacija dažnai sunaikina detalias QB ikonas — paliekame originalų git restore.
// Jei reikia tik dydžio korekcijos, paleisk normalize atskirai po peržiūros.
console.log(JSON.stringify(log, null, 2));
console.log('Skip normalize — classic illustrated icons kept as restored from git.');
