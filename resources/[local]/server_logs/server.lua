print(('[%s] Loaded — configure webhooks in config.lua'):format(GetCurrentResourceName()))

-- Pridėti naują logų kategoriją:
-- 1. config.lua → Config.Webhooks.naujas_tipas = 'WEBHOOK_URL'
-- 2. config.lua → Config.Colors.naujas_tipas = 123456
-- 3. Sukurk modules/naujasLogs.lua arba naudok export/event:
--    exports['server_logs']:SendCustomLog('naujas_tipas', 'Title', 'Message', source)
-- 4. fxmanifest.lua → pridėk failą į server_scripts
