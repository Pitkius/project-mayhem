local cfgAnim = Config.TalkAnim or {}
local cfgFace = Config.FacialAnim or {}
local dict = cfgAnim.dict or 'random@arrests'
local anim = cfgAnim.anim or 'generic_radio_chatter'
local flag = cfgAnim.flag or 49
local faceDict = cfgFace.dict or 'mp_facial'
local faceAnim = cfgFace.anim or 'mic_chatter'

local talking = false
local dictLoaded = false

local function isOnRadio()
    if not Config.SkipWhenRadioActive then return false end
    return LocalPlayer.state.radioActive == true
end

local function ensureDict()
    if dictLoaded then return true end
    RequestAnimDict(dict)
    local t = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do
        Wait(0)
    end
    dictLoaded = HasAnimDictLoaded(dict)
    return dictLoaded
end

local function startTalkVisuals()
    if isOnRadio() then return end
    local ped = PlayerPedId()
    if ensureDict() and not IsEntityPlayingAnim(ped, dict, anim, 3) then
        TaskPlayAnim(ped, dict, anim, 8.0, -8.0, -1, flag, 0.0, false, false, false)
    end
    PlayFacialAnim(ped, faceAnim, faceDict)
end

local function stopTalkVisuals()
    local ped = PlayerPedId()
    if dictLoaded then
        StopAnimTask(ped, dict, anim, 1.0)
    end
    ClearFacialIdleAnimOverride(ped)
end

CreateThread(function()
    while GetResourceState('pma-voice') ~= 'started' do
        Wait(500)
    end
    while true do
        local isTalking = NetworkIsPlayerTalking(PlayerId())
        if isTalking and not talking then
            talking = true
            startTalkVisuals()
        elseif not isTalking and talking then
            talking = false
            stopTalkVisuals()
        elseif talking and isTalking and not isOnRadio() then
            local ped = PlayerPedId()
            if dictLoaded and not IsEntityPlayingAnim(ped, dict, anim, 3) then
                TaskPlayAnim(ped, dict, anim, 8.0, -8.0, -1, flag, 0.0, false, false, false)
            end
        end
        Wait(80)
    end
end)
