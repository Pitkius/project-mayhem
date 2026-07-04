# Discord + FiveM Logging System

Pilna Discord apsaugos ir FiveM logų sistema projektui **FIVEMPROJEKTAS**.

## Struktūra

```
discord-system/
└── guardian-bot/          # Discord.js v14 botas (anti-nuke + logai + moderacija)
    ├── src/
    │   ├── antinuke/      # Threshold sistema, baudimas
    │   ├── commands/      # Slash komandos
    │   ├── database/      # SQLite
    │   ├── events/        # Discord eventai
    │   └── logs/          # Log dispatcher
    └── deploy-commands.js

resources/[local]/server_logs/   # FiveM webhook logai
    ├── config.lua
    ├── modules/           # Logų moduliai pagal kategoriją
    └── integrations/      # QBCore / ESX pavyzdžiai
```

---

## 1. Discord Guardian Bot

### Reikalavimai
- Node.js 18+
- Discord Application + Bot Token

### Discord Developer Portal
1. Eik į https://discord.com/developers/applications
2. **New Application** → sukurk app
3. **Bot** → **Reset Token** → nukopijuok token
4. Įjunk **Privileged Gateway Intents**:
   - Server Members Intent
   - Message Content Intent
   - **Presence Intent** (Discord narių skaičiui voice kanale)
   - (Rekomenduojama) visi intents, kurių prašo botas
5. **OAuth2 → URL Generator**:
   - Scopes: `bot`, `applications.commands`
   - Bot Permissions: `Administrator` (arba: Manage Channels, Manage Roles, Ban/Kick, Moderate, View Audit Log, Manage Messages)
6. Atidaryk sugeneruotą URL ir pridėk botą į serverį

### Instaliacija

```bash
cd discord-system/guardian-bot
copy .env.example .env
# Redaguok .env — įrašyk DISCORD_TOKEN ir DISCORD_CLIENT_ID
npm install
npm run branding
npm run deploy
npm start
```

`npm run branding` nustato boto vardą **MRP** ir profilinę iš `assets/avatar.png` (MAYHEM RP logo).

### Pirmas paleidimas Discord serveryje

1. `/setup` — inicializuoja guild, **automatiškai sukuria logų kategorijas ir kanalus** po `Admin-logai`
2. Arba vėliau perkurti: `/setuplogs`
3. FiveM webhook URL nukopijuok iš `guardian-bot/data/fivem-webhooks-{GUILD_ID}.lua` → `server_logs/config.lua`
4. `/whitelist add` — pridėk owner/trusted admin ID
5. `/antinuke settings` — peržiūrėk threshold

### Gyvas Discord narių skaičius (voice kanalas „Gyventojai“)

Botas atnaujina voice kanalo pavadinimą pagal **Discord serverio narių** skaičių (ne FiveM).

1. Botui reikia teisės **Manage Channels**
2. Developer Portal → Bot → įjunk **Server Members Intent** ir **Presence Intent**
3. `.env`:
   - `DISCORD_STATS_ENABLED=true`
   - `DISCORD_STATS_CHANNEL_ID=` — voice kanalo ID
   - `DISCORD_STATS_CHANNEL_TEMPLATE=Gyventojai: {members}` (arba `{online}` prisijungusiems)
4. Perkrauk botą: `npm start`

Šablonai: `{members}` visi nariai, `{online}` prisijungę dabar.

### Pasitvirtinimas (oro-uostas + ✅ / 🔔)

Nauji nariai mato tik **oro-uostas** ir **pasitvirtinimas**. Reakcijos duoda jau sukurtas roles.

1. Sukurk roles Discord (pvz. `Member`, `Ping`, optional `Unverified`)
2. Bot rolė turi būti **aukščiau** už tas roles (Server Settings → Roles)
3. Paleisk serveryje:
   ```
   /setupverify config verified_role:@Member ping_role:@Ping unverified_role:@Unverified
   /setupverify permissions
   /setupverify post
   ```
4. Kanalai randami pagal pavadinimą (`oro-uostas`, `pasitvirtinimas`) arba pasirenki ranka

| Reakcija | Rolė |
|----------|------|
| ✅ | Verified — mato visą serverį |
| 🔔 | Ping — pranešimų rolė (įjungti/išjungti) |

Jei reakcijos neveikia po senesnės formos: `/setupverify sync`

### Logų struktūra (auto-sukuriama)

Po kategorijos **📋 Admin-logai**:

| Kategorija | Kanalai |
|------------|---------|
| Discord · Saugumas | mod, antinuke, security |
| Discord · Žinutės | message |
| Discord · Nariai | member, join, role |
| Discord · Serveris | channel, voice, webhook |
| FiveM · Žaidėjai | join_leave, chat, death, revive, spawn |
| FiveM · Ekonomika | bank, money, inventory, warehouse |
| FiveM · Frakcijos | job, gang, mission |
| FiveM · Frakcijų sandėliai | police, ems, mechanic, taxi |
| FiveM · Transportas | vehicle |
| FiveM · Admin | admin, **tx_admin**, **admin_actions**, **reports**, security |

### Slash komandos
`setup`, `setuplogs`, `setlogchannel`, `setupverify`, `whitelist`, `antinuke`, `ban`, `kick`, `timeout`, `warn`, `warnings`, `clearwarnings`, `purge`, `lock`, `unlock`, `slowmode`, `serverinfo`, `userinfo`

---

## 2. FiveM server_logs Resource

### Instaliacija

1. Resource jau yra: `resources/[local]/server_logs/`
2. `cfg/30_custom.cfg` turi `ensure server_logs`
3. Redaguok `config.lua` — įrašyk Discord webhook URL kiekvienam tipui

### Webhook kūrimas Discord

1. Server Settings → Integrations → Webhooks → New Webhook
2. Pasirink kanalą (pvz. `#fivem-death-logs`)
3. Nukopijuok URL į `Config.Webhooks.death`

### Logų kanalai (rekomenduojama)
- `#fivem-join-leave`
- `#fivem-chat-logs`
- `#fivem-death-logs`
- `#fivem-revive-logs`
- `#fivem-admin-logs`
- `#fivem-spawn-logs`
- `#fivem-bank-logs`
- `#fivem-money-logs`
- `#fivem-inventory-logs`
- `#fivem-job-logs`
- `#fivem-warehouse-logs`
- `#fivem-gang-logs`
- `#fivem-mission-logs`
- `#fivem-vehicle-logs`
- `#fivem-security-logs`

### Integracija į kitus scriptus

**Export:**
```lua
exports['server_logs']:SendCustomLog('admin', 'Title', 'Message', source)
exports['server_logs']:SendLog('money', 'Bank', 'Deposit $5000', {
    { name = 'Amount', value = '5000', inline = true },
}, source)
```

**Event:**
```lua
TriggerEvent('server_logs:sendLog', 'inventory', 'Item Added', 'bread x5', source, nil)
TriggerEvent('server_logs:inventoryAdd', 'bread', 5, 'shop')
TriggerEvent('server_logs:playerDeath', { victim = src, killer = killerId, weapon = hash })
```

### Naujos logų kategorijos pridėjimas

1. `config.lua` → `Config.Webhooks.naujas = 'URL'`
2. `config.lua` → `Config.Colors.naujas = 123456`
3. Naudok `SendLog('naujas', ...)` arba sukurk `modules/naujasLogs.lua`
4. Pridėk į `fxmanifest.lua` server_scripts

---

## Saugumas

- Webhook URL **tik** `config.lua` / `.env` — ne hardcode
- Tuščias webhook = logas praleidžiamas (be klaidos)
- Rate limit queue apsaugo nuo Discord spam
- Security logai — tik perspėjimai, ne auto-ban (konfigūruojama)

---

## Paleidimas (santrauka)

| Komponentas | Komanda |
|-------------|---------|
| Discord bot | `cd discord-system/guardian-bot && npm start` |
| Deploy commands | `npm run deploy` |
| FiveM | `ensure server_logs` server.cfg |

Žiūrėk `TODO.md` dėl būsimų patobulinimų.
