fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_pd_oldstyle'
author 'MRP'
description 'PD Old style vehicle pack'
version '1.0.0'

files {
    'data/**/vehicles.meta',
    'data/**/carvariations.meta',
    'data/**/carcols.meta',
    'data/**/handling.meta',
    'data/**/vehiclelayouts.meta',
    'data/**/*.meta',
    'data/**/*.xml',
}

data_file 'HANDLING_FILE' 'data/**/handling.meta'
data_file 'VEHICLE_METADATA_FILE' 'data/**/vehicles.meta'
data_file 'CARCOLS_FILE' 'data/**/carcols.meta'
data_file 'VEHICLE_VARIATION_FILE' 'data/**/carvariations.meta'
data_file 'VEHICLE_LAYOUTS_FILE' 'data/**/vehiclelayouts.meta'
data_file 'CONTENT_UNLOCKING_META_FILE' 'data/**/*unlocks.meta'
