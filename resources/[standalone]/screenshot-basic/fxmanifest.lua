fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'screenshot-basic'
description 'FiveM ekrano nuotraukos (reikalingas telefono kamerai)'
version '1.0.0'

client_script 'dist/client.js'
server_script 'dist/server.js'

files {
    'dist/ui.html',
}

ui_page 'dist/ui.html'
