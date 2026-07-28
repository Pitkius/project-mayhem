--- Keep druglabs stopped: ensure [mlo] starts it, then cfg stop; re-stop if someone ensures it again.

local function stopDruglabs(reason)
    if GetResourceState('druglabs') == 'started' or GetResourceState('druglabs') == 'starting' then
        StopResource('druglabs')
        print(('[mrp_mapfix] stop druglabs (%s) — O\'Neil vanilla farmhouse'):format(reason or 'guard'))
    end
end

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == 'druglabs' then
        CreateThread(function()
            Wait(0)
            stopDruglabs('onResourceStart')
        end)
    elseif resourceName == GetCurrentResourceName() then
        CreateThread(function()
            Wait(500)
            stopDruglabs('mrp_mapfix start')
        end)
    end
end)

CreateThread(function()
    Wait(2000)
    stopDruglabs('boot')
end)
