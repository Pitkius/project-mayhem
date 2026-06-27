local QBCore = exports['qb-core']:GetCoreObject()

local role = nil --- 'aggressor' | 'victim' | nil
local peerSid = nil
local helpThread = false

local function notify(msg, typ)
    QBCore.Functions.Notify(msg, typ or 'primary')
end

local function loadDict(dict)
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    local t = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do
        Wait(10)
    end
    return HasAnimDictLoaded(dict)
end

local function isPistolWeapon(weapon)
    if weapon == 0 or weapon == `WEAPON_UNARMED` then return false end
    for _, w in ipairs(Config.PistolWeapons or {}) do
        if weapon == w then return true end
    end
    local group = GetWeapontypeGroup(weapon)
    return group == `GROUP_PISTOL` or group == 416676503
end

local function hasPistolInHand()
    if not Config.RequirePistolInHand then return true end
    local ped = PlayerPedId()
    if not IsPedArmed(ped, 4) then return false end
    return isPistolWeapon(GetSelectedPedWeapon(ped))
end

local function getClosestPlayerServerId(radius)
    local ok, closestPlayer = pcall(function()
        return QBCore.Functions.GetClosestPlayer()
    end)
    if ok and closestPlayer and closestPlayer ~= -1 then
        local targetPed = GetPlayerPed(closestPlayer)
        if targetPed and targetPed ~= 0 then
            local myPed = PlayerPedId()
            if #(GetEntityCoords(targetPed) - GetEntityCoords(myPed)) <= radius then
                return GetPlayerServerId(closestPlayer)
            end
        end
    end

    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local bestSid, bestDist = nil, radius + 0.01
    for _, pid in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(pid)
        if ped ~= myPed and ped ~= 0 then
            local d = #(GetEntityCoords(ped) - myCoords)
            if d < bestDist then
                bestDist = d
                bestSid = GetPlayerServerId(pid)
            end
        end
    end
    return bestSid
end

local function peerPed()
    if not peerSid then return nil end
    local idx = GetPlayerFromServerId(peerSid)
    if idx == -1 then return nil end
    local ped = GetPlayerPed(idx)
    if ped and ped ~= 0 then return ped end
    return nil
end

local function stopLocalHostage()
    local ped = PlayerPedId()
    role = nil
    peerSid = nil
    helpThread = false
    DetachEntity(ped, true, false)
    ClearPedSecondaryTask(ped)
    DisablePlayerFiring(PlayerId(), false)
end

local function drawHelp()
    SetTextFont(4)
    SetTextScale(0.42, 0.42)
    SetTextColour(255, 255, 255, 230)
    SetTextCentre(true)
    SetTextDropshadow(2, 0, 0, 0, 200)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(Config.HelpText or '~g~G~s~ Paleisti  |  ~r~H~s~ Nusauti')
    EndTextCommandDisplayText(0.5, 0.92)
end

local function startHelpLoop()
    if helpThread then return end
    helpThread = true
    CreateThread(function()
        while helpThread and role == 'aggressor' do
            drawHelp()
            Wait(0)
        end
        helpThread = false
    end)
end

local function canContinueHostage()
    local ped = PlayerPedId()
    if IsEntityDead(ped) then return false end
    if IsPedInAnyVehicle(ped, false) then return false end
    local vic = peerPed()
    if not vic or not DoesEntityExist(vic) then return false end
    if IsEntityDead(vic) then return false end
    if IsPedInAnyVehicle(vic, false) then return false end
    if role == 'aggressor' and Config.RequirePistolInHand and not isPistolWeapon(GetSelectedPedWeapon(ped)) then
        return false
    end
    return true
end

RegisterNetEvent('mrp_ikaitas:client:beAggressor', function(targetSid)
    if role then return end
    if not loadDict(Config.AnimDict) then
        notify('Nepavyko užkrauti animacijos.', 'error')
        TriggerServerEvent('mrp_ikaitas:server:abort')
        return
    end

    peerSid = tonumber(targetSid)
    role = 'aggressor'
    local ped = PlayerPedId()
    local vic = peerPed()
    if not vic then
        stopLocalHostage()
        TriggerServerEvent('mrp_ikaitas:server:abort')
        notify('Taikinys nerastas.', 'error')
        return
    end

    SetCurrentPedWeapon(ped, GetSelectedPedWeapon(ped), true)
    TaskPlayAnim(ped, Config.AnimDict, Config.AnimAggressor, 8.0, -8.0, -1, 49, 0, false, false, false)
    startHelpLoop()

    CreateThread(function()
        while role == 'aggressor' and peerSid do
            if not canContinueHostage() then
                TriggerServerEvent('mrp_ikaitas:server:abort')
                break
            end

            ped = PlayerPedId()
            if not IsEntityPlayingAnim(ped, Config.AnimDict, Config.AnimAggressor, 3) then
                TaskPlayAnim(ped, Config.AnimDict, Config.AnimAggressor, 8.0, -8.0, -1, 49, 0, false, false, false)
            end

            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 47, true)
            DisableControlAction(0, 74, true)
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 22, true)

            if IsDisabledControlJustPressed(0, Config.KeyRelease) then
                TriggerServerEvent('mrp_ikaitas:server:release')
                break
            end
            if IsDisabledControlJustPressed(0, Config.KeyKill) then
                TriggerServerEvent('mrp_ikaitas:server:kill')
                break
            end

            Wait(0)
        end
    end)
end)

RegisterNetEvent('mrp_ikaitas:client:beVictim', function(aggressorSid)
    if role then return end
    if not loadDict(Config.AnimDict) then return end

    peerSid = tonumber(aggressorSid)
    role = 'victim'
    local ped = PlayerPedId()
    local agg = peerPed()
    if not agg then
        stopLocalHostage()
        return
    end

    ClearPedSecondaryTask(ped)
    local a = Config.Attach
    AttachEntityToEntity(
        ped, agg, 0,
        a.x, a.y, a.z,
        a.rx, a.ry, a.rz,
        false, false, false, false, 2, true
    )
    TaskPlayAnim(ped, Config.AnimDict, Config.AnimVictim, 8.0, -8.0, -1, 49, 0, false, false, false)

    CreateThread(function()
        while role == 'victim' and peerSid do
            ped = PlayerPedId()
            agg = peerPed()
            if not agg or not DoesEntityExist(agg) or IsEntityDead(ped) or IsEntityDead(agg) then
                TriggerServerEvent('mrp_ikaitas:server:abort')
                break
            end

            if not IsEntityAttachedToEntity(ped, agg) then
                AttachEntityToEntity(
                    ped, agg, 0,
                    a.x, a.y, a.z,
                    a.rx, a.ry, a.rz,
                    false, false, false, false, 2, true
                )
            end

            if not IsEntityPlayingAnim(ped, Config.AnimDict, Config.AnimVictim, 3) then
                TaskPlayAnim(ped, Config.AnimDict, Config.AnimVictim, 8.0, -8.0, -1, 49, 0, false, false, false)
            end

            DisableAllControlActions(0)
            EnableControlAction(0, 1, true)
            EnableControlAction(0, 2, true)
            EnableControlAction(0, 245, true)
            EnableControlAction(0, 246, true)

            Wait(0)
        end
    end)
end)

RegisterNetEvent('mrp_ikaitas:client:executeVictim', function()
    local ped = PlayerPedId()
    DetachEntity(ped, true, false)
    ClearPedSecondaryTask(ped)
    SetEntityHealth(ped, 0)
end)

RegisterNetEvent('mrp_ikaitas:client:stop', function(reason)
    if role == 'aggressor' and reason == 'kill' and loadDict(Config.AnimDict) then
        local ped = PlayerPedId()
        TaskPlayAnim(ped, Config.AnimDict, Config.AnimKillAggressor, 8.0, -8.0, 1200, 168, 0, false, false, false)
        Wait(900)
    end
    stopLocalHostage()
end)

RegisterCommand('ikaitas', function()
    if role then
        notify('Jau esi įkaitų situacijoje.', 'error')
        return
    end

    if not hasPistolInHand() then
        notify('Išsitrauk pistoletą ir laikyk jį rankoje.', 'error')
        return
    end

    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        notify('Išeik iš transporto.', 'error')
        return
    end

    local target = getClosestPlayerServerId(Config.MaxDistance or 3.0)
    if not target then
        notify(('Nėra žaidėjo šalia (≤ %.0f m).'):format(Config.MaxDistance or 3.0), 'error')
        return
    end

    local targetPed = GetPlayerPed(GetPlayerFromServerId(target))
    if targetPed and targetPed ~= 0 then
        if IsPedInAnyVehicle(targetPed, false) then
            notify('Taikinys transporte — negalima.', 'error')
            return
        end
        if IsEntityDead(targetPed) then
            notify('Taikinys negyvas.', 'error')
            return
        end
    end

    TriggerServerEvent('mrp_ikaitas:server:tryStart', target)
end, false)

TriggerEvent('chat:addSuggestion', '/ikaitas', 'Paimti artimiausią žaidėją įkaitu (reikia pistoleto rankoje)')
