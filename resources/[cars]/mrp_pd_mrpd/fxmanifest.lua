fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_pd_mrpd'
author 'MRP'
description 'Mission Row PD vehicle pack (MRPD 1-16)'
version '2.0.0'

--- Originali FiveM pack'o struktūra: kiekvienas modelis krauna savo carcols.
--- ID yra unikalūs, todėl vieno modelio schema neperrašo kito.
files {
    'data/**/carcols.meta',
    'data/**/carvariations.meta',
    'data/**/handling.meta',
    'data/**/vehicles.meta',
}

data_file 'CARCOLS_FILE' 'data/**/carcols.meta'
data_file 'VEHICLE_VARIATION_FILE' 'data/**/carvariations.meta'
data_file 'HANDLING_FILE' 'data/**/handling.meta'
data_file 'VEHICLE_METADATA_FILE' 'data/**/vehicles.meta'
