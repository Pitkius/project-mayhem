local QBCore = exports['qb-core']:GetCoreObject()

local searchAnimActive = false

local function notify(msg, typ)
    QBCore.Functions.Notify(msg, typ or 'primary')
end

local function getTargetServerId(entity)
    if not entity or entity == 0 then return nil end
    local idx = NetworkGetPlayerIndexFromPed(entity)
    if idx == -1 then return nil end
    return GetPlayerServerId(idx)
end

local function isEntityDown(ped)
    if not ped or ped == 0 then return false end
    if IsEntityDead(ped) or IsPedDeadOrDying(ped, true) then return true end
    local idx = NetworkGetPlayerIndexFromPed(ped)
    if idx == -1 then return false end
    local st = Player(idx).state
    return st and (st.isDead == true or st.dead == true)
end

local function targetHandsUp(ped)
    if not ped or ped == 0 then return false end
    if IsEntityPlayingAnim(ped, 'missminuteman_1ig_2', 'handsup_base', 3) then return true end
    local idx = NetworkGetPlayerIndexFromPed(ped)
    if idx == -1 then return false end
    return Player(idx).state.handsUp == true
end

local function targetRestrained(ped)
    local idx = NetworkGetPlayerIndexFromPed(ped)
    if idx == -1 then return false end
    return Player(idx).state.ltpdCuffed == true
end

local function restraintTypeOf(ped)
    local idx = NetworkGetPlayerIndexFromPed(ped)
    if idx == -1 then return nil end
    return Player(idx).state.mrpRestraintType
end

local function canSearchEntity(entity)
    if not entity or entity == PlayerPedId() then return false end
    if targetRestrained(entity) then return true end
    if isEntityDown(entity) then return true end
    return targetHandsUp(entity)
end

local function canApplyRestraintEntity(entity)
    if not entity or entity == PlayerPedId() then return false end
    if targetRestrained(entity) then return false end
    if isEntityDown(entity) then return true end
    return targetHandsUp(entity)
end

local function playSearchLoop()
    searchAnimActive = true
    local cfg = Config.Search.loopAnim or Config.Search.anim
    CreateThread(function()
        local dict = cfg.dict
        local clip = cfg.clip
        local flag = cfg.flag or 49
        RequestAnimDict(dict)
        while not HasAnimDictLoaded(dict) and searchAnimActive do Wait(10) end
        local ped = PlayerPedId()
        while searchAnimActive do
            if not IsEntityPlayingAnim(ped, dict, clip, 3) then
                TaskPlayAnim(ped, dict, clip, 2.0, 2.0, -1, flag, 0.0, false, false, false)
            end
            Wait(800)
        end
        ClearPedTasks(ped)
    end)
end

RegisterNetEvent('mrp_restraints:client:restrainedState', function(state, rType)
    LocalPlayer.state:set('ltpdCuffed', state, true)
    LocalPlayer.state:set('mrpRestraintType', state and rType or nil, true)
    local ped = PlayerPedId()
    if state then
        if GetResourceState('qb-smallresources') == 'started' then
            pcall(function() exports['qb-smallresources']:resetHandsupState() end)
        end
        RequestAnimDict('mp_arresting')
        while not HasAnimDictLoaded('mp_arresting') do Wait(10) end
        TaskPlayAnim(ped, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0.0, false, false, false)
    else
        ClearPedTasks(ped)
    end
end)

RegisterNetEvent('mrp_restraints:client:startSearchAnim', function()
    playSearchLoop()
end)

RegisterNetEvent('mrp_restraints:client:stopSearchAnim', function()
    searchAnimActive = false
end)

RegisterNetEvent('qb-inventory:client:closeInv', function()
    if searchAnimActive then
        searchAnimActive = false
        TriggerServerEvent('mrp_restraints:server:searchAnimStopped')
    end
end)

CreateThread(function()
    while true do
        if LocalPlayer.state.ltpdCuffed then
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 22, true)
            DisableControlAction(0, 23, true)
            DisableControlAction(0, 75, true)
            Wait(0)
        else
            Wait(400)
        end
    end
end)

CreateThread(function()
    while true do
        if LocalPlayer.state.ltpdCuffed then
            local ped = PlayerPedId()
            if not IsEntityPlayingAnim(ped, 'mp_arresting', 'idle', 3) then
                RequestAnimDict('mp_arresting')
                while not HasAnimDictLoaded('mp_arresting') do Wait(10) end
                TaskPlayAnim(ped, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0.0, false, false, false)
            end
            Wait(1200)
        else
            Wait(800)
        end
    end
end)

local function runSearch(entity)
    local targetId = getTargetServerId(entity)
    if not targetId then return end
    QBCore.Functions.TriggerCallback('mrp_restraints:server:canSearch', function(ok, msg)
        if not ok then return notify(msg or 'Negalima apieškoti.', 'error') end
        local cfg = Config.Search
        local done = RestraintProgress('mrp_search', cfg.label, cfg.progressMs, true, cfg.anim)
        if not done then return notify('Apieškojimas atšauktas.', 'error') end
        TriggerServerEvent('mrp_restraints:server:searchPlayer', targetId)
    end, targetId)
end

local function runRestrain(entity, rType, removing)
    local targetId = getTargetServerId(entity)
    if not targetId then return end
    local cfg = Config.Restraints[rType]
    if not cfg then return end
    QBCore.Functions.TriggerCallback('mrp_restraints:server:canRestrain', function(ok, msg)
        if not ok then return notify(msg or 'Negalima.', 'error') end
        local label = removing and cfg.removeLabel or cfg.applyLabel
        local done = RestraintProgress('mrp_restrain_' .. rType, label, cfg.progressMs, true, cfg.applyAnim)
        if not done then return notify('Atšaukta.', 'error') end
        TriggerServerEvent('mrp_restraints:server:toggleRestraint', targetId, rType)
    end, targetId, rType, removing)
end

CreateThread(function()
    Wait(2500)
    local options = {
        {
            icon = 'fas fa-search',
            label = 'Apieškoti',
            canInteract = function(entity)
                return canSearchEntity(entity)
            end,
            action = function(entity)
                runSearch(entity)
            end,
        },
        {
            icon = 'fas fa-handcuffs',
            label = 'Uždėti antrankius',
            item = Config.Restraints.handcuffs.item,
            canInteract = function(entity)
                return canApplyRestraintEntity(entity)
            end,
            action = function(entity)
                runRestrain(entity, 'handcuffs', false)
            end,
        },
        {
            icon = 'fas fa-link',
            label = 'Surišti virve',
            item = Config.Restraints.rope.item,
            canInteract = function(entity)
                return canApplyRestraintEntity(entity)
            end,
            action = function(entity)
                runRestrain(entity, 'rope', false)
            end,
        },
        {
            icon = 'fas fa-user-lock',
            label = 'Surišti dirželiais',
            item = Config.Restraints.ziptie.item,
            canInteract = function(entity)
                return canApplyRestraintEntity(entity)
            end,
            action = function(entity)
                runRestrain(entity, 'ziptie', false)
            end,
        },
        {
            icon = 'fas fa-unlock',
            label = 'Nuimti surakymą',
            canInteract = function(entity)
                return targetRestrained(entity)
            end,
            action = function(entity)
                local rType = restraintTypeOf(entity) or 'handcuffs'
                runRestrain(entity, rType, true)
            end,
        },
    }

    exports['qb-target']:AddGlobalPlayer({
        options = options,
        distance = Config.MaxDistance or 2.5,
    })
end)

exports('IsLocalRestrained', function()
    return LocalPlayer.state.ltpdCuffed == true
end)

exports('GetLocalRestraintType', function()
    return LocalPlayer.state.mrpRestraintType
end)
