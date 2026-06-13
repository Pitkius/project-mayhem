InventoryAnim = InventoryAnim or {}

local invAnimActive = false
local invAnimToken = 0
local invProp = nil

local function loadAnimDict(dict)
    if not dict or dict == '' or HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do
        Wait(10)
    end
    return HasAnimDictLoaded(dict)
end

local function animCfg()
    return Config.InventoryAnimation or {}
end

local function canPlayInventoryAnim()
    local cfg = animCfg()
    if cfg.enabled == false then return false end

    local ped = PlayerPedId()
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end
    if IsEntityDead(ped) or IsPedDeadOrDying(ped, true) then return false end
    if IsPedRagdoll(ped) or IsPedFalling(ped) then return false end
    if cfg.disableInVehicle ~= false and IsPedInAnyVehicle(ped, false) then return false end
    if IsPedSwimming(ped) or IsPedSwimmingUnderWater(ped) then return false end
    return true
end

local function deleteInvProp()
    if invProp and DoesEntityExist(invProp) then
        DeleteEntity(invProp)
    end
    invProp = nil
end

local function attachInvProp(ped)
    local cfg = animCfg()
    if not cfg.useProp then return end

    deleteInvProp()
    local model = cfg.propModel or `p_michael_backpack_s`
    if type(model) == 'string' then model = joaat(model) end

    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do
        Wait(10)
    end
    if not HasModelLoaded(model) then return end

    local coords = GetEntityCoords(ped)
    invProp = CreateObject(model, coords.x, coords.y, coords.z, true, true, false)
    SetEntityCollision(invProp, false, false)
    local bone = GetPedBoneIndex(ped, cfg.propBone or 57005)
    local off = cfg.propOffset or { 0.12, -0.02, -0.02, 175.0, 120.0, 0.0 }
    AttachEntityToEntity(
        invProp,
        ped,
        bone,
        off[1] or 0.12,
        off[2] or -0.02,
        off[3] or -0.02,
        off[4] or 175.0,
        off[5] or 120.0,
        off[6] or 0.0,
        true,
        true,
        false,
        true,
        1,
        true
    )
    SetModelAsNoLongerNeeded(model)
end

function InventoryAnim.stop(playClose)
    if not invAnimActive and not invProp and playClose ~= true then return end

    invAnimActive = false
    invAnimToken = invAnimToken + 1
    local ped = PlayerPedId()
    ClearPedSecondaryTask(ped)
    deleteInvProp()

    if playClose ~= true or not canPlayInventoryAnim() then return end

    local cfg = animCfg()
    local close = cfg.close or {}
    local dict = close.dict or 'pickup_object'
    local anim = close.anim or 'putdown_low'
    if not loadAnimDict(dict) then return end

    TaskPlayAnim(ped, dict, anim, 4.0, -4.0, close.durationMs or 900, 0, 0.0, false, false, false)
end

function InventoryAnim.playOpen()
    local cfg = animCfg()
    if cfg.enabled == false or not canPlayInventoryAnim() then return end

    invAnimActive = true
    invAnimToken = invAnimToken + 1
    local token = invAnimToken
    local ped = PlayerPedId()

    CreateThread(function()
        local open = cfg.open or {}
        local openDict = open.dict or 'pickup_object'
        local openAnim = open.anim or 'pickup_low'
        if loadAnimDict(openDict) then
            TaskPlayAnim(ped, openDict, openAnim, 4.0, -4.0, open.durationMs or 850, 0, 0.0, false, false, false)
            Wait(open.durationMs or 850)
        end

        if invAnimToken ~= token or not invAnimActive then return end

        attachInvProp(ped)

        local idle = cfg.idle or {}
        local idleDict = idle.dict or 'clothingshirt'
        local idleAnim = idle.anim or 'try_shirt_positive_a'
        local idleFlag = idle.flag or 49
        if not loadAnimDict(idleDict) then
            idleDict = 'amb@prop_human_bum_bin@idle_b'
            idleAnim = 'idle_d'
            loadAnimDict(idleDict)
        end

        while invAnimActive and invAnimToken == token do
            ped = PlayerPedId()
            if not canPlayInventoryAnim() then
                invAnimActive = false
                break
            end
            if idleDict and idleAnim and not IsEntityPlayingAnim(ped, idleDict, idleAnim, 3) then
                TaskPlayAnim(ped, idleDict, idleAnim, 4.0, -4.0, -1, idleFlag, 0.0, false, false, false)
            end
            Wait(400)
        end

        if invAnimToken == token then
            deleteInvProp()
            ClearPedSecondaryTask(ped)
        end
    end)
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    InventoryAnim.stop(false)
end)
