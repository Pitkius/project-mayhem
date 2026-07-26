Config = Config or {}

Config.Branding = {
    title = 'Mayhem Roleplay',
    subtitle = 'Los Santos · Roleplay',
    logo = 'assets/mrp_logo.png',
    icon = 'assets/mrp_icon.png',
}

--- Native FM_INTRO is disabled: it often leaves a grey/black screen after spawn on FiveM.
--- Put html/assets/gta_theme.mp3 if you want NUI music during loading.
Config.LoadscreenMusic = {
    enabled = false,
    startEvent = 'FM_INTRO_START',
    stopEvent = 'FM_INTRO_STOP',
    audioScene = nil,
}

Config.LoadscreenNuiMusic = {
    enabled = true,
    volume = 0.28,
    track = 'assets/gta_theme.mp3',
}
