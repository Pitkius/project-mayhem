Config = Config or {}

Config.Branding = {
    title = 'Mayhem Roleplay',
    subtitle = 'Los Santos · Roleplay',
    logo = 'assets/mrp_logo.png',
    icon = 'assets/mrp_icon.png',
}

--- Tik sena GTA V teminė muzika (in-game audio event) — be NUI mp3
Config.LoadscreenMusic = {
    enabled = true,
    --- FM_INTRO_START = GTA Online intro / Los Santos tema
    startEvent = 'FM_INTRO_START',
    stopEvent = 'FM_INTRO_STOP',
    audioScene = 'MP_LEADERBOARD_SCENE',
}

--- NUI mp3 išjungta (nenaudojama)
Config.LoadscreenNuiMusic = {
    enabled = false,
}
