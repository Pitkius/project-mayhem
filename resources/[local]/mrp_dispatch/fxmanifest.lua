fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_dispatch'
description 'Fivempro unified dispatch, crews, faction blips, panic alerts'
version '1.0.0'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua',
}

server_exports {
    'TriggerOfficerPanic',
    'CreateDispatchCall',
}

dependencies {
    'qb-core',
    --- Soft: mrp_mdt_core should start first (cfg/30_custom.cfg). Not hard-required so dispatch still boots alone.
}

