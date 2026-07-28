fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_bank'
author 'MRP'
description 'BANKNET bankomato ir banko terminalo UI'
version '2.0.0'

ui_page 'html/index.html'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

files {
    'html/index.html',
    'html/style.css',
    'html/app.js'
}

dependencies {
    'qb-core',
    'mrp_phone',
    'mrp_fonts'
}
