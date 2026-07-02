local QBCore = exports['qb-core']:GetCoreObject()

local lastInteractMs = 0

RegisterNetEvent('mrp_motel:client:openPublicStash', function()
    TriggerServerEvent('mrp_motel:server:openPublicStash')
end)

local function stashHint(label)
    if GetResourceState('mrp_npcshops') == 'started' then
        return exports['mrp_npcshops']:StashInteractHint(label)
    end
    return ('[F2] %s'):format(label or 'Sandėlis')
end

local function isStashOpenPressed()
    if GetResourceState('mrp_npcshops') == 'started' then
        return exports['mrp_npcshops']:IsStashOpenPressed()
    end
    EnableControlAction(0, 289, true)
    return IsControlJustPressed(0, 289) or IsDisabledControlJustPressed(0, 289)
end

local function enableStashOpenControl()
    if GetResourceState('mrp_npcshops') == 'started' then
        exports['mrp_npcshops']:EnableStashOpenControl()
    else
        EnableControlAction(0, 289, true)
    end
end

CreateThread(function()
    local st = Config.PublicStash
    if not st or not st.coords then return end

    local pos = st.coords
    local useR = st.maxDistance or 2.5
    local drawD = useR + 18.0
    local label = st.label or 'Motelio sandėlis'

    while true do
        local sleep = 800
        if not IsNuiFocused() then
            local ped = PlayerPedId()
            local pcoords = GetEntityCoords(ped)
            local dist = #(pcoords - pos)
            if dist < drawD then
                sleep = dist < useR and 0 or 120
                DrawMarker(
                    2,
                    pos.x, pos.y, pos.z + 0.06,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    0.34, 0.34, 0.34,
                    255, 180, 72, 140,
                    false, false, 2, false, nil, nil, false
                )
                if dist < useR then
                    enableStashOpenControl()
                    QBCore.Functions.DrawText3D(pos.x, pos.y, pos.z + 0.55, stashHint(label))
                    if isStashOpenPressed() and (GetGameTimer() - lastInteractMs) > 450 then
                        lastInteractMs = GetGameTimer()
                        TriggerEvent('mrp_motel:client:openPublicStash')
                    end
                end
            end
        end
        Wait(sleep)
    end
end)
