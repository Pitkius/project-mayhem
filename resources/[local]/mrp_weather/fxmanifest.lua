fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_weather'
author 'MRP'
description 'Regioninė orų prognozė (Los Santos, Sandy Shores, Paleto) sinchronizuota su žaidimo laiku'
version '1.0.0'

shared_scripts {
    'config.lua',
    'shared/forecast.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

dependencies {
    'qb-core',
    'qb-weathersync',
}

exports {
    'getCurrentSlot',
    'getRegionAtCoords',
    'getRegions',
}

server_exports {
    'getGameTime',
    'getForecast',
    'getCurrentSlot',
}
