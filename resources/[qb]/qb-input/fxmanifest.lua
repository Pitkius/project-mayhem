fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'Kakarot'
description 'Menu that allows players to input information for various things'
version '1.2.0'

client_scripts {
    '@mrp_hud/client/theme_nui_consumer.lua',
    'client/*.lua'
}

exports {
    'ShowInput',
    'ForceClose',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/styles/*.css',
    'html/script.js'
}
