--- Gabz Park Ranger MLO durys / vartai (E + spynos UI, tik gamtosaugininkams tarnyboje)
Config.RangerDoorJob = 'ranger'

Config.RangerDoorGroups = {}

--- Automatinis durų skenavimas MLO viduje (visos sanhje durys / celės)
Config.RangerDoorDynamics = {
    {
        stationId = 'ranger_main',
        label = 'Gamtos apsaugos durys',
        bounds = {
            min = vector3(355.0, 775.0, 184.0),
            max = vector3(400.0, 808.0, 192.5),
        },
        models = {
            'sanhje_parkranger_door',
            'sanhje_parkranger_celldoor',
            'sanhje_parkranger_cell_gate',
        },
        pairDist = 3.5,
        interactDist = 2.85,
        interactOffset = vector3(0.0, 0.0, 0.88),
    },
    --- Aikštelės / išorės vartai (netoli garažo)
    {
        stationId = 'ranger_yard',
        label = 'Gamtos apsaugos vartai',
        bounds = {
            min = vector3(358.0, 778.0, 184.0),
            max = vector3(382.0, 798.0, 191.0),
        },
        models = {
            'prop_facgate_07b',
            'prop_gate_military_01',
            'prop_lrggate_01',
            'prop_gate_airport_01',
        },
        pairDist = 4.5,
        interactDist = 3.0,
        interactOffset = vector3(0.0, 0.0, 0.88),
        doorType = 'barrier',
    },
}
