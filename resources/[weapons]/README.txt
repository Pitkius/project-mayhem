FGC-9 (addon ginklas)
=====================

1. Nukopijuok f60129-FGC-9.rar į tools/weapon-drops/
2. Paleisk tools/START-FGC9-INSTALL.bat
3. Perkrauk serverį arba: ensure [weapons]

QB integracija (jau paruošta):
- item: weapon_fgc9
- gamyba: fivempro_drugs ginklų dirbtuvė (L2, craft_fgc9)
- ammo: pistol_ammo (9 mm)
- inventory ikona: qb-inventory/html/images/weapon_fgc9.png

Jei ginklas nematomas arba duoda vanilla modelį — atidaryk weapons.meta ir patikrink <Name>.
Jei hash ne WEAPON_FGC9, atnaujink qb-core/shared/items.lua ir weapons.lua.
