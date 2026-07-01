fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_gunshop'
description 'Ginklų parduotuvės ir ginklo licencijos (QBCore)'
version '1.0.0'

shared_scripts {
    'config.lua',
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
    'qb-target',
    'qb-inventory',
    'oxmysql',
}
