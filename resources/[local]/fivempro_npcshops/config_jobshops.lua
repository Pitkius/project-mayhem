Config = Config or {}

--- Tarnybinių daiktų parduotuvės (nemokamai / $0 — tik on duty)
Config.PoliceSupplyShop = {
    name = 'fivempro_pd_supply',
    label = 'PD inventorius',
    items = {
        { name = 'radio', amount = 999, price = 0, slot = 1 },
        { name = 'handcuffs', amount = 999, price = 0, slot = 2 },
        { name = 'armor', amount = 999, price = 0, slot = 3 },
        { name = 'bandage', amount = 999, price = 0, slot = 4 },
        { name = 'painkillers', amount = 999, price = 0, slot = 5 },
        { name = 'vehicle_key_copy', amount = 999, price = 0, slot = 6 },
        { name = 'lockpick', amount = 50, price = 25, slot = 7 },
    },
}

Config.EmsSupplyShop = {
    name = 'fivempro_ems_supply',
    label = 'EMS inventorius',
    items = {
        { name = 'bandage', amount = 999, price = 0, slot = 1 },
        { name = 'painkillers', amount = 999, price = 0, slot = 2 },
        { name = 'firstaid', amount = 999, price = 0, slot = 3 },
        { name = 'ifaks', amount = 999, price = 0, slot = 4 },
        { name = 'radio', amount = 999, price = 0, slot = 5 },
        { name = 'vehicle_key_copy', amount = 999, price = 0, slot = 6 },
    },
}

Config.RangerSupplyShop = {
    name = 'fivempro_ranger_supply',
    label = 'Gamtos apsaugos inventorius',
    items = {
        { name = 'radio', amount = 999, price = 0, slot = 1 },
        { name = 'handcuffs', amount = 999, price = 0, slot = 2 },
        { name = 'armor', amount = 999, price = 0, slot = 3 },
        { name = 'bandage', amount = 999, price = 0, slot = 4 },
        { name = 'weapon_stungun', amount = 50, price = 0, slot = 5 },
        { name = 'weapon_nightstick', amount = 50, price = 0, slot = 6 },
        { name = 'weapon_flashlight', amount = 50, price = 0, slot = 7 },
        { name = 'weapon_pistol', amount = 25, price = 0, slot = 8 },
        { name = 'pistol_ammo', amount = 999, price = 0, slot = 9 },
        { name = 'binoculars', amount = 999, price = 0, slot = 10 },
        { name = 'vehicle_key_copy', amount = 999, price = 0, slot = 11 },
    },
}

--- NPC taškai prie PD / EMS MLO (supply, garažas, rūbinė, sandėlis)
--- role: supply | garage | locker | stash | duty | boss
Config.JobStationNpcs = {
    --- LS MRPD (Gabz)
    { job = 'police', stationId = 'ls_main', role = 'supply', model = 's_m_y_cop_01', coords = vector4(451.2, -993.4, 30.69, 270.0), label = 'PD inventorius' },
    { job = 'police', stationId = 'ls_main', role = 'garage', model = 's_m_y_cop_01', coords = vector4(441.64, -1013.14, 28.62, 175.52), label = 'PD garažas / transportas' },
    { job = 'police', stationId = 'ls_main', role = 'locker', model = 's_f_y_cop_01', coords = vector4(461.85, -998.35, 30.69, 90.0), label = 'PD rūbinė' },
    { job = 'police', stationId = 'ls_main', role = 'stash', model = 's_m_y_cop_01', coords = vector4(449.55, -993.45, 30.69, 270.0), label = 'PD sandėlis' },

    --- Davis PD (Gabz)
    { job = 'police', stationId = 'davis', role = 'supply', model = 's_m_y_cop_01', coords = vector4(374.04, -1608.08, 29.29, 320.0), label = 'PD inventorius' },
    { job = 'police', stationId = 'davis', role = 'garage', model = 's_m_y_cop_01', coords = vector4(397.85, -1607.09, 29.29, 230.0), label = 'PD garažas / transportas' },
    { job = 'police', stationId = 'davis', role = 'locker', model = 's_f_y_cop_01', coords = vector4(365.13, -1598.32, 25.45, 320.0), label = 'PD rūbinė' },
    { job = 'police', stationId = 'davis', role = 'stash', model = 's_m_y_cop_01', coords = vector4(373.2, -1606.5, 29.29, 320.0), label = 'PD sandėlis' },

    --- Sandy PD
    { job = 'police', stationId = 'sandy', role = 'supply', model = 's_m_y_sheriff_01', coords = vector4(1849.12, 3690.04, 34.27, 210.0), label = 'PD inventorius' },
    { job = 'police', stationId = 'sandy', role = 'garage', model = 's_m_y_sheriff_01', coords = vector4(1869.5, 3695.2, 33.53, 210.0), label = 'PD garažas / transportas' },
    { job = 'police', stationId = 'sandy', role = 'locker', model = 's_f_y_sheriff_01', coords = vector4(1851.2, 3689.1, 34.27, 210.0), label = 'PD rūbinė' },
    { job = 'police', stationId = 'sandy', role = 'stash', model = 's_m_y_sheriff_01', coords = vector4(1850.5, 3691.5, 34.27, 210.0), label = 'PD sandėlis' },

    --- Paleto PD
    { job = 'police', stationId = 'paleto', role = 'supply', model = 's_m_y_sheriff_01', coords = vector4(-449.38, 6014.12, 31.72, 45.0), label = 'PD inventorius' },
    { job = 'police', stationId = 'paleto', role = 'garage', model = 's_m_y_sheriff_01', coords = vector4(-459.2, 6016.3, 31.49, 45.0), label = 'PD garažas / transportas' },
    { job = 'police', stationId = 'paleto', role = 'locker', model = 's_f_y_sheriff_01', coords = vector4(-448.9, 6013.2, 31.72, 45.0), label = 'PD rūbinė' },
    { job = 'police', stationId = 'paleto', role = 'stash', model = 's_m_y_sheriff_01', coords = vector4(-450.5, 6015.2, 31.72, 45.0), label = 'PD sandėlis' },

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

--- Garažų / sandėlių 3D markeriai (role garage | stash — be NPC)
Config.JobMarkerDrawDistance = 28.0
Config.JobMarkerUseRadius = 2.2
Config.JobMarkerScale = { x = 2.4, y = 2.4, z = 0.24 }
Config.JobMarkerGarageScale = { x = 3.2, y = 3.2, z = 0.28 }
Config.JobMarkerStashScale = { x = 2.0, y = 2.0, z = 0.22 }
