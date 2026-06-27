local cfgFace = Config.FacialAnim or {}
local faceDict = cfgFace.dict or 'mp_facial'
local faceAnim = cfgFace.anim or 'mic_chatter'
local gestureFlag = Config.GestureFlag or 49

local talking = false
local lastGestureAt = 0
local activeGesture = nil
local loadedDicts = {}

local function isOnRadio()
    if not Config.SkipWhenRadioActive then return false end
    return LocalPlayer.state.radioActive == true
end

local function canPlayGesture(ped)
    if isOnRadio() then return false end
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end
    if Config.DisableGesturesInVehicle and IsPedInAnyVehicle(ped, false) then return false end
    if IsPedRagdoll(ped) or IsPedFalling(ped) or IsPedSwimming(ped) then return false end
    if GetGameTimer() - lastGestureAt < (Config.GestureCooldownMs or 5500) then return false end
    return true
end

local function ensureAnimDict(dict)
    if loadedDicts[dict] then return true end
    RequestAnimDict(dict)
    local t = GetGameTimer() + 2500
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do
        Wait(0)
    end
    if HasAnimDictLoaded(dict) then
        loadedDicts[dict] = true
        return true
    end
    return false
end

local function getGesturePool(ped)
    if IsPedMale(ped) then
        return Config.GesturesMale or {}
    end
    return Config.GesturesFemale or Config.GesturesMale or {}
end

local function pickGesture(ped)
    local pool = getGesturePool(ped)
    if #pool == 0 then return nil end
    return pool[math.random(1, #pool)]
end

local function stopGesture(ped)
    if not activeGesture then return end
    if ped and DoesEntityExist(ped) then
        StopAnimTask(ped, activeGesture.dict, activeGesture.anim, 1.0)
    end
    activeGesture = nil
end

local function playGesture(ped, gesture)
    if not gesture or not canPlayGesture(ped) then return false end
    if not ensureAnimDict(gesture.dict) then return false end
    stopGesture(ped)
    local duration = gesture.duration or 2500
    TaskPlayAnim(ped, gesture.dict, gesture.anim, 8.0, -8.0, duration, gestureFlag, 0.0, false, false, false)
    activeGesture = { dict = gesture.dict, anim = gesture.anim }
    lastGestureAt = GetGameTimer()
    SetTimeout(duration + 100, function()
        if activeGesture and activeGesture.dict == gesture.dict and activeGesture.anim == gesture.anim then
            activeGesture = nil
        end
    end)
    return true
end

local function tryGesture(ped, chance)
    chance = tonumber(chance) or 0
    if chance <= 0 or math.random() > chance then return end
    local g = pickGesture(ped)
    if g then playGesture(ped, g) end
end

local function startFaceAnim(ped)
    PlayFacialAnim(ped, faceAnim, faceDict)
end

local function stopFaceAnim(ped)
    ClearFacialIdleAnimOverride(ped)
end

local function onTalkStart()
    if isOnRadio() then return end
    local ped = PlayerPedId()
    startFaceAnim(ped)
    tryGesture(ped, Config.GestureChanceOnStart or 0.22)
end

local function onTalkEnd()
    local ped = PlayerPedId()
    stopGesture(ped)
    stopFaceAnim(ped)
end

AddStateBagChangeHandler('radioActive', nil, function(bagName, _, value)
    local sid = tonumber(bagName:match('player:(%d+)'))
    if sid ~= GetPlayerServerId(PlayerId()) then return end
    if value then
        local ped = PlayerPedId()
        stopGesture(ped)
        stopFaceAnim(ped)
    end
end)

CreateThread(function()
    while GetResourceState('pma-voice') ~= 'started' do
        Wait(500)
    end

    local pollMs = Config.GesturePollMs or 900

    while true do
        local isTalking = NetworkIsPlayerTalking(PlayerId())

        if isTalking and not talking then
            talking = true
            onTalkStart()
        elseif not isTalking and talking then
            talking = false
            onTalkEnd()
        elseif talking and isTalking and not isOnRadio() then
            local ped = PlayerPedId()
            startFaceAnim(ped)
            if not activeGesture then
                tryGesture(ped, Config.GestureChanceWhileTalking or 0.08)
            end
        end

        Wait(pollMs)
    end
end)
