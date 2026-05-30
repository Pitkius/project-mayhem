fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivempro_loadscreen'
author 'FIVEMPROJEKTAS'
description 'GTA-style loading screen with rotating scenes'
version '1.0.1'

loadscreen 'html/index.html'
loadscreen_manual_shutdown 'yes'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/assets/*.jpg',
}

client_script 'client/main.lua'
