fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivempro_drugs'
author 'FIVEMPROJEKTAS'
description 'Narkotikų crafting, NPC pardavimas, turf ir dispatch (RP)'
version '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/schedule.js',
}

shared_scripts {
    'config.lua',
}

client_scripts {
    'client/progress.lua',
    'client/drug_sell_anim.lua',
    'client/schedule_anim.lua',
    'client/main.lua',
    'client/planned.lua',
    'client/printer.lua',
    'client/mushrooms.lua',
    'client/weed_grow.lua',
    'client/amp_lab.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/printer.lua',
    'server/amp_lab.lua',
}

client_exports {
    'PlayDrugSellAnim',
    'IsDrugSellAnimBusy',
    'RunScheduleMinigame',
}

dependencies {
    'qb-core',
    'qb-target',
    'qb-menu',
    'qb-inventory',
    'oxmysql',
    'fivempro_gangs',
    'fivempro_dispatch',
}
