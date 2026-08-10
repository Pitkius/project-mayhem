# Mayhem · Tebex kreditai (1€ = 1 CR)

## Schema

```
Žaidėjas → Tebex store (EUR) → FiveM native Tebex → konsolės komanda
  → mrp_credits → QBCore money.credits → Premium shop (importai / dėžės / VIP)
```

**Kursas:** `Config.EurToCredits = 1` → **1 EUR = 1 kreditas**.

## 1. Tebex Control Panel

1. Sukurk store (arba naudok esamą).
2. **Integrations → Game Servers → Connect** (FiveM native plugin).
3. Gausi secret key → įdėk į `cfg/00_base.cfg`:

```cfg
sv_tebexSecret "PASTE_SECRET_HERE"
```

4. Restart FXServer. Tebex turi parodyti serverį kaip connected.

## 2. Package’ai (kaina EUR = kreditų kiekis)

| Package pavadinimas | Kaina (EUR) | Komanda |
|---|---|---|
| 100 Kreditų | 100.00 | `mrp_credits tebex {id} {price} {transaction}` |
| 500 Kreditų | 500.00 | tas pats |
| 1000 Kreditų | 1000.00 | tas pats |
| 2500 Kreditų | 2500.00 | tas pats |
| 5000 Kreditų | 5000.00 | tas pats |

**Komandos nustatymai:**
- Be leading `/`
- **Require player online** = ON (rekomenduojama) arba OFF (offline queue pagal steam/license)
- Game server = tavo Mayhem serveris

`{price}` = package EUR kaina → serveris daro `credits = floor(price * 1)`.
`{transaction}` = unikalus Tebex txn (neleidžia double-grant).

Alternatyva fiksuotam kiekiui:
```
mrp_credits give {id} 1000 {transaction}
```

## 3. Serverio resursai

- `qb-core` → `MoneyTypes.credits = 0`
- `mrp_credits` — grant / spend / log lentelė `mrp_credit_transactions`
- `mrp_dashboard` — Premium shop nurašo CR (VIP, dėžės)

`ensure mrp_credits` prieš `mrp_dashboard` (`cfg/30_custom.cfg`).

## 4. Testas be Tebex

Konsolėje (txAdmin):
```
mrp_credits give 1 500 test-txn-001
```
arba žaidime admin:
```
/givecredits 1 500
```

ESC → Premium → balansas turi kilti. VIP / dėžė turi nuskaičiuoti CR.

## 5. Žaidėjams

- Vienintelis pirkimo kanalas: Tebex URL (`Config.TebexStoreUrl` / mygtukas **PIRKTI KREDITUS**)
- Jokio DM / crypto / pavedimo
- In-game tik leidžia **kreditus** (Premium)

## 6. Saugumas

- Idempotent `txn_id` DB
- Admin `/givecredits` tik ace `admin`
- Optional Discord webhook `Config.DiscordWebhook`
- Chargeback: Tebex merchant of record; loguose matosi txn → citizenid
