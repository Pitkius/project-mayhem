Config = {}

-- Bendri nustatymai
Config.ServerName = 'MRP | MAYHEM RP'
Config.LogIpAddresses = false          -- IP identifikatoriai (GDPR / privatumas)
Config.RateLimitPerSecond = 4          -- Max webhook POST per sekunde
Config.QueueProcessInterval = 250      -- ms
Config.DefaultColor = 3447003           -- melyna
Config.EnableScreenshotOnDeath = false -- reikia screenshot-basic resurso

-- Discord webhook URL kiekvienam logu tipui (palik tuscia jei nenaudoji)
Config.Webhooks = {
    join_leave   = '',
    chat         = '',
    death        = '',
    revive       = '',
    admin        = '',
    spawn        = '',
    bank         = '',
    money        = '',
    inventory    = '',
    job          = '',
    warehouse    = '',
    gang         = '',
    mission      = '',
    vehicle      = '',
    security     = '',
}

-- Spalvos embedams
Config.Colors = {
    join_leave = 3066993,
    chat       = 9807270,
    death      = 15158332,
    revive     = 5763719,
    admin      = 15105570,
    spawn      = 10181046,
    bank       = 15844367,
    money      = 16776960,
    inventory  = 1752220,
    job        = 1146986,
    warehouse  = 2067276,
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
