DrugSellAnim = DrugSellAnim or {}

local busy = false

local PROGRESS_DISABLE = {
    disableMovement = true,
    disableCarMovement = true,
    disableCombat = true,
}

local function loadAnimDict(dict)
    if not dict or dict == '' then return false end
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do
        Wait(10)
    end
    return HasAnimDictLoaded(dict)
end

local function getAnimCfg()
    local cfg = Config.SellAnim or {}
    return {
        label = cfg.label or 'Sandoris su pirkėju...',
        durationMs = tonumber(cfg.durationMs) or 2800,
        faceMs = tonumber(cfg.faceMs) or 550,
        player = cfg.player or { dict = 'mp_common', clip = 'givetake1_a', flag = 49 },
        npc = cfg.npc or { dict = 'mp_common', clip = 'givetake1_b', flag = 49 },
    }
end

local function playPedAnim(ped, anim)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end
    if not loadAnimDict(anim.dict) then return false end
    TaskPlayAnim(ped, anim.dict, anim.clip, 4.0, 4.0, -1, anim.flag or 49, 0, false, false, false)
    return true
end

local function releaseNpc(npcEntity, wasFrozen)
    if not npcEntity or npcEntity == 0 or not DoesEntityExist(npcEntity) then return end
    if wasFrozen then
        FreezeEntityPosition(npcEntity, false)
    end
    ClearPedTasks(npcEntity)
end

function DrugSellAnim.isBusy()
    return busy
end

--- @param npcEntity number
--- @param onDone fun(ok: boolean)
function DrugSellAnim.play(npcEntity, onDone)
    if busy then
        if onDone then onDone(false) end
        return
    end

    local ped = PlayerPedId()
    if not npcEntity or npcEntity == 0 or not DoesEntityExist(npcEntity) or IsEntityDead(npcEntity) then
        if onDone then onDone(false) end
        return
    end

    local cfg = getAnimCfg()
    busy = true
    local npcFrozen = false

    TaskTurnPedToFaceEntity(ped, npcEntity, cfg.faceMs)
    TaskTurnPedToFaceEntity(npcEntity, ped, cfg.faceMs)
    Wait(math.min(cfg.faceMs, 400))

    if not DoesEntityExist(npcEntity) or IsEntityDead(npcEntity) then
        busy = false
        if onDone then onDone(false) end
        return
    end

    if #(GetEntityCoords(ped) - GetEntityCoords(npcEntity)) > 4.0 then
        busy = false
        if onDone then onDone(false) end
        return
    end

    ClearPedTasks(npcEntity)
    FreezeEntityPosition(npcEntity, true)
    npcFrozen = true
    playPedAnim(npcEntity, cfg.npc)

    DrugProgress.run(
        'fivempro_drug_sell',
        cfg.label,
        cfg.durationMs,
        false,
        false,
        PROGRESS_DISABLE,
        {
            animDict = cfg.player.dict,
            anim = cfg.player.clip,
            flags = cfg.player.flag,
        },
        function()
            releaseNpc(npcEntity, npcFrozen)
            busy = false
            if onDone then onDone(true) end
        end,
        function()
            releaseNpc(npcEntity, npcFrozen)
            busy = false
            if onDone then onDone(false) end
        end
    )
end

exports('PlayDrugSellAnim', DrugSellAnim.play)
exports('IsDrugSellAnimBusy', DrugSellAnim.isBusy)
