# mrp_furniture

Baldų sistema Dynasty 8 būstams.

## Funkcijos
- Parduotuvė (blip + qb-target NPC)
- Pirkimas → inventorius (`furn_*`) → naudojant name: raycast pastatymas
- Owner / keyholder gali statyti ir paimti
- Limitai pagal būsto klasę (`Config.FurnitureCaps`)
- qb-target: sėdėjimas, sofa, lova, TV, seifas, spinta (qb-clothing outfits)
- „Su baldais“ pirkimas → `Config.Presets` layout

## Testas
1. `ensure mrp_housing` tada `ensure mrp_furniture`
2. Dynasty 8 → pirkite economy be baldų / su baldais
3. Eikite į baldų shop (Davis zona blip)
4. Nusipirkite kėdę, name naudokite item → E pastatyti, X atšaukti
5. Seifas / spinta / lova — ALT target

## Pastaba
IPL shell vizualiai gali likti „įrengtas“ GTA assetais; žaidimo baldai = mūsų prop'ai su funkcijomis.
