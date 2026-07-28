fx_version 'cerulean'
game 'gta5'

name 'mrp_mapfix'
author 'FIVEMPRO'
description 'Forces key map interiors/IPLs to load'
lua54 'yes'

dependency 'cfx-gabz-mapdata'

server_scripts {
    'server.lua',
}

client_scripts {
    'client.lua',
}

exports {
    'ReloadSimeonShowroom',
    'ReloadOneilFarmhouse',
    'ReloadLostMc',
    'ReloadVapeSkyscraper',
    'ApplyMapFixes',
}
