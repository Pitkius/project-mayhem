fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_jobs'
description 'Modulinė legalių darbų sistema (nafta / Burger Joint / vaisiai)'
author 'FIVEMPRO'
version '0.2.0'

shared_scripts {
    'shared/constants.lua',
    'shared/utils.lua',
    'config/main.lua',
    'config/jobs.lua',
    'config/minigames.lua',
    'config/locations.lua',
    'config/rewards.lua',
    'config/npc.lua',
    'config/vape.lua',
}

client_scripts {
    '@mrp_hud/client/theme_nui_consumer.lua',
    'client/main.lua',
    'client/job_manager.lua',
    'client/minigame.lua',
    'client/props.lua',
    'client/oil.lua',
    'client/npc.lua',
    'client/burger.lua',
    'client/cleaner.lua',
    'client/fruit.lua',
    'client/vape.lua',
    'client/career.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/security.lua',
    'server/persistence.lua',
    'server/cooldowns.lua',
    'server/rewards.lua',
    'server/job_manager.lua',
    'server/main.lua',
    'server/oil.lua',
    'server/burger_npc.lua',
    'server/burger.lua',
    'server/cleaner.lua',
    'server/fruit.lua',
    'server/vape.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/app.js',
    'html/styles.css',
}

dependencies {
    'qb-core',
    'qb-target',
    'qb-inventory',
    'qb-menu',
    'oxmysql',
}
