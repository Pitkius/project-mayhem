Config = {}

-- qb-log:server:CreateLog → DB (pinigai, inventorius, join/leave, OOC, anticheat ir t. t.)
Config.HookQbLog = true

-- Papildomi įvykiai (nėra visų qb-log žinučių)
Config.HookPlayerLoaded = true
Config.HookPlayerDropped = true
Config.HookJobUpdate = true
Config.HookGangUpdate = true
Config.HookPlayerConnecting = true

-- Transportas (gali būti dažni šūviai – pagal nutylėjimą išjungta)
Config.HookVehicleBaseEvents = false

-- qb-inventory SetInventory labai dažnas – ribojimas pagal žaidėją (sekundės, 0 = visai nesaugoti per qb-log)
Config.SetInventoryLogCooldownSeconds = 45

-- Maks. žinutės ilgis DB (likutis nukerpamas)
Config.MaxMessageLength = 60000
