# ASSET_REQUIREMENTS — MRP Drugs darbo stotys

Šis dokumentas aprašo vizualinius/garso assetus, kurių reikia, kad darbo stotys
atrodytų profesionaliai. Kol jų nėra, scenoje naudojami **PLACEHOLDER** objektai,
piešiami PixiJS `Graphics` (NE CSS). Placeholderiai kode pažymėti komentaru
`PLACEHOLDER`.

## Bendri reikalavimai visiems assetams

- Formatas: **WebP** (fallback PNG), su permatomu fonu (kur reikia).
- Kameros kampas: **~15° iš viršaus** (lengvas top-down), vienodas visoms stotims.
- Apšvietimas: **kryptinis iš viršaus-kairės**, minkšti šešėliai.
- Spalvų korekcija: tamsi „underground" paletė (žr. `src/engine/pixi/theme.ts`).
- Rezoliucija: authoring 1280×720 dizaino erdvėje (žr. `DESIGN_W/DESIGN_H`).
- Optimizacija: suspausti WebP, be 4K tekstūrų; kur įmanoma – sprite atlasai.

## Katalogų struktūra (kai bus assetai)

```text
web/src/assets/
  workstations/{thc,alcohol,vape,weed,heroin,cocaine,amphetamine}/
  equipment/
  packaging/
  effects/
  audio/
  shared/
```

## THC stotis (`src/minigames/thc/ThcStation.ts`)

| Failas | Paskirtis | Rezoliucija | Fonas | Scena |
|--------|-----------|-------------|-------|-------|
| `workstations/thc/bench.webp` | Tamsus stalviršis + apšvietimas | 1280×720 | ne | visos THC |
| `workstations/thc/tray.webp` | Trim padėklas su derva | 640×360 | taip | SCRAPE |
| `equipment/scraper.webp` | Metalinė gramdyklė | 256×96 | taip | SCRAPE |
| `equipment/distiller_beaker.webp` | Stiklinis distiliavimo indas | 320×420 | taip | DISTILL |
| `packaging/thc_cartridge_empty.webp` | Tuščia kasetė | 160×420 | taip | FILL/SEAL |
| `packaging/thc_cartridge_full.webp` | Pilna kasetė | 160×420 | taip | PACK |
| `packaging/thc_box.webp` | Pakavimo dėžutė | 560×440 | taip | PACK |
| `effects/liquid_amber.webp` | THC skysčio tekstūra | 256×256 | taip | FILL/DISTILL |
| `effects/bubbles.webp` | Burbuliukų sprite atlasas | 512×512 | taip | DISTILL |

## Garsas

Šiuo metu naudojama **WebAudio sintezė** (`src/engine/audio/audio.ts`) —
placeholderiai. Norint pakeisti tikrais garsais, įkelk į `assets/audio/`:

| Failas | Kada | Trukmė |
|--------|------|--------|
| `click.webm` | mygtukai / žymėjimas | <0.1s |
| `pour.webm` | skysčio pylimas | ~0.4s |
| `valve.webm` | vožtuvo/spaudimo laikymas | loop |
| `seal.webm` | sandarinimas | ~0.3s |
| `success.webm` | etapo/sesijos sėkmė | ~0.5s |
| `fail.webm` | nesėkmė | ~0.4s |
| `ambient_lab.webm` | foninis ūžimas | loop |

## Pastaba dėl migracijos

Assetų pakeitimas NEKEIČIA interakcijų logikos — `Graphics` primityvus tereikia
pakeisti `Sprite`/`Texture` tuose pačiuose `stage*` metoduose.

## Perkelti į React/Pixi (2026-07)

Visi schedule minigame narkotikai naudoja `web/src/minigames/`:

| Drug | Failas | Režimai |
|------|--------|---------|
| thc | `thc/ThcStation.ts` | thc_scrape, thc_cartridge |
| alcohol | `alcohol/AlcoholStation.ts` | moonshine_still, moonshine_jar |
| vape | `vape/VapeStation.ts` | vape_blend, vape_dropper |
| weed | `weed/WeedStation.ts` | weed_soil … weed_pack |
| heroin | `heroin/HeroinStation.ts` | heroin_cook, heroin_fold |
| cocaine | `cocaine/CocaineStation.ts` | cocaine_wash, cocaine_brick, coca_harvest |
| amp | `amp/AmpStation.ts` | amp_stamp (process = quiz, ne schedule) |
| meth | `meth/MethStation.ts` | meth_crystal, meth_crush_pack |
| pills | `pills/PillsStation.ts` | pills_press, pills_blister |
| mushroom | `mushroom/MushroomStation.ts` | mushroom_brush, mushroom_jar, mushroom_harvest |

Bendri etapai: `web/src/minigames/shared/commonStages.ts`
