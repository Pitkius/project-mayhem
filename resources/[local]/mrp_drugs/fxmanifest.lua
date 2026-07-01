fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_drugs'
author 'MRP'
description 'Narkotikų crafting, NPC pardavimas, turf ir dispatch (RP)'
version '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/schedule-icons.js',
    'html/schedule.js',
    'html/drug-games.js',
    'html/icons/grow_pot.png',
    'html/icons/watering_can.png',
    'html/icons/drug_scale.png',
    'html/icons/weed_leaf.png',
    'html/icons/trimming_scissors.png',
    'html/icons/gloves_item.png',
    'html/assets/mayhem_logo.png',
}

shared_scripts {
    'config.lua',
    'shared/minigame_registry.lua',
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
    'mrp_gangs',
    'mrp_dispatch',
}
