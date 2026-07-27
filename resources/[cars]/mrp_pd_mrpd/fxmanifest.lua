fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_pd_mrpd'
author 'MRP'
description 'Mission Row PD vehicle pack (mrpd9-12, mrpd24) — non-ELS'
version '1.1.2'

this_is_a_map 'yes'

files {
    'data/**/vehicles.meta',
    'data/**/carvariations.meta',
    'data/**/carcols.meta',
    'data/**/handling.meta',
    'audioconfig/*.dat151.rel',
    'audioconfig/*.dat54.rel',
    'sfx/**/*.awc',
}

data_file 'HANDLING_FILE' 'data/**/handling.meta'
data_file 'VEHICLE_METADATA_FILE' 'data/**/vehicles.meta'
data_file 'CARCOLS_FILE' 'data/**/carcols.meta'
data_file 'VEHICLE_VARIATION_FILE' 'data/**/carvariations.meta'

-- BMW M3 (mrpd24) custom engine
data_file 'AUDIO_GAMEDATA' 'audioconfig/m5cracklemod_game.dat'
data_file 'AUDIO_SOUNDDATA' 'audioconfig/m5cracklemod_sounds.dat'
data_file 'AUDIO_WAVEPACK' 'sfx/dlc_m5cracklemod'
