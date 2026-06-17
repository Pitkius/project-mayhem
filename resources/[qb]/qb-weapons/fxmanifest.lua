fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'Kakarot'
description 'Manages all weapon logic for ammo, attachments, and more'
version '1.2.1'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'locales/en.lua',
    'locales/*.lua',
    'config.lua',
    'shared/weapon_damage.lua',
    'shared/weapon_hash.lua',
}

client_scripts {
    'client/main.lua',
    'client/damage.lua',
    'client/recoil.lua',
    'client/weapdraw.lua',
}

server_scripts {
    'server/main.lua',
    'server/damage.lua',
}

files {
    'weaponsnspistol.meta'
}

data_file 'WEAPONINFO_FILE_PATCH' 'weaponsnspistol.meta'
