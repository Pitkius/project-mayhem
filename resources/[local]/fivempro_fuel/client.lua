local QBCore = exports['qb-core']:GetCoreObject()

local pumping = false
local currentPump = nil
local lastPayResult = { ok = false }

RegisterNetEvent('fivempro_fuel:client:payResult', function(res)
    lastPayResult = res or { ok = false }
end)

local function createFuelBlips()
    for _, s in ipairs(Config.Stations or {}) do
        local blip = AddBlipForCoord(s.x + 0.0, s.y + 0.0, s.z + 0.0)
        SetBlipSprite(blip, Config.BlipSprite or 361)
        SetBlipScale(blip, Config.BlipScale or 0.75)
        SetBlipColour(blip, Config.BlipColor or 2)
        SetBlipDisplay(blip, 4)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(Config.BlipLabel or 'Degalinė')
        EndTextCommandSetBlipName(blip)
    end
end

CreateThread(function()
    Wait(1500)
    createFuelBlips()
end)

local function findNearestPump()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return nil end
    local veh = GetVehiclePedIsIn(ped, false)
    if GetPedInVehicleSeat(veh, -1) ~= ped then return nil end

    local pos = GetEntityCoords(veh)
    local bestDist, best = 9999.0, nil
    local maxD = Config.MaxDistanceToPump or 2.8
    for _, s in ipairs(Config.Stations or {}) do
        local d = #(pos - vector3(s.x, s.y, s.z))
        if d < maxD and d < bestDist then
            bestDist = d
            best = s
        end
    end
    if not best then return nil end
    return { coords = vector3(best.x, best.y, best.z), veh = veh }
end

local function stopPumping()
    if not pumping then return end
    pumping = false
    currentPump = nil
    ClearPedTasks(PlayerPedId())
end

local function startPumping(pump)
    if pumping then
        stopPumping()
        return
    end
    pumping = true
    currentPump = pump
    local ped = PlayerPedId()
    TaskTurnPedToFaceCoord(ped, pump.coords.x, pump.coords.y, pump.coords.z, 800)
    CreateThread(function()
        local pricePerL = Config.PricePerLiter or 7
        while pumping and currentPump and DoesEntityExist(currentPump.veh) do
            local veh = currentPump.veh
            local fuel = GetVehicleFuelLevel(veh)
            if fuel >= 99.5 then
                QBCore.Functions.Notify('Bakas pilnas.', 'primary')
                break
            end
            if not IsPedInAnyVehicle(ped, false) or GetVehiclePedIsIn(ped, false) ~= veh then
                QBCore.Functions.Notify('Turi likti automobilyje kol pilasi kuras.', 'error')
                break
            end
            lastPayResult = { ok = false }
            TriggerServerEvent('fivempro_fuel:server:payTick')
            local waitMs = GetGameTimer() + 700
            while GetGameTimer() < waitMs and pumping do
                Wait(0)
            end
            if not lastPayResult.ok then
                QBCore.Functions.Notify('Nebepakanka pinigų kurui.', 'error')
                break
            end
            local add = 1.5
            SetVehicleFuelLevel(veh, math.min(100.0, fuel + add))
        end
        stopPumping()
    end)
end

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local pump = findNearestPump()
            if pump then
                local msg = pumping and '[E] Sustabdyti pildymą' or '[E] Pildyti kurą'
                local coords = pump.coords
                SetTextFont(0)
                SetTextProportional(1)
                SetTextScale(0.35, 0.35)
                SetTextColour(255, 255, 255, 215)
                SetTextCentre(true)
                BeginTextCommandDisplayText('STRING')
                AddTextComponentSubstringPlayerName(msg)
                EndTextCommandDisplayText(0.5, 0.90)

                if IsControlJustPressed(0, 38) then
                    startPumping(pump)
                end
                Wait(0)
            else
                Wait(400)
            end
        else
            if pumping then
                stopPumping()
            end
            Wait(600)
        end
    end
end)

