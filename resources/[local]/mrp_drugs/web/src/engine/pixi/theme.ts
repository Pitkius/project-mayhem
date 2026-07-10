// Shared "underground workstation" visual language. Colors, fonts and helpers
// used by every station so the whole system feels consistent.
export const PALETTE = {
  bgTop: 0x141821,
  bgBottom: 0x090b10,
  tableTop: 0x2a2620,
  tableEdge: 0x18140f,
  metal: 0x3a4048,
  metalLight: 0x565e68,
  glass: 0x9fd8e6,
  neon: 0x22d3ee,
  neonSoft: 0x0e7490,
  amber: 0xf59e0b,
  green: 0x84cc16,
  red: 0xef4444,
  text: 0xe8eef6,
  textDim: 0x8b96a6,
};

export const FONT = 'Inter, "Segoe UI", system-ui, sans-serif';

export function textStyle(size: number, color = PALETTE.text, weight = '600') {
  return {
    fontFamily: FONT,
    fontSize: size,
    fontWeight: weight as never,
    fill: color,
    align: 'center' as const,
  };
}
