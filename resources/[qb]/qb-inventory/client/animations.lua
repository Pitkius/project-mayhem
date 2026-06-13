InventoryAnim = InventoryAnim or {}

local invAnimToken = 0

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

local function resolveActionCfg(action)
    local cfg = animCfg()
    local key = action or 'hand'
    local data = cfg[key] or cfg.hand or cfg.close or {}
    return {
        dict = data.dict or 'pickup_object',
        anim = data.anim or 'putdown_low',
        durationMs = data.durationMs or 450,
    }
end

function InventoryAnim.playHandAction(action)
    local cfg = animCfg()
    if cfg.enabled == false or not canPlayInventoryAnim() then return end

    invAnimToken = invAnimToken + 1
    local token = invAnimToken
    local step = resolveActionCfg(action)
    local ped = PlayerPedId()

    if not loadAnimDict(step.dict) then return end

    ClearPedSecondaryTask(ped)
    TaskPlayAnim(ped, step.dict, step.anim, 4.0, -4.0, step.durationMs, 0, 0.0, false, false, false)

    CreateThread(function()
        Wait(step.durationMs)
        if invAnimToken ~= token then return end
        if IsEntityPlayingAnim(ped, step.dict, step.anim, 3) then
            StopAnimTask(ped, step.dict, step.anim, 1.0)
        end
    end)
end

function InventoryAnim.stop(playClose)
    invAnimToken = invAnimToken + 1
    local ped = PlayerPedId()
    ClearPedSecondaryTask(ped)

    if playClose == true then
        InventoryAnim.playHandAction('close')
    end
end

function InventoryAnim.playOpen()
    InventoryAnim.playHandAction('open')
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    invAnimToken = invAnimToken + 1
    ClearPedSecondaryTask(PlayerPedId())
end)
