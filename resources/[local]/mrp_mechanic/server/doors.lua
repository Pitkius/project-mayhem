local QBCore = exports['qb-core']:GetCoreObject()

local MechDoorLocked = {}
local MechDoorMeta = {}
local MechDoorToggleCooldown = {}

local function isMechanicOnDuty(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    local j = Player.PlayerData.job
    return j and j.name == Config.JobName and j.onduty == true
end

local function initMechDoors()
    for _, g in ipairs(Config.DoorGroups or {}) do
        MechDoorMeta[g.id] = {
            interact = g.interact,
            interactDist = g.interactDist or 4.0,
        }
        if MechDoorLocked[g.id] == nil then
            MechDoorLocked[g.id] = g.defaultLocked ~= false
        end
    end
end

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    initMechDoors()
end)

AddEventHandler('playerDropped', function()
    local src = source
    MechDoorToggleCooldown[src] = nil
end)

RegisterNetEvent('mrp_mechanic:server:requestDoorsSync', function()
    TriggerClientEvent('mrp_mechanic:client:syncDoors', source, MechDoorLocked)
end)

RegisterNetEvent('mrp_mechanic:server:toggleDoorGroup', function(groupId, wantLocked)
    local src = source
    if type(groupId) ~= 'string' then return end
    if not isMechanicOnDuty(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Tik mechanikams tarnyboje.', 'error')
    end
    local meta = MechDoorMeta[groupId]
    if not meta then
        return TriggerClientEvent('QBCore:Notify', src, 'Durų duomenys dar kraunami — palauk kelias sekundes.', 'error')
    end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local pc = GetEntityCoords(ped)
    local reach = (Config.DoorToggleReach or 5.0) + 0.5
    local interactReach = math.max(meta.interactDist or 4.0, Config.DoorToggleReach or 5.0) + 0.5
    if not meta.interact or #(pc - meta.interact) > interactReach then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo durų.', 'error')
    end
    local now = GetGameTimer()
    if (MechDoorToggleCooldown[src] or 0) > now then return end
    MechDoorToggleCooldown[src] = now + 650
    local cur = MechDoorLocked[groupId] ~= false
    if wantLocked == true or wantLocked == 1 then
        MechDoorLocked[groupId] = true
    elseif wantLocked == false or wantLocked == 0 then
        MechDoorLocked[groupId] = false
    else
        MechDoorLocked[groupId] = not cur
    end
    if MechDoorLocked[groupId] == cur then
        return TriggerClientEvent('mrp_mechanic:client:setDoorState', src, groupId, cur)
    end
    TriggerClientEvent('mrp_mechanic:client:setDoorState', -1, groupId, MechDoorLocked[groupId])
    TriggerClientEvent(
        'QBCore:Notify',
        src,
        MechDoorLocked[groupId] and 'Durys užrakintos.' or 'Durys atrakintos.',
        'primary'
    )
end)

initMechDoors()
