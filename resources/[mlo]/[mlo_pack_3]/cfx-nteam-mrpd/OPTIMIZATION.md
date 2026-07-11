# cfx-nteam-mrpd — optimizacijos gidas

Resursas: `resources/[mlo]/[mlo_pack_3]/cfx-nteam-mrpd`
Dydis: ~47 MB · 289 failų · 206 `.ydr` modeliai · 6 `.ytd` tekstūros · 36 `.ymap`

> **Kodėl reikia CodeWalker / OpenIV:** visi `.ytd`, `.ydr`, `.ymap`, `.ybn` yra binariniai
> GTA5 RSC7 failai. Jų neįmanoma redaguoti tekstiniu editoriumi ar skriptu — reikia
> grafinės programos. Šis gidas nurodo TIKSLIUS failus ir nustatymus, kad darbas būtų greitas.

Įrankiai (nemokami):
- **CodeWalker** (RPF Explorer + YTD/YMAP editorius) — pagrindinis
- **OpenIV** — alternatyva tekstūroms
- (Sudėtingam) **CodeWalker** portalų/occlusion redaktorius

---

## 1 VARIANTAS — SAUGU ✅ (JAU ATLIKTA)

- `dt_19_mrpd` (nenaudojamas, `stop` cfg) pašalintas iš repo.
  Backup: `C:\Users\pytka\Desktop\_MRPD_BACKUP\dt_19_mrpd` (463 failai, ~96 MB).
- `.gitignore` papildytas: `_tmp_mrpd_extract/`, `_tmp_vehicle_packs/`, `_MRPD_BACKUP/`,
  `**/tsconfig.tsbuildinfo`, ir `dt_19_mrpd/`.
- Serveris naudoja tik `cfx-nteam-mrpd` (`cfg/15_mlo.cfg`), dvigubo MRPD kraunimo nėra.

Rezultatas: repo/deploy −96 MB, jokios rizikos (failai tik diske, git istorijoje išlieka).

---

## 2 VARIANTAS — VIDUTINIS: tekstūrų grandinė (didžiausias FPS efektas)

### Problema
`data/gtxd.meta` sukuria **5 lygių tekstūrų grandinę**, kuri visa turi būti sustreaminta
artėjant prie MRPD (render thread spike / FPS kritimas):

```
nteammrpdtxt5 → nteammrpdtxt4 → nteammrpdtxt3 → nteammrpdtxt2 → nteammrpdtxt1 → nteammrpdtxt
```

| Failas | Dydis | Tikslas |
|---|---|---|
| nteammrpdtxt.ytd  | 6.01 MB | mažinti mip/resize |
| nteammrpdtxt5.ytd | 5.10 MB | mažinti |
| nteammrpdtxt1.ytd | 4.80 MB | mažinti |
| nteammrpdtxt2.ytd | 4.76 MB | mažinti |
| nteammrpdtxt4.ytd | 4.23 MB | mažinti |
| nteammrpdtxt3.ytd | 4.18 MB | mažinti |
| **VISO** | **~29 MB** | tikslas ~12–15 MB |

### Žingsniai (CodeWalker)
1. **Backup** — jis jau yra `_MRPD_BACKUP`, bet prieš keitimą nusikopijuok patį
   `cfx-nteam-mrpd` į atskirą aplanką.
2. CodeWalker → **RPF Explorer** → atidaryk `stream/nteammrpdtxt.ytd`.
3. Kiekvienai tekstūrai patikrink rezoliuciją. Taikinys:
   - Grindys/sienos/lubos diffuse: **2048 → 1024**
   - Smulkūs dekorai / logotipai / plakatai: **1024 → 512**
   - Normal maps: gali likti, bet ne didesni nei diffuse.
4. **Formatas:** įsitikink, kad naudojama **DXT1** (be alfa) arba **DXT5** (su alfa),
   ne nekompresuotas A8R8G8B8. Nekompresuotos tekstūros = didžiausias „riebumas".
5. **Mip levels:** palik pilną mip grandinę (svarbu tolimam LOD), bet po resize.
6. Išsaugok kiekvieną `.ytd`. Pakartok su txt1–txt5.

### (Neprivaloma) grandinės supaprastinimas
Jei daug tekstūrų kartojasi tarp lygių — jas galima sujungti į mažiau `.ytd` ir
sutrumpinti `gtxd.meta` grandinę (pvz. 5 → 2 lygiai). Tai advanced; daryk tik jei
patogu su CodeWalker `.ytd` merge.

### Patikra
- `ensure cfx-nteam-mrpd`, nueik prie MRPD ir viduje — vizualiai patikrink, ar
  tekstūros neišsiplovė (ypač tekstas ant lentelių, logotipai).
- `resmon` (F8 → `resmon 1`) — stebėk resurso CPU/streaming ms artėjant.

Laukiamas efektas: streaming ~29 MB → ~13 MB, mažesnis spike įeinant.

---

## 3 VARIANTAS — SUDĖTINGAS: geometrija, portalai, occlusion

> Didesnė rizika. Daryk tik po 2 varianto ir tik su pilnu backup. Testuok kiekvieną žingsnį.

### 3.1 Sunkiausi modeliai (draw calls / poly)
| Failas | Dydis | Pastaba |
|---|---|---|
| nteammprdstairsrails.ydr | 1.34 MB | laiptų turėklai — daug poly, tikrink LOD |
| dt1_19_furgrass.ydr | 1.23 MB | „grass" geometrija — ar tikrai reikia? |
| ntreammrpdbuilding.ydr | 1.01 MB | pastato korpusas |
| nteam_mrpd_armoryanim2.ydr | 0.99 MB | animuotas armory |
| nteam_mrpd_armory1.ydr | 0.96 MB | armory |
| nteammrpdlobbyseat.ydr | 0.79 MB | lobbio sėdynės |

Veiksmai CodeWalker/Blender:
1. Patikrink, ar kiekvienas `.ydr` turi **LOD lygius** (L0/L1/L2). Jei tik High —
   FiveM visada renderina pilną. Pridėk LOD arba `lodDist` per ymap.
2. `nteammprdstairsrails` ir `nteammrpdlobbyseat` — pagrindiniai poly „valgytojai".
   Decimate LOD1/2 Blenderyje (`.ydr` eksportas per Sollumz plugin).

### 3.2 Portalai (interjero kambarių matomumas)
- MRPD interjeras aprašytas `nteammrpdmilo.ymap` + `.ytyp`.
- CodeWalker **YMAP → MLO → Portals**: patikrink, ar portalai teisingai atskiria
  kambarius. Blogi/per platūs portalai priverčia renderinti visus kambarius vienu metu.
- Tikslas: kiekvienas kambarys mato tik kaimyninius per duris/langus.

### 3.3 Occlusion
- Yra `hei_dt1_occl_05.ymap` (occlusion). Patikrink, ar occlusion box'ai dengia
  pastato korpusą — kad iš lauko nesirenderintų vidus ir atvirkščiai.

### 3.4 LOD lights (mažas, bet lengvas laimėjimas)
36 `.ymap` sąraše yra daug `vw_distlodlights_*` ir `vw_lodlights_*` — tai tolimų
žibintų LOD. Jie normalūs, NEtrinti (kitaip dings tolimi žibintai). Tik informacijai.

### Patikra po 3 varianto
- Įeik/išeik iš kiekvieno kambario — ar nedingsta sienos, ar nematyti „pro sienas".
- `resmon` + FPS prieš/po prie įėjimo ir viduje.
- Collision testas: vaikščiok, tikrink ar nekrenti pro grindis (jei lietei `.ybn`).

---

## Bendra tvarka
1. ✅ 1 (saugu) — atlikta.
2. 2 (tekstūros) — didžiausias efektas / mažiausia rizika. **Rekomenduoju pradėti čia.**
3. 3 (geometrija/portalai) — tik jei po 2 vis dar reikia daugiau FPS.

Po kiekvieno keitimo: `restart cfx-nteam-mrpd` serveryje ir vizualus + `resmon` testas.
