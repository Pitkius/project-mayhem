local QBCore = exports['qb-core']:GetCoreObject()

local policeBlips = {}

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

local function setBlipLabel(blip, label)
    local text = tostring(label or 'Policijos apklausa')
    if GetResourceState('fivempro_fonts') == 'started' then
        exports['fivempro_fonts']:SetBlipName(blip, text)
        return
    end
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(text)
    EndTextCommandSetBlipName(blip)
end

local function resolveStationBlip(st)
    if not Config.ShowBlips or not st then return nil end
    local custom = st.blip
    if custom == false or (type(custom) == 'table' and custom.enabled == false) then return nil end
    if type(custom) ~= 'table' then return nil end
    return {
        coords = custom.coords or st.center,
        sprite = custom.sprite or 60,
        color = custom.color or 29,
        scale = custom.scale or 0.85,
        shortRange = custom.shortRange ~= false,
        label = custom.label or st.label or 'Policijos apklausa',
    }
end

local function createPoliceBlips()
    for _, st in ipairs(Config.PoliceStations or {}) do
        local bc = resolveStationBlip(st)
        if not bc then goto continue end
        local blip = AddBlipForCoord(bc.coords.x, bc.coords.y, bc.coords.z)
        SetBlipSprite(blip, bc.sprite)
        SetBlipColour(blip, bc.color)
        SetBlipScale(blip, bc.scale)
        SetBlipAsShortRange(blip, bc.shortRange)
        setBlipLabel(blip, bc.label)
        policeBlips[#policeBlips + 1] = blip
        ::continue::
    end
end

CreateThread(function()
    Wait(1500)
    createPoliceBlips()
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

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, blip in ipairs(policeBlips) do
        if blip and DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    policeBlips = {}
end)
