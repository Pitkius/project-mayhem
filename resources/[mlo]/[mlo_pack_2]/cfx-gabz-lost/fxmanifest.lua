fx_version 'cerulean'
game 'gta5'

lua54 'yes'

this_is_a_map 'yes'

dependencies {
    'cfx-gabz-mapdata',
}

files {
    'stream/ydr/gabz_lost_props.ytyp',
    'stream/ytyp/bkr_biker_dlc_int_02.ytyp',
}

data_file 'DLC_ITYP_REQUEST' 'stream/ydr/gabz_lost_props.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/ytyp/bkr_biker_dlc_int_02.ytyp'

client_script {
    'gabz_lost_entitysets.lua',
}
