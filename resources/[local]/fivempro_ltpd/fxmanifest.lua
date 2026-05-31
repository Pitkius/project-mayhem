fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivempro_ltpd'
author 'FIVEMPROJEKTAS'
description 'Lietuvos policija – rangai, padaliniai, MDT (QBCore)'
version '1.0.0'

ui_page 'html/mdt/index.html'

shared_scripts {
    'config.lua',
    'config_surveillance.lua',
    'config_ems_doors.lua',
    'config_ranger_doors.lua',
}

client_scripts {
    'client/main.lua',
    'client/cctv_props.lua',
    'client/cctv.lua',
    'client/bodycam.lua',
    'client/boss.lua',
    'client/emergency_kit.lua',
    'client/pd_doors.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/surveillance.lua',
}

files {
    'html/mdt/index.html',
    'html/mdt/app.js',
    'html/mdt/mdt_map.js',
    'html/mdt/style.css',
    'html/mdt/vendor/leaflet.js',
    'html/mdt/vendor/leaflet.css',
    'html/mdt/asset/gtav_satellite.jpg',
    'html/mdt/asset/gtav_satellite_2048.png',
}

dependencies {
    'qb-core',
    'fivempro_dispatch',
}
-- qb-menu (garažo meniu), qb-inventory (ginklinė / stash), qb-target (zonos)
