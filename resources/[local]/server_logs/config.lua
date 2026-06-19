Config = {}

-- Bendri nustatymai
Config.ServerName = 'MRP | MAYHEM RP'
Config.LogIpAddresses = false          -- IP identifikatoriai (GDPR / privatumas)
Config.RateLimitPerSecond = 8          -- Max webhook POST per sekunde
Config.QueueProcessInterval = 150      -- ms
Config.DefaultColor = 3447003           -- melyna
Config.EnableScreenshotOnDeath = false -- reikia screenshot-basic resurso

-- Discord webhook URL — pilnas sąrašas webhooks.lua (sinchronizuok: tools/sync_server_log_webhooks.ps1)
Config.Webhooks = Config.Webhooks or {}

-- Spalvos embedams
Config.Colors = {
    join_leave = 3066993,
    chat       = 9807270,
    death      = 15158332,
    revive     = 5763719,
    admin      = 15105570,
    tx_admin   = 10181046,
    admin_actions = 16744228,
    reports    = 15844367,
    spawn      = 10181046,
    bank       = 15844367,
    money      = 16776960,
    inventory  = 1752220,
    job        = 1146986,
    warehouse  = 2067276,
    police     = 3447003,
    ems        = 5763719,
    mechanic   = 15105570,
    taxi       = 16776960,
    gang       = 9442302,
    mission    = 7419530,
    vehicle    = 3447003,
    security   = 16711680,
}

-- Chat filtrai
Config.BannedWords = {
    -- 'exampleword',
}

Config.BlockDiscordInvites = true

-- Saugumo / anti-cheat stiliaus logai (tik perspejimai)
Config.Security = {
  suspiciousMoneyThreshold = 500000,
  maxSpeedKmh = 350.0,
  blacklistedWeapons = {
    -- `WEAPON_RAILGUN`,
  },
  blacklistedVehicles = {
    -- `khanjali`,
  },
  blacklistedItems = {
    -- 'weapon_rpg',
  },
}

-- Admin komandos stebejimui (papildomai registruok per export)
Config.AdminCommands = {
    'bring', 'goto', 'tpm', 'noclip', 'revive', 'heal', 'car', 'dv',
    'setjob', 'setgang', 'giveitem', 'giveweapon', 'givemoney', 'setmoney',
    'ban', 'kick', 'warn', 'freeze', 'spectate', 'announce',
}
