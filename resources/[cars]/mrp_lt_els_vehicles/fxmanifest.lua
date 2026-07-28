fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_lt_els_vehicles'
author 'MRP'
description 'PD/EMS vehicles: ELS (mrpd13-15,21-22,ems) + Skoda non-ELS carcols (mrpd16/23)'
version '1.0.2'

this_is_a_map 'yes'

files {
    'data/**/vehicles.meta',
    'data/**/carvariations.meta',
    'data/**/carcols.meta',
    'data/**/handling.meta',
}

data_file 'HANDLING_FILE' 'data/**/handling.meta'
data_file 'VEHICLE_METADATA_FILE' 'data/**/vehicles.meta'
data_file 'CARCOLS_FILE' 'data/**/carcols.meta'
data_file 'VEHICLE_VARIATION_FILE' 'data/**/carvariations.meta'
