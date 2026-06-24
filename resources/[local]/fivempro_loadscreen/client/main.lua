--- Uždaryti loadscreen tik kai spawnfix / QBCore baigia krauti žaidėją
local closed = false
local musicStarted = false

local function musicCfg()
    return Config.LoadscreenMusic or {}
end

local function sessionReady()
    if NetworkIsSessionStarted() then return true end
    if NetworkIsPlayerConnected(PlayerId()) then return true end
    return false
end

local function startLoadingMusic()
    local cfg = musicCfg()
    if musicStarted or cfg.enabled == false then return end
    if not sessionReady() then return end

    musicStarted = true

    SetFrontendRadioActive(false)
    SetUserRadioControlEnabled(false)
    SetMobileRadioEnabledDuringGameplay(false)

    if cfg.audioScene then
        StartAudioScene(cfg.audioScene)
    end

    local startEv = cfg.startEvent or 'FM_INTRO_START'
    PrepareMusicEvent(startEv)
    TriggerMusicEvent(startEv)
end

local function stopLoadingMusic()
    if not musicStarted then return end
    musicStarted = false

    local cfg = musicCfg()
    local startEv = cfg.startEvent or 'FM_INTRO_START'
    local stopEv = cfg.stopEvent or 'FM_INTRO_STOP'

    PrepareMusicEvent(stopEv)
    TriggerMusicEvent(stopEv)
    CancelMusicEvent(startEv)

    if cfg.audioScene then
        StopAudioScene(cfg.audioScene)
    end
end

local function closeLoadscreen()
    if closed then return end
    closed = true
    stopLoadingMusic()
    ShutdownLoadingScreenNui()
    ShutdownLoadingScreen()
end

RegisterNetEvent('fivempro_loadscreen:client:close', closeLoadscreen)

RegisterNUICallback('loadscreenReady', function(_, cb)
    startLoadingMusic()
    cb('ok')
end)

RegisterNUICallback('setLoadscreenMusic', function(data, cb)
    if data and data.enabled then
        startLoadingMusic()
    else
        stopLoadingMusic()
    end
    cb('ok')
end)

--- Bandome paleisti kai sesija pasiruošusi; Wait(0) kai jau ready — kuo greičiau.
CreateThread(function()
    local deadline = GetGameTimer() + 120000
    while not closed and GetGameTimer() < deadline do
        if not musicStarted then
            startLoadingMusic()
        end
        if musicStarted then return end
        Wait(sessionReady() and 0 or 50)
    end
end)

CreateThread(function()
    local deadline = GetGameTimer() + 120000
    while not closed and GetGameTimer() < deadline do
        if LocalPlayer.state.isLoggedIn then
            Wait(3000)
            closeLoadscreen()
            return
        end
        Wait(500)
    end
    if not closed then
        closeLoadscreen()
    end
end)

exports('CloseLoadscreen', closeLoadscreen)
