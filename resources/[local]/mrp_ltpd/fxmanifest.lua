fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_ltpd'
author 'MRP'
description 'Lietuvos policija – rangai, padaliniai, MDT (QBCore)'
version '1.0.0'

ui_page 'html/mdt/index.html'

shared_scripts {
    'config_fine_presets.lua',
    'config.lua',
    'config_pd_craft.lua',
    'shared/pd_divisions.lua',
    'config_duty_outfits.lua',
    'config_surveillance.lua',
    'config_ems_doors.lua',
    'config_ranger_doors.lua',
}

client_scripts {
    'client/pd_markers.lua',
    'client/reception.lua',
    'client/divisions.lua',
    'client/main.lua',
    'client/pd_craft.lua',
    'client/cctv_props.lua',
    'client/cctv.lua',
    'client/bodycam.lua',
    'client/boss.lua',
    'client/emergency_kit.lua',
    'client/spike_strip.lua',
    'client/pd_doors.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/division_ranks.lua',
    'server/reception.lua',
    'server/pd_craft.lua',
    'server/surveillance.lua',
    'server/spike_strip.lua',
    'server/mdt_incidents.lua',
}

files {
    'html/mdt/index.html',
    'html/mdt/app.js',
    'html/mdt/incidents.js',
    'html/mdt/gtav_map_core.js',
    'html/mdt/mdt_map.js',
    'html/mdt/style.css',
    'html/mdt/vendor/leaflet.js',
    'html/mdt/vendor/leaflet.css',
    'html/mdt/asset/gtav_satellite.jpg',
    'html/mdt/asset/gtav_satellite_2048.png',
    'html/mdt/assets/mayhem_logo.png',
    'html/mdt/assets/mayhem_mark.png',
    'html/mdt/assets/logo_pd.png',
    'html/craft/style.css',
    'html/craft/app.js',
}

dependencies {
    'qb-core',
    'qb-menu',
    'qb-input',
    'qb-inventory',
    'qb-target',
    'mrp_dispatch',
    'mrp_siren_controller',
}

server_exports {
    'SaveInterrogationRecord',
    'PersistVehicleEmergencyMods',
    'ApplyVehicleEmergencyFromMods',
}
--- IssuePoliceFine / AddPoliceArrestRecord / HasLtpdPermissionV2 / IsLtpdOnDuty
--- registruojami runtime (`exports('...', fn)`) server/main.lua faile.
-- qb-menu (garažo meniu), qb-inventory (ginklinė / stash), qb-target (zonos)
