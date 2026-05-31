--- EMS ligoninių durys / vartai (tas pats E + spynos UI kaip PD)
Config.EmsDoorJob = 'ambulance'

Config.EmsDoorGroups = {}

Config.EmsDoorDynamics = {
    {
        stationId = 'ems_pillbox',
        label = 'EMS durys (Pillbox)',
        bounds = { min = vector3(295.0, -645.0, 25.0), max = vector3(355.0, -535.0, 50.0) },
        models = {
            'gabz_pillbox_entrancedoor_l',
            'gabz_pillbox_entrancedoor_r',
            'gabz_pillbox_doubledoor_l',
            'gabz_pillbox_doubledoor_r',
            'gabz_pillbox_singledoor',
        },
        pairDist = 3.85,
        interactDist = 2.95,
        interactOffset = vector3(0.0, 0.0, 0.88),
    },
    {
        stationId = 'ems_sandy',
        label = 'EMS durys (Sandy)',
        bounds = { min = vector3(1825.0, 3655.0, 32.0), max = vector3(1855.0, 3695.0, 38.0) },
        models = {
            'v_ilev_cor_doorglassa',
            'v_ilev_cor_doorglassb',
            'v_ilev_fh_frontdoor',
            'v_ilev_fh_door01',
            'prop_gate_hospital_01',
        },
        pairDist = 3.5,
        interactDist = 2.85,
        interactOffset = vector3(0.0, 0.0, 0.88),
    },
    {
        stationId = 'ems_paleto',
        label = 'EMS durys (Paleto)',
        bounds = { min = vector3(-265.0, 6320.0, 30.0), max = vector3(-235.0, 6360.0, 38.0) },
        models = {
            'v_ilev_cor_doorglassa',
            'v_ilev_cor_doorglassb',
            'v_ilev_fh_frontdoor',
            'v_ilev_fh_door01',
        },
        pairDist = 3.5,
        interactDist = 2.85,
        interactOffset = vector3(0.0, 0.0, 0.88),
    },
}
