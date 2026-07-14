fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_chopshop'
author 'FIVEMPRO'
description 'Chop shop — ardyti transportą, dalys → nešvarūs pinigai'
version '1.0.0'

shared_scripts {
    '@qb-core/shared/locale.lua',
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
    'oxmysql',
}
