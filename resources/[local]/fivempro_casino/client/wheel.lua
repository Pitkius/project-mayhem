local QBCore = exports['qb-core']:GetCoreObject()

local spinning = false

RegisterNetEvent('fivempro_casino:client:openWheel', function()
    if spinning then return end
    if not Casino.canUseCasino() then return end

    QBCore.Functions.TriggerCallback('fivempro_casino:server:spinWheel', function(res)
        if not res or not res.ok then
            QBCore.Functions.Notify(res and res.msg or 'Ratas neprieinamas.', 'error')
            return
        end

        spinning = true
        local ped = PlayerPedId()
        local dict = 'anim_casino_a@amb@casino@games@lucky7wheel@female'
        RequestAnimDict(dict)
        while not HasAnimDictLoaded(dict) do Wait(10) end
        TaskPlayAnim(ped, dict, 'enter_right_to_baseidle', 8.0, -8.0, 2500, 0, 0, false, false, false)
        Wait(1200)

        local duration = (Config.Wheel and Config.Wheel.spinDurationMs) or 6500
        local started = GetGameTimer()
        while GetGameTimer() - started < duration do
            local wheel = Config.Wheel and Config.Wheel.coords
            if wheel then
                local c = GetEntityCoords(ped)
                Casino.drawText3D(vector3(c.x, c.y, c.z + 1.0), '🎡 Sukasi...', 0.45)
            end
            Wait(0)
        end

        ClearPedTasks(ped)
        spinning = false

        if res.type == 'none' then
            QBCore.Functions.Notify('Ratas: ' .. (res.label or 'Nieko'), 'error')
        elseif res.type == 'chips' then
            QBCore.Functions.Notify(('Ratas: %s!'):format(res.label or 'Prizas'), 'success')
        else
            QBCore.Functions.Notify(('Ratas: %s!'):format(res.label or 'Prizas'), 'success')
        end
    end)
end)
