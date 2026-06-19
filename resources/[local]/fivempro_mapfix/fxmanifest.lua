fx_version 'cerulean'
game 'gta5'

name 'fivempro_mapfix'
author 'FIVEMPRO'
description 'Forces key map interiors/IPLs to load'
lua54 'yes'

dependency 'cfx-gabz-mapdata'
dependency 'cfx-gabz-lost'

client_scripts {
    'client.lua'
}

exports {
    'ReloadSimeonShowroom',
    'ReloadOneilFarmhouse',
    'ReloadLostMc',
    'ApplyMapFixes',
}
