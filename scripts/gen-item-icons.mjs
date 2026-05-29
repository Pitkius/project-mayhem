import { Resvg } from '@resvg/resvg-js';
import { writeFileSync, readFileSync, mkdirSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const outDir = join(__dirname, '../resources/[qb]/qb-inventory/html/images');

const icons = {
  basic_flashdrive: `<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
  <rect width="256" height="256" fill="none"/>
  <g transform="translate(28 88) rotate(-35 100 40)">
    <rect x="72" y="18" width="88" height="34" rx="4" fill="#b8bcc4" stroke="#6b7280" stroke-width="3"/>
    <rect x="18" y="8" width="58" height="54" rx="8" fill="#1f2937" stroke="#4b5563" stroke-width="3"/>
    <rect x="28" y="18" width="38" height="34" rx="3" fill="#374151"/>
    <circle cx="148" cy="35" r="10" fill="none" stroke="#9ca3af" stroke-width="4"/>
  </g>
</svg>`,

  encrypted_flashdrive: `<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
  <rect width="256" height="256" fill="none"/>
  <g transform="translate(28 88) rotate(-35 100 40)">
    <rect x="72" y="18" width="88" height="34" rx="4" fill="#b8bcc4" stroke="#6b7280" stroke-width="3"/>
    <rect x="18" y="8" width="58" height="54" rx="8" fill="#312e81" stroke="#6366f1" stroke-width="3"/>
    <rect x="28" y="18" width="38" height="34" rx="3" fill="#4338ca"/>
    <rect x="34" y="24" width="26" height="20" rx="2" fill="none" stroke="#c4b5fd" stroke-width="3"/>
    <path d="M47 34v-4a6 6 0 0 1 12 0v4" fill="none" stroke="#c4b5fd" stroke-width="3"/>
    <circle cx="148" cy="35" r="10" fill="none" stroke="#818cf8" stroke-width="4"/>
  </g>
</svg>`,

  military_flashdrive: `<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
  <rect width="256" height="256" fill="none"/>
  <g transform="translate(28 88) rotate(-35 100 40)">
    <rect x="72" y="18" width="88" height="34" rx="4" fill="#9ca3af" stroke="#4b5563" stroke-width="3"/>
    <rect x="18" y="8" width="58" height="54" rx="6" fill="#3f4f37" stroke="#1f2937" stroke-width="3"/>
    <rect x="28" y="18" width="38" height="34" rx="2" fill="#556b2f"/>
    <path d="M38 28h18v4H38zm0 8h18v4H38zm0 8h12v4H38z" fill="#1a2e05"/>
    <circle cx="148" cy="35" r="10" fill="none" stroke="#6b7280" stroke-width="4"/>
  </g>
</svg>`,

  basic_tablet: `<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
  <rect width="256" height="256" fill="none"/>
  <rect x="58" y="36" width="140" height="184" rx="14" fill="#374151" stroke="#9ca3af" stroke-width="4"/>
  <rect x="70" y="52" width="116" height="148" rx="4" fill="#111827"/>
  <rect x="82" y="68" width="52" height="8" rx="2" fill="#4b5563"/>
  <rect x="82" y="84" width="92" height="6" rx="2" fill="#374151"/>
  <rect x="82" y="96" width="80" height="6" rx="2" fill="#374151"/>
  <circle cx="128" cy="212" r="6" fill="#6b7280"/>
</svg>`,

  advanced_tablet: `<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
  <rect width="256" height="256" fill="none"/>
  <rect x="54" y="32" width="148" height="192" rx="16" fill="#1e3a5f" stroke="#38bdf8" stroke-width="4"/>
  <rect x="68" y="48" width="120" height="156" rx="4" fill="#0f172a"/>
  <rect x="80" y="62" width="40" height="40" rx="6" fill="#0ea5e9" opacity="0.35"/>
  <rect x="128" y="62" width="48" height="8" rx="2" fill="#38bdf8"/>
  <rect x="128" y="78" width="36" height="6" rx="2" fill="#334155"/>
  <path d="M80 120h96M80 136h72M80 152h84" stroke="#334155" stroke-width="4" stroke-linecap="round"/>
  <circle cx="128" cy="212" r="6" fill="#38bdf8"/>
</svg>`,

  military_tablet: `<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
  <rect width="256" height="256" fill="none"/>
  <rect x="50" y="28" width="156" height="200" rx="10" fill="#3f4f37" stroke="#1f2937" stroke-width="5"/>
  <rect x="62" y="44" width="132" height="164" rx="2" fill="#0a0f0a"/>
  <path d="M74 58h108M74 74h88M74 90h96" stroke="#4ade80" stroke-width="3" opacity="0.7"/>
  <rect x="74" y="110" width="48" height="48" rx="2" fill="none" stroke="#22c55e" stroke-width="2"/>
  <path d="M86 134h24M98 122v24" stroke="#22c55e" stroke-width="2"/>
  <rect x="130" y="118" width="40" height="6" fill="#14532d"/>
  <rect x="130" y="132" width="28" height="6" fill="#14532d"/>
  <circle cx="128" cy="216" r="7" fill="#365314" stroke="#84cc16" stroke-width="2"/>
</svg>`,

  drill: `<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
  <rect width="256" height="256" fill="none"/>
  <g transform="translate(24 72)">
    <rect x="8" y="52" width="72" height="88" rx="16" fill="#111827" stroke="#374151" stroke-width="3"/>
    <rect x="18" y="62" width="52" height="24" rx="6" fill="#f97316"/>
    <rect x="24" y="92" width="18" height="34" rx="4" fill="#1f2937"/>
    <rect x="72" y="68" width="96" height="44" rx="10" fill="#f97316" stroke="#c2410c" stroke-width="3"/>
    <rect x="168" y="78" width="32" height="24" rx="4" fill="#374151"/>
    <path d="M200 90l36-18 8 16-36 18z" fill="#9ca3af" stroke="#6b7280" stroke-width="2"/>
    <path d="M236 88l12 6-4 8-12-6z" fill="#d1d5db"/>
  </g>
</svg>`,

  tow_chain: `<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
  <rect width="256" height="256" fill="none"/>
  <g fill="none" stroke="#71717a" stroke-width="10" stroke-linecap="round">
    <ellipse cx="88" cy="128" rx="34" ry="22"/>
    <ellipse cx="128" cy="128" rx="34" ry="22"/>
    <ellipse cx="168" cy="128" rx="34" ry="22"/>
    <path d="M54 128c0-28 16-48 34-48"/>
    <path d="M202 128c0 28-16 48-34 48"/>
  </g>
  <path d="M38 128c-12 0-22 10-22 22v8c0 8 6 14 14 14h8" fill="none" stroke="#52525b" stroke-width="8" stroke-linecap="round"/>
  <path d="M218 128c12 0 22 10 22 22v8c0 8-6 14-14 14h-8" fill="none" stroke="#52525b" stroke-width="8" stroke-linecap="round"/>
</svg>`,
};

mkdirSync(outDir, { recursive: true });

for (const [name, svg] of Object.entries(icons)) {
  const resvg = new Resvg(svg, {
    fitTo: { mode: 'width', value: 256 },
    background: 'rgba(0,0,0,0)',
  });
  const png = resvg.render().asPng();
  const path = join(outDir, `${name}.png`);
  writeFileSync(path, png);
  console.log('wrote', path);
}
