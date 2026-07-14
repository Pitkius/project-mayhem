fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_duty_locker'
description 'Tarnybinių rūbų rūbinė — dešinės pusės UI (PD / EMS / mechanikai)'
version '1.0.0'

shared_scripts {
    'shared/categories.lua',
}

client_scripts {
    '@mrp_hud/client/theme_nui_consumer.lua',
    'client/apply.lua',
    'client/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}
