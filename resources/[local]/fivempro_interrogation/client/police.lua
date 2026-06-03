local QBCore = exports['qb-core']:GetCoreObject()

local function notify(msg, typ)
    QBCore.Functions.Notify(msg, typ or 'primary')
end

local function isPoliceOnDuty()
    local P = QBCore.Functions.GetPlayerData()
    if not P or not P.job then return false end
    return P.job.name == Config.PoliceJob and P.job.onduty == true
end

local function stationById(id)
    for _, st in ipairs(Config.PoliceStations or {}) do
        if st.id == id then return st end
    end
end

local function inStation(st)
    if not st then return false end
    local c = GetEntityCoords(PlayerPedId())
    return #(c - st.center) <= (st.radius or 14.0)
end

CreateThread(function()
    Wait(1500)
    for _, st in ipairs(Config.PoliceStations or {}) do
        exports['qb-target']:AddCircleZone(('police_interr_%s'):format(st.id), st.center, 1.8, {
            name = ('police_interr_%s'):format(st.id),
            useZ = true,
        }, {
            options = {
                {
                    icon = 'fas fa-user-shield',
                    label = 'Policijos apklausa',
                    action = function()
                        if not inStation(st) then return notify('Per toli.', 'error') end
                        TriggerEvent('fivempro_interrogation:client:startPickSuspect', {
                            locationKind = 'station',
                            locationId = st.id,
                            mode = 'police',
                        })
                    end,
                    canInteract = function()
                        return isPoliceOnDuty() and inStation(st)
                    end,
                },
                {
                    icon = 'fas fa-chair',
                    label = 'Pasodinti įtariamąjį',
                    action = function()
                        TriggerServerEvent('fivempro_interrogation:server:action', 'seat')
                    end,
                    canInteract = function()
                        return isPoliceOnDuty() and InterrogationActivePoliceLead and InterrogationActivePoliceLead(st.id)
                    end,
                },
            },
            distance = 2.3,
        })
    end
end)

function InterrogationActivePoliceLead(stationId)
    return InterrogationIsLeadAt('station', stationId)
end

function GetPoliceStation(id)
    return stationById(id)
end

RegisterNetEvent('fivempro_interrogation:client:showPoliceControls', function(on)
    SendNUIMessage({ action = 'policeControls', show = on == true })
    SetNuiFocus(on == true, on == true)
end)
