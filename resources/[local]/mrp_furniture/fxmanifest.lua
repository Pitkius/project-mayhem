fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_furniture'
author 'MRP'
description 'Baldų parduotuvė, pastatymas name, qb-target funkcijos (sėdėjimas, TV, lova, seifai, spintos)'
version '1.0.0'

shared_scripts {
    'config/catalog.lua',
    'config/shared.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependencies {
    'qb-core',
    'oxmysql',
    'qb-target',
    'qb-inventory',
    'mrp_housing',
}
