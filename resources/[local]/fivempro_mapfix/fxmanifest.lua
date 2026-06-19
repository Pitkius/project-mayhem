fx_version 'cerulean'
game 'gta5'

name 'fivempro_mapfix'
author 'FIVEMPRO'
description 'Forces key map interiors/IPLs to load'
lua54 'yes'

dependency 'cfx-gabz-mapdata'

client_scripts {
    'client.lua'
}

exports {
    'ReloadSimeonShowroom',
    'ReloadOneilFarmhouse',
    'ReloadLostMc',
    'ReloadVapeSkyscraper',
    'ApplyMapFixes',
}
