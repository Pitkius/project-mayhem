CreateThread(function()
    Wait(2000)
    for _, entry in ipairs(Config.Blips or {}) do
        local started = false
        if entry.resource and GetResourceState(entry.resource) == 'started' then
            started = true
        end
        if not started and type(entry.resources) == 'table' then
            for _, resName in ipairs(entry.resources) do
                if GetResourceState(resName) == 'started' then
                    started = true
                    break
                end
            end
        end
        if started and entry.coords then
            local b = AddBlipForCoord(entry.coords.x, entry.coords.y, entry.coords.z)
            SetBlipSprite(b, entry.sprite or 1)
            SetBlipDisplay(b, 4)
            SetBlipScale(b, entry.scale or Config.DefaultScale or 0.75)
            SetBlipColour(b, entry.color or 0)
            SetBlipAsShortRange(b, entry.shortRange ~= false and Config.ShortRange ~= false)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(entry.label or entry.resource or 'MLO')
            EndTextCommandSetBlipName(b)
        end
    end
end)

