mrp_radio — fizinės racijos UI

Reikia: qb-core, pma-voice (balsas per raciją)

Naudojimas:
- Item „radio“ arba komanda /racija
- 3 mygtukai: Prisijungti | Dažnis | Garsas ON/OFF
- Dažnis įvedamas ranka (nėra kanalų sąrašo)

Užkoduoti dažniai (server-side):
  1–10   — tik police
  11–15  — tik ambulance
  16–20  — mechanikai (job type mechanic)
  21+    — vieši

PTT (kalbėjimas per raciją): konfigūruok pma-voice (pvz. CAPSLOCK).

ensure mrp_radio (cfg/30_custom.cfg)
