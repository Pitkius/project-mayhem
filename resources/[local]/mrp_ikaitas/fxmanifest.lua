fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_ikaitas'
author 'MRP'
description 'Įkaitų sistema — pistoletas, vedimas, paleisti / nusauti'
version '1.0.0'

shared_scripts {
    'config.lua',
}

client_scripts {
    'client.lua',
}

server_scripts {
    'server.lua',
}

dependencies {
    'qb-core',
}
