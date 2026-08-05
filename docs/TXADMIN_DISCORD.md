# Discord botai — Mayhem RP

| Botas | Paskirtis | Token kur |
|-------|-----------|-----------|
| **MRP guardian** | Apsauga (anti-nuke), verify, logai, `/invite`, mod komandos, serverio priežiūra | `/home/fivem/.config/mrp-discord.env` (`BOT_USERNAME=MRP` arba `MRP guardian`) |
| **MRP admin** | txAdmin (status + Discord role allowlist) + vėliau muzika / admin utility Discord’e | Tik txAdmin panelė (+ atskiras env jei bus music botas) |

**Svarbu:** txAdmin **nepriima** boto su Kick/Ban/Manage*/Administrator. Todėl guardian ir admin — **skirtingi** application + tokenai.

---

## MRP guardian (dabartinis)

- Repo: `discord-system/guardian-bot`
- Servisas: `mrp-discord`
- Docs: `discord-system/README.md`

---

## MRP admin (naujas) — txAdmin

1. [Developer Portal](https://discord.com/developers/applications) → **New Application** → vardas **`MRP admin`**
2. Bot → Reset Token → nukopijuok
3. Bot → **Server Members Intent** ON
4. OAuth2 → URL Generator:
   - Scopes: `bot`, `applications.commands`
   - Permissions (minimaliai txAdmin’ui):
     - View Channels
     - Send Messages
     - Embed Links
     - Read Message History
   - Be Administrator / Kick / Ban / Manage*
5. Invite į Mayhem Discord
6. txAdmin → **Settings → Discord** → šito boto tokenas + Guild ID → Save
7. **Player Manager / Allowlist** → Discord Server Roles → Member (verified) role ID
8. Rejection text + Discord invite iš Guardian: `/invite status`

Muzikai / kitiems Discord dalykams vėliau galima **pridėti scopes/permissions** tam pačiam **MRP admin** (arba atskirą music resource) — bet **ne** duoti Administrator, jei vis dar naudojamas txAdmin’e.

---

## Allowlist trumpai

```
Player → txAdmin allowlist → Discord API
  → turi Member role? → taip: connect / ne: reject + invite
```

Guardian daro invite + verify; txAdmin (**MRP admin**) tikrina rolę join’e.
