Config = Config or {}

--- Tarnybinių daiktų parduotuvės (nemokamai / $0 — tik on duty)
Config.PoliceSupplyShop = {
    name = 'mrp_pd_supply',
    label = 'PD ginklinė / inventorius',
    items = {
        { name = 'radio', amount = 999, price = 0, slot = 1 },
        { name = 'handcuffs', amount = 999, price = 0, slot = 2 },
        { name = 'ziptie', amount = 999, price = 0, slot = 3 },
        { name = 'bandage', amount = 999, price = 0, slot = 4 },
        { name = 'painkillers', amount = 999, price = 0, slot = 5 },
        { name = 'vehicle_key_copy', amount = 999, price = 0, slot = 6 },
        { name = 'lockpick', amount = 50, price = 25, slot = 7 },
        { name = 'pd_emergency_kit', amount = 50, price = 0, slot = 8 },
        { name = 'weapon_pistol', amount = 25, price = 0, slot = 9 },
        { name = 'weapon_stungun', amount = 50, price = 0, slot = 10 },
        { name = 'weapon_nightstick', amount = 50, price = 0, slot = 11 },
        { name = 'weapon_assaultsmg', amount = 15, price = 0, slot = 12 },
        { name = 'pistol_ammo', amount = 999, price = 0, slot = 13 },
        { name = 'smg_ammo', amount = 999, price = 0, slot = 14 },
        { name = 'armor_police', amount = 50, price = 0, slot = 15 },
        { name = 'armor_light', amount = 50, price = 0, slot = 16 },
        { name = 'armor', amount = 999, price = 0, slot = 17 },
        { name = 'metal_scrap', amount = 999, price = 0, slot = 18 },
        { name = 'weapon_parts', amount = 999, price = 0, slot = 19 },
        { name = 'gun_frame', amount = 999, price = 0, slot = 20 },
        { name = 'gun_barrel', amount = 999, price = 0, slot = 21 },
        { name = 'gun_spring', amount = 999, price = 0, slot = 22 },
        { name = 'gun_trigger', amount = 999, price = 0, slot = 23 },
        { name = 'electronickit', amount = 999, price = 0, slot = 24 },
        { name = 'plastic', amount = 999, price = 0, slot = 25 },
    },
}

--- ARO / ARAS ginklinė (atskirai nuo bendro PD inventoriaus — tik SOR padalinys)
Config.AroWeaponSupplyShop = {
    name = 'mrp_aro_weapon_supply',
    label = 'ARO ginklinė',
    items = {
        { name = 'weapon_heavypistol', amount = 15, price = 0, slot = 1 },
        { name = 'weapon_specialcarbine', amount = 10, price = 0, slot = 2 },
        { name = 'weapon_tacticalsmg', amount = 10, price = 0, slot = 3 },
        { name = 'weapon_heavyrifle', amount = 10, price = 0, slot = 4 },
        { name = 'weapon_pumpshotgun', amount = 10, price = 0, slot = 5 },
        { name = 'weapon_sniperrifle', amount = 5, price = 0, slot = 6 },
        { name = 'pistol_ammo', amount = 999, price = 0, slot = 7 },
        { name = 'smg_ammo', amount = 999, price = 0, slot = 8 },
        { name = 'rifle_ammo', amount = 999, price = 0, slot = 9 },
        { name = 'shotgun_ammo', amount = 999, price = 0, slot = 10 },
        { name = 'snp_ammo', amount = 200, price = 0, slot = 11 },
    },
}

--- Marker taškai (mrp_ltpd 3D markeriai) — serverio atstumo patikra
Config.JobSupplyPoints = {
    { job = 'police', stationId = 'ls_main', coords = vector3(462.23, -981.12, 30.68) },
    { job = 'police', stationId = 'sandy', coords = vector3(1849.12, 3690.04, 34.27) },
}
Config.JobSupplyReach = 5.5

Config.EmsSupplyShop = {
    name = 'mrp_ems_supply',
    label = 'EMS inventorius',
    items = {
        { name = 'bandage', amount = 999, price = 0, slot = 1 },
        { name = 'painkillers', amount = 999, price = 0, slot = 2 },
        { name = 'firstaid', amount = 999, price = 0, slot = 3 },
        { name = 'ifaks', amount = 999, price = 0, slot = 4 },
        { name = 'radio', amount = 999, price = 0, slot = 5 },
        { name = 'vehicle_key_copy', amount = 999, price = 0, slot = 6 },
        { name = 'ems_emergency_kit', amount = 50, price = 0, slot = 7 },
    },
}

Config.RangerSupplyShop = {
    name = 'mrp_ranger_supply',
    label = 'Gamtos apsaugos inventorius',
    items = {
        { name = 'radio', amount = 999, price = 0, slot = 1 },
        { name = 'handcuffs', amount = 999, price = 0, slot = 2 },
        { name = 'armor', amount = 999, price = 0, slot = 3 },
        { name = 'bandage', amount = 999, price = 0, slot = 4 },
        { name = 'weapon_stungun', amount = 50, price = 0, slot = 5 },
        { name = 'weapon_nightstick', amount = 50, price = 0, slot = 6 },
        { name = 'weapon_flashlight', amount = 50, price = 0, slot = 7 },
        { name = 'binoculars', amount = 999, price = 0, slot = 8 },
        { name = 'vehicle_key_copy', amount = 999, price = 0, slot = 9 },
    },
}

--- NPC taškai prie tarnybų MLO (duty = pamaina)
--- role: supply | garage | locker | stash | duty | boss
--- PD registratūra — tik qb-target (mrp_ltpd/client/reception.lua)
Config.JobStationNpcs = {
    --- Pamainos pradžia / pabaiga — Mission Row (NTeam MRPD)
    {
        job = 'police',
        stationId = 'ls_main',
        role = 'duty',
        model = 's_m_y_cop_01',
        coords = vector4(440.085, -974.924, 30.689, 90.654),
        label = 'PD pamaina (pradėti / baigti)',
    },
    { job = 'police', stationId = 'ls_main', role = 'supply', model = 's_m_y_cop_01', coords = vector4(462.23, -981.12, 30.68, 90.654), label = 'PD ginklinė / inventorius' },

    --- Pamainos pradžia / pabaiga (tik policijai) — Sandy Shores
    {
        job = 'police',
        stationId = 'sandy',
        role = 'duty',
        model = 's_m_y_cop_01',
        coords = vector4(1853.2, 3686.5, 34.27, 210.0),
        label = 'PD pamaina (pradėti / baigti)',
    },
    { job = 'police', stationId = 'sandy', role = 'supply', model = 's_m_y_cop_01', coords = vector4(1849.12, 3690.04, 34.27, 210.0), label = 'PD ginklinė / inventorius' },

    --- EMS Pillbox (Gabz MLO)
    { job = 'ambulance', stationId = 'ems_ls', role = 'duty', model = 's_m_m_doctor_01', coords = vector4(309.52, -595.29, 43.28, 71.0), label = 'EMS registratūra / tarnyba' },
    { job = 'ambulance', stationId = 'ems_ls', role = 'supply', model = 's_m_m_doctor_01', coords = vector4(306.36, -601.55, 43.28, 250.0), label = 'EMS inventorius' },
    { job = 'ambulance', stationId = 'ems_ls', role = 'garage', model = 's_m_m_paramedic_01', coords = vector4(339.32, -584.32, 28.80, 70.0), label = 'EMS garažas / transportas' },
    { job = 'ambulance', stationId = 'ems_ls', role = 'locker', model = 's_f_y_scrubs_01', coords = vector4(298.62, -598.41, 43.28, 250.0), label = 'EMS rūbinė' },
    { job = 'ambulance', stationId = 'ems_ls', role = 'stash', model = 's_m_m_doctor_01', coords = vector4(306.36, -601.55, 43.28, 250.0), label = 'EMS sandėlis' },

    --- EMS Sandy
    { job = 'ambulance', stationId = 'ems_sandy', role = 'duty', model = 's_m_m_doctor_01', coords = vector4(1839.6, 3672.9, 34.28, 30.0), label = 'EMS registratūra / tarnyba' },
    { job = 'ambulance', stationId = 'ems_sandy', role = 'supply', model = 's_m_m_doctor_01', coords = vector4(1837.2, 3674.5, 34.28, 210.0), label = 'EMS inventorius' },
    { job = 'ambulance', stationId = 'ems_sandy', role = 'garage', model = 's_m_m_paramedic_01', coords = vector4(1843.5, 3663.8, 33.85, 210.0), label = 'EMS garažas / transportas' },
    { job = 'ambulance', stationId = 'ems_sandy', role = 'locker', model = 's_f_y_scrubs_01', coords = vector4(1841.0, 3671.0, 34.28, 210.0), label = 'EMS rūbinė' },
    { job = 'ambulance', stationId = 'ems_sandy', role = 'stash', model = 's_m_m_doctor_01', coords = vector4(1837.2, 3674.5, 34.28, 210.0), label = 'EMS sandėlis' },

    --- EMS Paleto
    { job = 'ambulance', stationId = 'ems_paleto', role = 'duty', model = 's_m_m_doctor_01', coords = vector4(-247.76, 6331.39, 32.43, 135.0), label = 'EMS registratūra / tarnyba' },
    { job = 'ambulance', stationId = 'ems_paleto', role = 'supply', model = 's_m_m_doctor_01', coords = vector4(-249.5, 6333.0, 32.43, 315.0), label = 'EMS inventorius' },
    { job = 'ambulance', stationId = 'ems_paleto', role = 'garage', model = 's_m_m_paramedic_01', coords = vector4(-254.0, 6347.0, 32.50, 135.0), label = 'EMS garažas / transportas' },
    { job = 'ambulance', stationId = 'ems_paleto', role = 'locker', model = 's_f_y_scrubs_01', coords = vector4(-246.0, 6329.5, 32.43, 315.0), label = 'EMS rūbinė' },
    { job = 'ambulance', stationId = 'ems_paleto', role = 'stash', model = 's_m_m_doctor_01', coords = vector4(-249.5, 6333.0, 32.43, 315.0), label = 'EMS sandėlis' },

    --- Gamtos apsauga (Gabz Park Ranger)
    { job = 'ranger', stationId = 'ranger_main', role = 'duty', model = 's_m_y_ranger_01', coords = vector4(380.50, 796.80, 190.49, 180.0), label = 'Tarnyba — pradėti / baigti' },
    { job = 'ranger', stationId = 'ranger_main', role = 'boss', model = 's_m_y_ranger_01', coords = vector4(386.72, 798.67, 190.49, 187.29), label = 'Gamtos apsaugos vadovybė' },
    { job = 'ranger', stationId = 'ranger_main', role = 'locker', model = 's_m_y_ranger_01', coords = vector4(387.64, 799.81, 187.46, 176.41), label = 'Gamtos apsaugos rūbinė' },
    { job = 'ranger', stationId = 'ranger_main', role = 'garage', model = 's_m_y_ranger_01', coords = vector4(371.33, 791.31, 187.47, 261.00), label = 'Gamtos apsaugos garažas / salonas' },
    { job = 'ranger', stationId = 'ranger_main', role = 'stash', model = 's_m_y_ranger_01', coords = vector4(385.39, 799.86, 190.49, 0.17), label = 'Gamtosaugininko daiktadėžė' },
    { job = 'ranger', stationId = 'ranger_main', role = 'supply', model = 's_m_y_ranger_01', coords = vector4(383.23, 794.67, 190.49, 88.84), label = 'Gamtos apsaugos inventorius' },
}

Config.JobNpcReach = 4.5

--- Sandėlių atidarymo klavišas (F2 = 289)
Config.StashOpenControl = 289
Config.StashOpenKeyLabel = 'F2'

--- Garažų / sandėlių / rūbinių 3D markeriai (role garage | stash | locker — be NPC)
Config.JobMarkerDrawDistance = 22.0
Config.JobMarkerUseRadius = 2.6
Config.JobMarkerStashUseRadius = 2.2
Config.JobMarkerLockerUseRadius = 2.0
Config.JobMarkerTypes = { garage = 36, stash = 2, locker = 2, armory = 2, supply = 2, mdt = 2, duty = 2 }
Config.JobMarkerScale = { x = 2.4, y = 2.4, z = 0.24 }
Config.JobMarkerGarageScale = { x = 1.15, y = 1.15, z = 1.15 }
Config.JobMarkerStashScale = { x = 0.32, y = 0.32, z = 0.32 }
Config.JobMarkerLockerScale = { x = 0.48, y = 0.48, z = 0.48 }
Config.JobMarkerArmoryScale = { x = 0.52, y = 0.52, z = 0.52 }
