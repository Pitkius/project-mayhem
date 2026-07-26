# mrp_gangs — Gang System 2.0

Naujas, server-authoritative QBCore gaujų resursas. Legacy turf pardavimai pašalinti.
Misijos, teritorijos ir karo kampanijos yra atskiri moduliai su aiškiomis taisyklėmis.

## Reikalavimai

- QBCore 1.3
- oxmysql
- qb-menu (atsarginis Mission Board)
- QBCore progressbar / qb-progressbar
- qb-inventory suderinami item pavadinimai
- OneSync NPC, network entity ir routing bucket palaikymui

`Config.TabletItem` numatyta reikšmė yra `gang_tablet`. Įrašas turi egzistuoti
`QBCore.Shared.Items`, kitaip tabletę galės atidaryti tik admin.

## Clean reset ir diegimas

`sql/reset_v2.sql` yra destruktyvus ir naudojamas tik rankiniu būdu.

1. Padaryti DB atsarginę kopiją ir sustabdyti serverį.
2. Paleisti `sql/reset_v2.sql`.
3. Paleisti `sql/schema_v2.sql`.
4. Į `server.cfg` įrašyti `ensure mrp_gangs` po `qb-core`, `oxmysql` ir `qb-menu`.
5. Paleisti serverį ir patikrinti `[mrp_gangs] ... ready`.
6. Sukurti testines gaujas `/gangcreatev2`.

Resursas starto metu vykdo tik saugų `CREATE TABLE IF NOT EXISTS`, mažas V2
migracijas ir seed duomenis. Jis automatiškai nevykdo reset.

## Komandos

- `/gangtablet` — atidaro naują NUI tabletę.
- `/gangmissions` — atsarginis qb-menu Mission Board.
- `/gangready [scout|breacher|driver|muscle|support]` — 5 min. party rezervacija.
- `/cancelgangmission` — atšaukia aktyvią operaciją.
- `/gangcreatev2 [type] [name] [label]` — admin sukuria gaują.
- `/gangaddv2 [playerId] [gangId]` — admin prideda žaidėją.

## Moduliai

### Gang Core

- Nariai, kvietimai, dinaminiai rangai, atsakomybės ir 60 narių limitas.
- RBAC tikrinamas serveryje; UI leidimai nėra saugumo riba.
- Iždo operacijos su sąlyginiu DB update, refund/revert ir idempotency.
- Reputacijos ledger, auditas, rate limit ir QBCore adapteriai.

### Mission Engine

- 30 mission family: 5 universalios ir po 5 kiekvienam gang type.
- Easy, Medium, Hard ir Extreme; 1–6 žaidėjų party scaling.
- Approach, breach, enter, search, collect, eliminate, defend, sabotage,
  rescue, capture, vehicle, checkpoint ir extraction fazės.
- Kelių bangų Encounter Director, NPC archetipai ir aktyvus cap.
- Rescue/capture network target, cargo carrier, mission transportas ir interjerai.
- Dviejų žingsnių action token, distance/order/time/party validacija.
- Reconnect grace, restart recovery ir gang-level DB lock.
- Vienkartinis reward ledger, pending delivery ir restricted loot governor.

Misijos nekeičia teritorijos savininko ir negeneruoja turf influence.

### Teritorijos

- 18 rankomis suformuotų gatvių polygon: Gang, PvP ir Reketo.
- Optimistic `control_version`, ownership history, lock ir anti-snowball cap.
- Reketo teritorijos periodiškai generuoja iždo pajamas.
- Drug sale leidimas tikrinamas serverio koordinačių, savininko ir produkto pagrindu.

Drug resursas prieš pardavimą privalo kviesti:

```lua
local allowed, resultOrReason = exports.mrp_gangs:ValidateDrugSale(source, itemName)
```

Kai `allowed == true`, `resultOrReason.priceMultiplier` yra saugus teritorijos
kainos koeficientas. Kliento atsiųstos koordinatės nenaudojamos.

### Diplomatija ir karai

- Alliance, Neutral, Enemy, Ceasefire, Pact, Protection, Tribute ir Temporary Peace.
- Mutual sutartims reikia kitos gaujos patvirtinimo; galioja expiry ir break penalty.
- Karui reikia Enemy statuso ir neužrakintos priešo teritorijos.
- Preparation, Active, Settlement, Completed/Cancelled state machine.
- Roster lock, online minimum, objective score ledger ir idempotency.
- Domination, Escort, Intercept, Plant ir Cash Transport objective įrašai.
- Gynėjo bei underdog koeficientai; pergalė sprendžiama score, ne kill count.

### Tabletė ir admin

- Role-aware Overview, Members, Progression, Territories, Missions, Diplomacy,
  Wars, Activity ir Admin skyriai.
- Leaflet GTA V žemėlapis su tikrais polygon ir DB ownership būsena.
- Admin: gaujų statusai, territory owner, mission toggles, active war cancel,
  supply quota, mission telemetry ir audit peržiūra.

## Vieši serverio export

- `GetPlayerGang(source)`
- `GetGangById(gangId)`
- `HasGangPermission(source, permission)`
- `ValidateDrugSale(source, itemName)`
- `FindTerritoryAt(x, y, territoryType?)`
- `GetTerritory(territoryId)` / `GetTerritories()`
- `CanDeclareGangWar(attackerGangId, defenderGangId)`
- `CanPerformGangHostileAction(attackerGangId, targetGangId)`
- `AddGangWarScore(...)` / `CompleteGangWarObjective(...)`
- `StartGangMission(...)` / `CancelGangMission(...)`

## Rankinis smoke test

1. Po clean reset patikrinti 21 V2 lentelę ir 18 seed teritorijų.
2. Sukurti penkias skirtingų tipų gaujas ir patikrinti default roles.
3. Pakviesti, priimti, keisti rangą, priskirti atsakomybę ir pašalinti narį.
4. Iš dviejų klientų tuo pačiu metu bandyti išimti iždo pinigus.
5. Tabletėje patikrinti visus RBAC variantus bei admin-only veiksmus.
6. Užbaigti outdoor, interior, rescue, sabotage ir vehicle misijas.
7. Medium/Hard/Extreme patikrinti NPC bangas ir party role bonusą.
8. Atsijungti interjere bei su cargo/target ir grįžti per grace laiką.
9. Užpildyti inventory prieš reward; prisijungus turi pristatyti pending loot.
10. Drug sale bandyti neutralioje, svetimoje, netinkamo produkto ir savo teritorijoje.
11. Sukurti Enemy statusą, paskelbti karą, pakeisti roster ir patikrinti state laikus.
12. Tą patį war score idempotency key siųsti du kartus; įsirašo tik vienas.
13. Admin pakeisti owner, išjungti misiją ir atšaukti aktyvų karą.
14. Patikrinti audit, reputation, territory history, mission rewards ir war score ledger.

## Atliktos statinės patikros

- Visi Lua failai ir `fxmanifest.lua` sėkmingai parsinti su `luaparse`.
- `html/app.js` patikrintas su `node --check`.
- Manifesto 35 failų nuorodos egzistuoja.
- Rastos 30 unikalių mission family.
- Visos 21 schema lentelės turi atitinkamą clean-reset `DROP TABLE`.

Lokali MySQL binarinė programa šiame workspace neįdiegta, todėl tikras SQL apply ir
FiveM runtime smoke test turi būti atliktas testiniame serveryje prieš produkciją.
