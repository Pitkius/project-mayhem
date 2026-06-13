const fs = require('fs');
const path = require('path');

const roots = [
  'resources/[cars]/reh-rebadged-car-pack/reh-rebadged-pack1',
  'resources/[cars]/reh-rebadged-car-pack/reh-rebadged-pack2',
  'resources/[cars]/reh-rebadged-car-pack/reh-rebadged-pack3',
];

const classMap = {
  VC_COMPACT: 'compacts',
  VC_SEDAN: 'sedans',
  VC_SUV: 'suvs',
  VC_COUPE: 'coupes',
  VC_MUSCLE: 'muscle',
  VC_SPORT_CLASSIC: 'sportsclassics',
  VC_SPORT: 'sports',
  VC_SUPER: 'super',
  VC_MOTORCYCLE: 'motorcycles',
  VC_OFF_ROAD: 'offroad',
  VC_INDUSTRIAL: 'industrial',
  VC_UTILITY: 'utility',
  VC_VAN: 'vans',
  VC_EMERGENCY: 'sports',
  VC_SERVICE: 'utility',
  VC_COMMERCIAL: 'vans',
};

const priceByCat = {
  compacts: 18000,
  sedans: 45000,
  suvs: 75000,
  coupes: 65000,
  muscle: 85000,
  sportsclassics: 120000,
  sports: 150000,
  super: 850000,
  motorcycles: 45000,
  offroad: 55000,
  utility: 35000,
  vans: 40000,
  _default: 75000,
};

function cleanBrand(b) {
  b = String(b || 'Import').trim();
  if (/https?:\/\//i.test(b) || b.length > 32) return 'Import';
  return b.replace(/'/g, '');
}

function walk(dir, acc = []) {
  for (const ent of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, ent.name);
    if (ent.isDirectory()) walk(p, acc);
    else if (ent.name === 'vehicles.meta') acc.push(p);
  }
  return acc;
}

const byModel = new Map();
for (const root of roots) {
  if (!fs.existsSync(root)) continue;
  for (const file of walk(root)) {
    const xml = fs.readFileSync(file, 'utf8');
    const model = xml.match(/<modelName>\s*([^<]+)\s*<\/modelName>/i)?.[1]?.trim()?.toLowerCase();
    if (!model) continue;
    const gameName = xml.match(/<gameName>\s*([^<]+)\s*<\/gameName>/i)?.[1]?.trim() || model;
    const brand = cleanBrand(xml.match(/<vehicleMakeName>\s*([^<]+)\s*<\/vehicleMakeName>/i)?.[1]);
    const vc = xml.match(/<vehicleClass>\s*([^<]+)\s*<\/vehicleClass>/i)?.[1]?.trim() || 'VC_SPORT';
    const category = classMap[vc] || 'sports';
    const price = priceByCat[category] || priceByCat._default;
    const entry = { model, name: gameName, brand, category, price };
    if (!byModel.has(model) || entry.name.length > byModel.get(model).name.length) {
      byModel.set(model, entry);
    }
  }
}

const vehicles = [...byModel.values()].sort((a, b) => a.model.localeCompare(b.model));

let out = '-- REH Rebadged Car Pack (auto-generated)\nreturn {\n';
for (const v of vehicles) {
  const name = v.name.replace(/'/g, "\\'");
  const brand = v.brand.replace(/'/g, "\\'");
  out += `    { model = '${v.model}', name = '${name}', brand = '${brand}', price = ${v.price}, category = '${v.category}', type = 'automobile', shop = 'pdm' },\n`;
}
out += '}\n';

fs.writeFileSync('resources/[qb]/qb-core/shared/vehicles_reh.lua', out);

let overrides = '\n--- REH Rebadged Car Pack kainos\n';
for (const v of vehicles) {
  const key = /^[0-9]/.test(v.model) ? `['${v.model}']` : v.model;
  overrides += `    ${key} = ${v.price},\n`;
}
fs.writeFileSync('resources/[local]/fivempro_dealership/config_reh_prices.lua', `--[[ REH pack spawn names: ${vehicles.map(v => v.model).join(', ')} ]]\nConfig.RehPriceOverrides = {\n${overrides}}\n`);

console.log('unique', vehicles.length);
console.log(vehicles.map(v => `${v.model} (${v.category})`).join('\n'));
