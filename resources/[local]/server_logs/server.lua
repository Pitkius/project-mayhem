print(('[%s] Loaded — configure webhooks in config.lua (Guardian: /setuplogs → fivem-webhooks-*.lua)'):format(GetCurrentResourceName()))

CreateThread(function()
    Wait(3000)
    local missing = {}
    for key, url in pairs(Config.Webhooks or {}) do
        if not url or url == '' then
            missing[#missing + 1] = key
        end
    end
    if #missing > 0 then
        print(('[%s] ^3WARNING: %d webhook URL tušti — Discord logai neateis: %s^0'):format(
            GetCurrentResourceName(),
            #missing,
            table.concat(missing, ', ')
        ))
    end
end)

-- Pridėti naują logų kategoriją:
-- 1. config.lua → Config.Webhooks.naujas_tipas = 'WEBHOOK_URL'
-- 2. config.lua → Config.Colors.naujas_tipas = 123456
-- 3. Sukurk modules/naujasLogs.lua arba naudok export/event:
--    exports['server_logs']:SendCustomLog('naujas_tipas', 'Title', 'Message', source)
-- 4. fxmanifest.lua → pridėk failą į server_scripts
