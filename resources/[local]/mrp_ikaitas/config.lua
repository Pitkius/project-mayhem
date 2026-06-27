Config = {}

Config.MaxDistance = 3.0

--- Turi būti ištrauktas pistoletas (GROUP_PISTOL arba sąrašas žemiau).
Config.RequirePistolInHand = true

Config.PistolWeapons = {
    `weapon_pistol`,
    `weapon_pistol_mk2`,
    `weapon_combatpistol`,
    `weapon_appistol`,
    `weapon_pistol50`,
    `weapon_snspistol`,
    `weapon_snspistol_mk2`,
    `weapon_heavypistol`,
    `weapon_vintagepistol`,
    `weapon_flaregun`,
    `weapon_marksmanpistol`,
    `weapon_revolver`,
    `weapon_revolver_mk2`,
    `weapon_doubleaction`,
    `weapon_raypistol`,
    `weapon_ceramicpistol`,
    `weapon_navyrevolver`,
    `weapon_gadgetpistol`,
    `weapon_pistolxm3`,
}

Config.AnimDict = 'anim@gangops@hostage@'
Config.AnimAggressor = 'perp_idle'
Config.AnimVictim = 'victim_idle'
Config.AnimKillAggressor = 'perp_fail'

Config.Attach = {
    x = -0.24,
    y = 0.11,
    z = 0.0,
    rx = 0.5,
    ry = 0.5,
    rz = 0.0,
}

--- Valdymas (įkaitų takeris)
Config.KeyRelease = 47  -- G — paleisti (paliesti)
Config.KeyKill = 74     -- H — nusauti

Config.HelpText = '~g~G~s~ Paleisti įkaitą  |  ~r~H~s~ Nusauti įkaitą'
