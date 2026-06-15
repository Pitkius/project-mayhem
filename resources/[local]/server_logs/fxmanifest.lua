fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'server_logs'
author 'FIVEMPROJEKTAS'
description 'FiveM server logging to Discord webhooks with queue and rate limiting'
version '1.0.0'

server_scripts {
    'config.lua',
    'modules/discord.lua',
    'modules/identifiers.lua',
    'modules/playerLogs.lua',
    'modules/adminLogs.lua',
    'modules/deathLogs.lua',
    'modules/reviveLogs.lua',
    'modules/spawnLogs.lua',
    'modules/bankLogs.lua',
    'modules/jobLogs.lua',
    'modules/warehouseLogs.lua',
    'modules/gangLogs.lua',
    'modules/missionLogs.lua',
    'modules/inventoryLogs.lua',
    'modules/vehicleLogs.lua',
    'modules/moneyLogs.lua',
    'modules/securityLogs.lua',
    'integrations/qbcore.lua',
    'integrations/esx.lua',
    'server.lua',
}

server_exports {
    'SendCustomLog',
    'SendLog',
    'GetPlayerIdentifiersFormatted',
}
