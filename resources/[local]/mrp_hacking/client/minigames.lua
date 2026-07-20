local QBCore = exports['qb-core']:GetCoreObject()

local physicalPromise = nil
local attachedProp = nil

local function loadAnimDict(dict)
    if not dict then return false end
    RequestAnimDict(dict)
    local t = 0
    while not HasAnimDictLoaded(dict) and t < 120 do
        Wait(10)
        t = t + 1
    end
    return HasAnimDictLoaded(dict)
end

local function loadModel(model)
    if type(model) == 'string' then model = joaat(model) end
    RequestModel(model)
    local t = 0
    while not HasModelLoaded(model) and t < 120 do
        Wait(10)
        t = t + 1
    end
    return HasModelLoaded(model)
end

local function clearProp()
    if attachedProp and DoesEntityExist(attachedProp) then
        DeleteEntity(attachedProp)
    end
    attachedProp = nil
end

local function startAnim(anim)
    if not anim or not anim.dict or not anim.name then return end
    local ped = PlayerPedId()
    if not loadAnimDict(anim.dict) then return end
    TaskPlayAnim(ped, anim.dict, anim.name, 3.0, 3.0, -1, anim.flags or 49, 0, false, false, false)
    if anim.prop and anim.prop.model then
        clearProp()
        local bone = anim.prop.bone or 57005
        local model = anim.prop.model
        if loadModel(model) then
            local coords = GetEntityCoords(ped)
            attachedProp = CreateObject(joaat(model), coords.x, coords.y, coords.z, true, true, false)
            local off = anim.prop.pos or vector3(0.0, 0.0, 0.0)
            local rot = anim.prop.rot or vector3(0.0, 0.0, 0.0)
            AttachEntityToEntity(attachedProp, ped, GetPedBoneIndex(ped, bone), off.x, off.y, off.z, rot.x, rot.y, rot.z, true, true, false, true, 1, true)
            SetModelAsNoLongerNeeded(joaat(model))
        end
    end
end

local function stopAnim()
    clearProp()
    ClearPedTasks(PlayerPedId())
end

--- Fiziniai minigame (ne hack sekos)
function RunPhysicalMinigame(mode, opts)
    opts = opts or {}
    if physicalPromise then return false end
    startAnim(opts.anim)

    --- Tikras GTA Online DRILLING scaleform
    if mode == 'drill' or mode == 'gtao_drill' or mode == 'native_drill' then
        PlaySoundFrontend(-1, 'Drill', 'DLC_HEIST_FLEECA_BANK_DRILLING_SOUNDS', true)
        local ok = exports['mrp_hacking']:RunNativeDrill()
        stopAnim()
        return ok == true
    end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'physicalOpen',
        mode = mode,
        label = opts.label or '',
        data = opts.data or {},
    })
    local p = promise.new()
    physicalPromise = p
    local ok = Citizen.Await(p)
    physicalPromise = nil
    stopAnim()
    SetNuiFocus(false, false)
    return ok == true
end

RegisterNUICallback('physicalResult', function(body, cb)
    cb('ok')
    if physicalPromise then
        physicalPromise:resolve(body and body.success == true)
    end
end)

RegisterNUICallback('physicalCancel', function(_, cb)
    cb('ok')
    if physicalPromise then
        physicalPromise:resolve(false)
    end
end)

--- Animacijos pagal vagystės fazę
Config = Config or {}
Config.RobberyAnims = Config.RobberyAnims or {
    hack = { dict = 'anim@heists@ornate_bank@hack', name = 'hack_loop', flags = 49 },
    card = { dict = 'anim@heists@keycard@', name = 'exit', flags = 49 },
    thermite = { dict = 'anim@heists@ornate_bank@thermal_charge', name = 'thermal_charge', flags = 49 },
    drill = {
        dict = 'anim@heists@fleeca_bank@drilling',
        name = 'drill_straight_idle',
        flags = 49,
        prop = { model = 'prop_tool_drill', bone = 57005, pos = vector3(0.14, 0.0, -0.01), rot = vector3(90.0, -90.0, 180.0) },
    },
    loot = {
        dict = 'anim@heists@ornate_bank@grab_cash',
        name = 'grab',
        flags = 1,
        prop = {
            model = 'hei_p_m_bag_var22_arm_s',
            bone = 57005,
            pos = vector3(0.0, 0.0, -0.16),
            rot = vector3(250.0, -30.0, 0.0),
        },
    },
    chain = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', name = 'machinic_loop_mechandplayer', flags = 49 },
    crack = { dict = 'anim@heists@ornate_bank@hack', name = 'hack_loop', flags = 49 },
}

Config.RobberyMinigames = Config.RobberyMinigames or {
    card = { mode = 'sequence', label = 'Perbrauk kortelę — rodyklės', data = { length = 4 } },
    thermite = { mode = 'hold', label = 'Laikyk SPACE termito zonoje', data = { holdMs = 2800 } },
    --- Tikras GTA Online Fleeca DRILLING scaleform
    drill = { mode = 'native_drill', label = 'Seifo gręžimas (GTA Online)', data = {} },
    loot = { mode = 'mash', label = 'Grabink pinigus — spam SPACE', data = { target = 22, timeMs = 9000 } },
    chain = { mode = 'sequence', label = 'Pritvirtink grandinę — rodyklės', data = { length = 5 } },
    atm_drill = { mode = 'native_drill', label = 'ATM gręžimas (GTA Online)', data = {} },
}

exports('RunPhysicalMinigame', RunPhysicalMinigame)
exports('PlayRobberyAnim', startAnim)
exports('StopRobberyAnim', stopAnim)
