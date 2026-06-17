FGC-9 (combat pistol model swap)
================================

Įdiegtas: resources/[weapons]/fgc9/
- Streamina FGC-9 3D modelį vietoj combat pistol (ospo mod)
- QB itemas: weapon_fgc9 (žaidime naudoja combat pistol hash per qb-weapons alias)

Testas:
  ensure [weapons]
  restart qb-weapons
  /giveitem [id] weapon_fgc9 1
  /giveitem [id] pistol_ammo 90

Pastaba: visi weapon_combatpistol serveryje atrodys kaip FGC-9 (replace mod).
