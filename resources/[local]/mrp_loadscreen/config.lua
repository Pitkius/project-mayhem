Config = Config or {}

Config.Branding = {
    title = 'Mayhem Roleplay',
    subtitle = 'Los Santos · Roleplay',
    logo = 'assets/mrp_logo.png',
    icon = 'assets/mrp_icon.png',
}

--- GTA V teminė muzika krovimosi metu (in-game audio event)
Config.LoadscreenMusic = {
    enabled = true,
    --- FM_INTRO_START = GTA Online intro / Los Santos tema
    startEvent = 'FM_INTRO_START',
    stopEvent = 'FM_INTRO_STOP',
    --- Padeda FM_INTRO_START groti krovimosi metu (ne laukiant pilno spawn).
    audioScene = 'MP_LEADERBOARD_SCENE',
}

--- NUI mp3 — paleidžiama kai atsiranda loadscreen (rekomenduojama).
--- Įdėk failą: resources/[local]/mrp_loadscreen/html/assets/gta_theme.mp3
--- Palaikoma: .mp3 (geriausiai), kartais .ogg
Config.LoadscreenNuiMusic = {
    enabled = true,
    volume = 0.28,
    track = 'assets/gta_theme.mp3',
}
