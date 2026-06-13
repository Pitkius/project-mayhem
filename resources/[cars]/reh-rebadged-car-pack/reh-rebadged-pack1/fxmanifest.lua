

fx_version "cerulean"
game "gta5"
name "reh-rebadged-pack1"
author "rehdacted"
description "REH Rebadged Car Pack 1"
version "1.0.0"
lua54 "yes"

files({
    "data/**/vehicles.meta",
    "data/**/carvariations.meta",
    "data/**/carcols.meta",
    "data/**/handling.meta",
    "data/**/vehiclelayouts.meta",
    "data/**/*.meta",
    "data/**/*.xml"
})

data_file "HANDLING_FILE" "data/**/handling.meta"
data_file "VEHICLE_METADATA_FILE" "data/**/vehicles.meta"
data_file "CARCOLS_FILE" "data/**/carcols.meta"
data_file "VEHICLE_VARIATION_FILE" "data/**/carvariations.meta"
data_file "VEHICLE_LAYOUTS_FILE" "data/**/vehiclelayouts.meta"
data_file "CONTENT_UNLOCKING_META_FILE" "data/**/*unlocks.meta"
