local QBCore = exports['qb-core']:GetCoreObject()

local Carry = {
    active = false,
    role = nil, ---@type 'carrier'|'carried'|nil
    peerSid = nil,
    variant = nil,
}

local function notify(msg, typ)
    QBCore.Functions.Notify(msg, typ or 'primary')
end

local function loadDict(animDict)
    if HasAnimDictLoaded(animDict) then return end
    RequestAnimDict(animDict)
    local t = GetGameTimer() + 5000
    while not HasAnimDictLoaded(animDict) and GetGameTimer() < t do
        Wait(10)
    end
end

local function getClosestPlayerServerId(radius)
    local players = GetActivePlayers()
    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local closest = nil
    local best = radius + 1.0
    for _, pid in ipairs(players) do
        local ped = GetPlayerPed(pid)
        if ped ~= myPed and ped ~= 0 then
            local d = #(GetEntityCoords(ped) - myCoords)
            if d < best then
                best = d
                closest = pid
            end
        end
    end
    if not closest then return nil end
    return GetPlayerServerId(closest)
end

local function waitForPeerPed(peerSid)
    local deadline = GetGameTimer() + 5000
    while GetGameTimer() < deadline do
        local idx = GetPlayerFromServerId(peerSid)
        if idx ~= -1 then
            local ped = GetPlayerPed(idx)
            if ped and ped ~= 0 then return ped end
        end
        Wait(50)
    end
    return nil
end

RegisterCommand('nesti', function(_, args)
    if Carry.active then
        notify('Jau neši ar būni nešamas — naudok /nenesti', 'error')
        return
    end

    local closest = getClosestPlayerServerId(Config.MaxDistance)
    if not closest then
        notify('Šalia nieko nėra (≤ 3 m).', 'error')
        return
    end

    local variant = tonumber(args[1]) or 1
    if not Config.Variants[variant] then
        notify('Naudok: /nesti arba /nesti 1-3', 'error')
        return
    end
    TriggerServerEvent('fivempro_carry:server:request', { target = closest, variant = variant })
end, false)

RegisterCommand('nenesti', function()
    TriggerServerEvent('fivempro_carry:server:stop')
end, false)

RegisterNetEvent('fivempro_carry:client:start', function(data)
    if type(data) ~= 'table' then return end
    local vcfg = Config.Variants[data.variant]
    if not vcfg then return end

    Carry.active = true
    Carry.role = data.role
    Carry.peerSid = data.peer
    Carry.variant = data.variant

    loadDict(vcfg.carrier.dict)
    loadDict(vcfg.carried.dict)

    local myPed = PlayerPedId()
    if data.role == 'carrier' then
        ClearPedSecondaryTask(myPed)
        TaskPlayAnim(myPed, vcfg.carrier.dict, vcfg.carrier.anim, 8.0, -8.0, -1, vcfg.carrier.flag, 0, false, false, false)
        return
    end

    local peerPed = waitForPeerPed(data.peer)
    if not peerPed then
        notify('Nepavyko pritvirtinti — per toli arba žaidėjas neparuoštas.', 'error')
        TriggerServerEvent('fivempro_carry:server:breakPair')
        return
    end

    ClearPedSecondaryTask(myPed)
    DetachEntity(myPed, true, false)
    AttachEntityToEntity(
        myPed,
        peerPed,
        0,
        vcfg.attach.x,
        vcfg.attach.y,
        vcfg.attach.z,
        vcfg.attach.rx,
        vcfg.attach.ry,
        vcfg.attach.rz,
        false,
        false,
        false,
        false,
        2,
        false
    )
    TaskPlayAnim(myPed, vcfg.carried.dict, vcfg.carried.anim, 8.0, -8.0, -1, vcfg.carried.flag, 0, false, false, false)
end)

RegisterNetEvent('fivempro_carry:client:stop', function()
    Carry.active = false
    Carry.role = nil
    Carry.peerSid = nil
    Carry.variant = nil
    local ped = PlayerPedId()
    ClearPedSecondaryTask(ped)
    DetachEntity(ped, true, false)
end)

CreateThread(function()
    while true do
        if Carry.active and Carry.variant and Config.Variants[Carry.variant] then
            local vcfg = Config.Variants[Carry.variant]
            local ped = PlayerPedId()
            if Carry.role == 'carrier' then
                if not IsEntityPlayingAnim(ped, vcfg.carrier.dict, vcfg.carrier.anim, 3) then
                    TaskPlayAnim(ped, vcfg.carrier.dict, vcfg.carrier.anim, 8.0, -8.0, -1, vcfg.carrier.flag, 0, false, false, false)
                end
            elseif Carry.role == 'carried' then
                local idx = Carry.peerSid and GetPlayerFromServerId(Carry.peerSid) or -1
                local peerPed = (idx ~= -1) and GetPlayerPed(idx) or 0
                if peerPed and peerPed ~= 0 and not IsEntityAttachedToEntity(ped, peerPed) then
                    AttachEntityToEntity(
                        ped,
                        peerPed,
                        0,
                        vcfg.attach.x,
                        vcfg.attach.y,
                        vcfg.attach.z,
                        vcfg.attach.rx,
                        vcfg.attach.ry,
                        vcfg.attach.rz,
                        false,
                        false,
                        false,
                        false,
                        2,
                        false
                    )
                end
                if not IsEntityPlayingAnim(ped, vcfg.carried.dict, vcfg.carried.anim, 3) then
                    TaskPlayAnim(ped, vcfg.carried.dict, vcfg.carried.anim, 8.0, -8.0, -1, vcfg.carried.flag, 0, false, false, false)
                end
                DisablePlayerFiring(ped, true)
                DisableControlAction(0, 24, true)
                DisableControlAction(0, 25, true)
                DisableControlAction(0, 140, true)
                DisableControlAction(0, 141, true)
                DisableControlAction(0, 142, true)
                DisableControlAction(0, 143, true)
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

exports('IsCarryBusy', function()
    return Carry.active == true
end)
