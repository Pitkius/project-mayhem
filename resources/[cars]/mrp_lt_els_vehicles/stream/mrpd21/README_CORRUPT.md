# mrpd21 — CRASH / ERR_STR_FAILURE_3

## Priežastis

`stream/mrpd21/mrpd21.yft` ir `mrpd21_hi.yft` yra **sugadinti binary failai**.
Jų RSC7 antraštėje vietoj versijos baitų yra UTF-8 replacement seka `EF BF BD`
(~2.8M tokių sekų `mrpd21.yft`). Tipiška kai `.yft` buvo atidarytas / išsaugotas
kaip tekstas (Git be LFS, redaktorius, blogas copy).

`mrpd21.ytd` atrodo sveikas.

## Crash

Spawn / preview → `RAGE error: ERR_STR_FAILURE_3` (stream failure).

## Fix

1. Atkurk **originalius** `mrpd21.yft` + `mrpd21_hi.yft` iš:
   - git LFS / remote (jei turit sveika istoriją)
   - originalaus BMW 540i ELS pack ZIP
2. Patikrink hex pradžią: turi būti `52 53 43 37` + **ne** `EF BF BD` 5–7 baituose.
3. Įjunk vėl dealership `shopEnabled = true` (`mrp_dealership/config.lua`).

Kol kas shop’e `mrpd21` išjungtas, kad žaidėjai nekrautų.
