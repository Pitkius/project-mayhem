local QBCore = exports['qb-core']:GetCoreObject()

local session = nil
local atmProp = nil
local dropBlip = nil

local function clearDropBlip()
    if dropBlip and DoesBlipExist(dropBlip) then RemoveBlip(dropBlip) end
    dropBlip = nil
end

local function clearAtmProp()
    if atmProp and DoesEntityExist(atmProp) then DeleteEntity(atmProp) end
    atmProp = nil
end

local function resetSession()
    if session and session.coords then
        TriggerServerEvent('fivempro_hacking:server:atmRelease', session.coords)
    end
    clearAtmProp()
    clearDropBlip()
    session = nil
end

local function vehicleAllowed(veh)
    if not veh or veh == 0 then return false end
    local cls = GetVehicleClass(veh)
    if Config.Atm.AllowedVehicleClasses[cls] == false then return false end
    return true
end

RegisterNetEvent('fivempro_hacking:client:hackSuccess', function(tierId, coords, ctx)
    if tierId ~= 'atm' or not session then return end
    session.phase = 'hacked'
    QBCore.Functions.Notify('ATM apsauga apeita. Gali gręžti.', 'success')
end)

RegisterNetEvent('fivempro_hacking:client:hackFailed', function(tierId)
    if tierId ~= 'atm' then return end
    resetSession()
end)

RegisterNetEvent('fivempro_hacking:client:atmDrillOk', function(coords)
    if not session then return end
    session.phase = 'drilled'
    QBCore.Functions.Notify('Pritvirtink grandinę (tow_chain).', 'primary')
end)

RegisterNetEvent('fivempro_hacking:client:atmChainOk', function(coords)
    if not session then return end
    session.phase = 'chained'
    QBCore.Functions.Notify('Sėsk į stiprią mašiną ir tempk ATM (vairuok ~50m).', 'primary')
    spawnPulledAtm()
end)

RegisterNetEvent('fivempro_hacking:client:atmGoCrack', function(dropIndex)
    if not session then return end
    session.phase = 'crack'
    session.dropIndex = dropIndex
    local drop = Config.Atm.Dropoffs[dropIndex]
    if drop then
        clearDropBlip()
        dropBlip = AddBlipForCoord(drop.coords.x, drop.coords.y, drop.coords.z)
        SetBlipSprite(dropBlip, 478)
        SetBlipColour(dropBlip, 1)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(drop.label or 'ATM drop')
        EndTextCommandSetBlipName(dropBlip)
        QBCore.Functions.Notify('Nuvežk ATM į saugią vietą ir išlaužk.', 'success')
    end
end)

RegisterNetEvent('fivempro_hacking:client:atmFinished', function()
    resetSession()
end)

function spawnPulledAtm()
    clearAtmProp()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then return end
    local model = joaat(Config.Atm.AttachedModel or 'prop_atm_01')
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end
    local vc = GetEntityCoords(veh)
    atmProp = CreateObject(model, vc.x, vc.y, vc.z - 1.0, true, true, false)
    AttachEntityToEntity(atmProp, veh, GetEntityBoneIndexByName(veh, 'boot'), 0.0, -1.8, 0.4, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
    session.pullStart = GetEntityCoords(veh)
end

local function startAtmSession(entity)
    local coords = GetEntityCoords(entity)
    QBCore.Functions.TriggerCallback('fivempro_hacking:server:atmCanStart', function(res)
        if not res or not res.ok then
            return QBCore.Functions.Notify((res and res.msg) or 'Negalima.', 'error')
        end
        session = { entity = entity, coords = { x = coords.x, y = coords.y, z = coords.z }, phase = 'idle' }
        TriggerServerEvent('fivempro_hacking:server:atmClaim', session.coords)
        exports['fivempro_hacking']:StartHack('atm', coords, function(ok)
            if not ok then resetSession() end
        end)
    end, { x = coords.x, y = coords.y, z = coords.z })
end

local function doDrill()
    if not session or session.phase ~= 'hacked' then return end
    QBCore.Functions.Progressbar('atm_drill', 'Gręžiamas bankomatas…', Config.Atm.DrillTimeMs or 18000, false, true, {
        disableMovement = true, disableCarMovement = true, disableCombat = true,
    }, { animDict = 'anim@heists@fleeca_bank@drilling', anim = 'drill_straight_idle', flags = 1 }, {}, {}, function()
        TriggerServerEvent('fivempro_hacking:server:atmDrillDone', session.coords)
    end, function()
        QBCore.Functions.Notify('Atšaukta.', 'error')
    end)
end

local function doChain()
    if not session or session.phase ~= 'drilled' then return end
    QBCore.Functions.Progressbar('atm_chain', 'Pritvirtinama grandinė…', 8000, false, true, {
        disableMovement = true, disableCombat = true,
    }, { animDict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', anim = 'machinic_loop_mechandplayer', flags = 1 }, {}, {}, function()
        TriggerServerEvent('fivempro_hacking:server:atmChainDone', session.coords)
    end, function() end)
end

local function tryPullComplete()
    if not session or session.phase ~= 'chained' or not session.pullStart then return end
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then return end
    if not vehicleAllowed(veh) then return end
    local dist = #(GetEntityCoords(veh) - vector3(session.pullStart.x, session.pullStart.y, session.pullStart.z))
    if dist < (Config.Atm.PullMinDistance or 45) then return end
    session.phase = 'delivered'
    local dropIdx = math.random(1, #(Config.Atm.Dropoffs or {}))
    TriggerServerEvent('fivempro_hacking:server:atmPulled', session.coords, dropIdx)
end

local function startCrackHack()
    exports['fivempro_hacking']:StartHack('atm', GetEntityCoords(PlayerPedId()), function(ok)
        TriggerServerEvent('fivempro_hacking:server:atmCrackResult', ok, not ok, session.dropIndex)
    end)
end

CreateThread(function()
    while true do
        if session and session.phase == 'chained' then
            tryPullComplete()
            Wait(500)
        else
            Wait(1200)
        end
    end
end)

CreateThread(function()
    while true do
        if session and session.phase == 'crack' and session.dropIndex then
            local drop = Config.Atm.Dropoffs[session.dropIndex]
            if drop then
                local p = GetEntityCoords(PlayerPedId())
                if #(p - drop.coords) < (drop.radius or 12) then
                    DrawMarker(1, drop.coords.x, drop.coords.y, drop.coords.z - 1.0, 0, 0, 0, 0, 0, 0, 2.5, 2.5, 1.0, 255, 80, 80, 120, false, false, 2, false, false, false, false)
                    if IsControlJustPressed(0, 38) then
                        startCrackHack()
                    end
                end
            end
            Wait(0)
        else
            Wait(600)
        end
    end
end)

CreateThread(function()
    exports['qb-target']:AddTargetModel(Config.Atm.Models, {
        options = {
            {
                icon = 'fas fa-laptop-code',
                label = 'ATM hack',
                canInteract = function() return not session end,
                action = function(entity) startAtmSession(entity) end,
            },
            {
                icon = 'fas fa-screwdriver',
                label = 'Gręžti ATM',
                canInteract = function() return session and session.phase == 'hacked' end,
                action = function() doDrill() end,
            },
            {
                icon = 'fas fa-link',
                label = 'Pritvirtinti grandinę',
                canInteract = function() return session and session.phase == 'drilled' end,
                action = function() doChain() end,
            },
        },
        distance = 1.8,
    })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    resetSession()
end)
