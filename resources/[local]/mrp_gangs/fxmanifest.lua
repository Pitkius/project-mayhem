fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_gangs'
author 'Project Mayhem'
description 'Gang System 2.0 - server-authoritative cooperative operations'
version '2.0.0-alpha.1'

ui_page 'html/index.html'

files {
    'sql/schema_v2.sql',
    'sql/reset_v2.sql',
    'html/index.html',
    'html/styles.css',
    'html/app.js',
    'html/vendor/leaflet.css',
    'html/vendor/leaflet.js',
    'html/asset/gtav_satellite_2048.png',
    'html/images/missions/*.png',
    'html/assets/mayhem_mark.png',
}

shared_scripts {
    'config/shared.lua',
    'config/permissions.lua',
    'config/territory_polygons.lua',
    'config/territories.lua',
    'config/diplomacy.lua',
    'config/interiors.lua',
    'config/missions.lua',
    'shared/util.lua',
}

client_scripts {
    'client/main.lua',
    'client/territories.lua',
    'client/missions.lua',
    'client/tablet.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/validation.lua',
    'server/bootstrap.lua',
    'server/core.lua',
    'server/rbac.lua',
    'server/adapters.lua',
    'server/organization.lua',
    'server/territories.lua',
    'server/drugs.lua',
    'server/diplomacy.lua',
    'server/wars.lua',
    'server/economy.lua',
    'server/missions/objectives.lua',
    'server/missions/encounters.lua',
    'server/missions/main.lua',
    'server/tablet.lua',
}

dependencies {
    'qb-core',
    'oxmysql',
    'qb-menu',
    'qb-target',
}
