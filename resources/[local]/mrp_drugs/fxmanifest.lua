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
    'html/minigames.css',
    'html/minigame-screens.css',
    'html/mg-vape.css',
    'html/mg-vape.js',
    'html/mg-thc.css',
    'html/mg-thc.js',
    'html/mg-weed.css',
    'html/mg-weed.js',
    'html/mg-heroin.css',
    'html/mg-heroin.js',
    'html/mg-meth.css',
    'html/mg-meth.js',
    'html/mg-pills.css',
    'html/mg-pills.js',
    'html/mg-mushroom.css',
    'html/mg-mushroom.js',
    'html/mg-cocaine.css',
    'html/mg-cocaine.js',
    'html/mg-amp.css',
    'html/mg-amp.js',
    'html/drug-icons.js',
    'html/mg-audio.js',
    'html/mg-fx.js',
    'html/app.js',
    'html/schedule-icons.js',
    'html/schedule.js',
    'html/minigame-ui.js',
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
    'shared/stations.lua',
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
    'client/water_refill.lua',
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

server_exports {
    'GiveDrugSalePayout',
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
