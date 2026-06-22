--[[
  Gabz / įkeltų MLO žemėlapio blipai – koordinatės iš Gabz dokumentacijos (alexwilliam Gabz coords)
  ir resursų client.lua (interjero taškai). Policijos postai – fivempro_ltpd; VU – fivempro_stripclub.
]]

Config = {}

Config.ShortRange = true
Config.DefaultScale = 0.75

Config.Blips = {
    -- ── Medicina / valdžia ──
    { resource = 'cfx-gabz-pillbox', label = 'Pillbox ligoninė', coords = vec3(286.562, -570.565, 43.168), sprite = 61, color = 2 },
    { resource = 'cfx-gabz-pacificbank', label = 'Pacific Bank', coords = vec3(223.313, 208.295, 105.521), sprite = 108, color = 2 },
    { resource = 'cfx-gabz-townhall', label = 'Rotušė', coords = vec3(-541.0, -210.0, 37.0), sprite = 525, color = 3 },

    -- ── Verslai / pramogos ──
    { resource = 'cfx-gabz-tuners', label = 'Tuner Shop', coords = vec3(166.715, -3014.122, 5.888), sprite = 72, color = 5 },
    { resource = 'cfx-gabz-ottos', label = 'Otto\'s Auto', coords = vec3(793.0, -817.0, 27.0), sprite = 72, color = 46 },
    { resource = 'cfx-gabz-harmony', label = 'Harmony Repair', coords = vec3(1178.985, 2653.985, 37.862), sprite = 72, color = 46 },
    {
        resources = { 'cfx-gabz-carmeet', 'gabz_carmeet', 'gabz_lscarmeet' },
        label = 'Car Meet',
        coords = vec3(1113.974, -1806.528, 20.0346),
        sprite = 380,
        color = 46,
    },
    { resource = 'cfx-gabz-bowling', label = 'Bowling', coords = vec3(760.792, -777.724, 26.456), sprite = 103, color = 17 },
    {
        resources = { 'cfx-gabz-records', 'gabz_recordstudio', 'gabz_studio' },
        label = 'Record Studio',
        coords = vec3(478.999, -108.676, 63.155),
        sprite = 136,
        color = 27,
    },
    {
        resources = { 'cfx-gabz-hub', 'gabz_hub', 'cfx-gabz-bennys' },
        label = 'Benny\'s / Impound Hub',
        coords = vec3(-237.189, -1327.393, 31.299),
        sprite = 280,
        color = 0,
    },

    -- ── Pack 1 (papildomi) ──
    { resource = 'cfx-gabz-diner', label = 'Pop\'s Diner', coords = vec3(1576.905, 6451.104, 25.006), sprite = 93, color = 46 },
    { resource = 'cfx-gabz-haters', label = 'Rūbų parduotuvė', coords = vec3(-1127.176, -1439.432, 5.228), sprite = 73, color = 4 },
    { resource = 'cfx-gabz-hayes', label = 'Hayes Auto', coords = vec3(-1434.173, -441.539, 35.624), sprite = 72, color = 46 },

    -- ── Pack 2 (papildomi) ──
    { resource = 'cfx-gabz-lscustoms', label = 'LS Customs', coords = vec3(716.214, -1088.703, 22.365), sprite = 72, color = 3 },
    { resource = 'cfx-gabz-lost', label = 'Lost MC', coords = vec3(957.232, -143.250, 74.496), sprite = 226, color = 1 },
    { resource = 'cfx-gabz-prison', label = 'Bolingbroke kalėjimas', coords = vec3(1855.556, 2586.384, 45.673), sprite = 188, color = 29 },
    { resource = 'cfx-gabz-parkranger', label = 'Park Ranger', coords = vec3(388.640, 787.820, 187.474), sprite = 60, color = 25 },

    -- ── Pack 3 ──
    { resource = 'c-hunting_shop', label = 'Medžioklės parduotuvė', coords = vec3(-675.342, 5836.141, 22.056), sprite = 141, color = 25 },
    { resource = 'dynasty8', label = 'Dynasty 8', coords = vec3(-694.03, 273.51, 82.90), sprite = 374, color = 2 },
    -- druglabs MLO (MrBrown 4× pack) — exterior įėjimai; vienas blip po žeme žemėlapyje nematomas
    { resource = 'druglabs', label = 'Narkotikų lab. (Grapeseed)', coords = vec3(1957.74, 5172.45, 47.91), sprite = 499, color = 1 },
    { resource = 'druglabs', label = 'Narkotikų lab. (La Mesa)', coords = vec3(892.26, -960.85, 38.18), sprite = 499, color = 6 },
    { resource = 'druglabs', label = 'Narkotikų lab. (Uostas)', coords = vec3(-341.86, -2444.32, 6.00), sprite = 499, color = 1 },
    { resource = 'druglabs', label = 'Narkotikų lab. (LS)', coords = vec3(-1366.68, -316.94, 38.29), sprite = 499, color = 6 },
    { resource = 'druglabs', label = 'Narkotikų sandėlis (LS uostas)', coords = vec3(1009.54, -3196.64, 14.00), sprite = 499, color = 1 },
    { resource = 'sc_secret_drug', label = 'Secret Meth Lab', coords = vec3(2719.0, 5204.7, 49.64), sprite = 499, color = 6 },
    { resource = 'weapon_warehouse', label = 'Ginklų sandėlis', coords = vec3(-1143.28, 4944.29, 221.27), sprite = 473, color = 1 },
    { resource = 'sc1_29_motel', label = 'Davis Motel', coords = vec3(356.2, -1800.96, 28.85), sprite = 475, color = 48 },
    { resource = 'fivempro_motel', label = 'Motelio sandėlis', coords = vec3(-1273.8059, 316.0920, 65.5118), sprite = 473, color = 48 },
}
