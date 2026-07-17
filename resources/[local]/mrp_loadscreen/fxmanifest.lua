fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_loadscreen'
author 'MRP'
description 'GTA-style loading screen with rotating scenes'
version '1.0.2'

loadscreen 'html/index.html'
loadscreen_cursor 'yes'
loadscreen_manual_shutdown 'yes'

shared_script 'config.lua'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/assets/*.jpg',
    'html/assets/*.png',
}

client_script 'client/main.lua'
