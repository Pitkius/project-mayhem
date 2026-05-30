Config = Config or {}

--- GTA V teminė muzika krovimosi metu (in-game audio event)
Config.LoadscreenMusic = {
    enabled = true,
    --- FM_INTRO_START = GTA Online intro / Los Santos tema
    startEvent = 'FM_INTRO_START',
    stopEvent = 'FM_INTRO_STOP',
    --- Papildomas ambient sluoksnis (nil = išjungta)
    audioScene = nil,
}

--- NUI mp3 (nebūtina) — įdėk html/assets/gta_theme.mp3 jei nori savo takelio
Config.LoadscreenNuiMusic = {
    enabled = true,
    volume = 0.28,
    track = 'assets/gta_theme.mp3',
}
