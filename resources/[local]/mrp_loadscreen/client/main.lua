--- Uždaryti loadscreen tik kai spawn.lua / QBCore baigia krauti žaidėją
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

local function restoreGameplayView(forceFadeIn)
    if IsCutsceneActive() then
        StopCutsceneImmediately()
    end
    DestroyAllCams(true)
    RenderScriptCams(false, false, 0, true, true)
    ClearFocus()
    ClearTimecycleModifier()
    ClearExtraTimecycleModifier()
    AnimpostfxStopAll()
    StopAudioScenes()
    if forceFadeIn and (IsScreenFadedOut() or IsScreenFadingOut()) then
        DoScreenFadeIn(0)
    end
    SetNuiFocus(false, false)
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
    local cfg = musicCfg()
    local startEv = cfg.startEvent or 'FM_INTRO_START'
    local stopEv = cfg.stopEvent or 'FM_INTRO_STOP'

    PrepareMusicEvent(stopEv)
    TriggerMusicEvent(stopEv)
    CancelMusicEvent(startEv)

    if cfg.audioScene then
        StopAudioScene(cfg.audioScene)
    end
    StopAudioScenes()
    musicStarted = false
end

local function closeLoadscreen()
    if closed then return end
    closed = true
    stopLoadingMusic()
    --- Tik muzika + NUI shutdown. Cam/fade atstatymą daro spawn/charcreator,
    --- kad čia nesunaikintume creator cam.
    ShutdownLoadingScreenNui()
    ShutdownLoadingScreen()
end

RegisterNetEvent('mrp_loadscreen:client:close', closeLoadscreen)

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

CreateThread(function()
    local deadline = GetGameTimer() + 120000
    while not closed and GetGameTimer() < deadline do
        if not musicStarted then
            startLoadingMusic()
        else
            return
        end
        Wait(sessionReady() and 0 or 50)
    end
end)

CreateThread(function()
    local deadline = GetGameTimer() + 120000
    while not closed and GetGameTimer() < deadline do
        if LocalPlayer.state.isLoggedIn then
            Wait(1500)
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
exports('RestoreGameplayView', function()
    restoreGameplayView(true)
end)