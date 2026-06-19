import { execSync } from 'child_process';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const imagesDir = path.join(__dirname, '..', '..', 'resources', '[qb]', 'qb-inventory', 'html', 'images');

const GENERATORS = [
  'weed_leaf', 'weed_buds', 'weed_resin', 'weed_seed', 'weed_baggy', 'weed_baggy_empty', 'weed_brick',
  'coca_leaf', 'cocaine_paste', 'cocaine_powder_loose', 'cocaine_baggy', 'coke_small_brick', 'coke_brick',
  'poppy_flower', 'heroin_powder_loose', 'heroin_bag', 'meth_crystal', 'meth_baggy',
  'mushroom_raw', 'mushroom_dried', 'mushroom_pack', 'joint', 'crack_baggy', 'xtc_baggy', 'oxy',
  'amp_precursor', 'amp_paste', 'pill_tablets', 'moonshine_spirit', 'alcohol_base', 'vodka',
  'vape_liquid_base', 'vape_mix', 'vape_liquid', 'thc_vape_bottle', 'chemical_mix', 'empty_bottle',
  'ocb_papers', 'filter_tip', 'lab_kit', 'drug_scale', 'gloves_item', 'lighter', 'plastic', 'metal_scrap',
  'gun_frame', 'gun_barrel', 'gun_spring', 'gun_trigger', 'weapon_parts', 'weapon_prototype', '3d_printer',
  'pistol_ammo', 'smg_ammo', 'rifle_ammo', 'shotgun_ammo',
];

const EXTRA_COPIES = ['cartel_pack', 'cartel_blend', 'heroin_paste', 'meth', 'meth_ingredient', 'rolling_paper', 'cokebaggy'];
const ALL = [...new Set([...GENERATORS, ...EXTRA_COPIES])];

const COMMITS = ['2d937c37', '6711cbd8', '3e7c9907', 'd8e61edd', 'c97e6e86'];

function tryGitShow(commit, name) {
  const gitPath = `resources/[qb]/qb-inventory/html/images/${name}.png`;
  try {
    return execSync(`git show ${commit}:"${gitPath}"`, { stdio: ['pipe', 'pipe', 'ignore'] });
  } catch {
    return null;
  }
}

const report = [];
for (const name of ALL) {
  let restored = null;
  let from = null;
  for (const c of COMMITS) {
    const buf = tryGitShow(c, name);
    if (buf && buf.length > 3000) {
      restored = buf;
      from = c;
      break;
    }
  }
  if (!restored) {
    for (const c of COMMITS) {
      const buf = tryGitShow(c, name);
      if (buf && buf.length > 500) {
        restored = buf;
        from = c;
        break;
      }
    }
  }
  if (restored) {
    fs.writeFileSync(path.join(imagesDir, `${name}.png`), restored);
    report.push({ name, from, size: restored.length, status: 'restored' });
  } else {
    report.push({ name, status: 'missing' });
  }
}

console.log(JSON.stringify(report, null, 2));
console.log(`Restored ${report.filter((r) => r.status === 'restored').length}/${ALL.length}`);
