--[[
Koordinatės derintos prie tipinių Gabz MLO (žr. dokumentaciją / alexwilliam gabz coords maps).
„Hub“ ir „Car Meet“ – pagal įdiegtų resursų (cfx-gabz-hub / cfx-gabz-carmeet) interjerų vietas projekte.
]]

Config = {}

Config.ShortRange = true
Config.DefaultScale = 0.75

Config.Blips = {
    -- Policijos
    { resource = 'cfx-gabz-mrpd', label = 'MLO: Mission Row PD', coords = vec3(427.12, -979.56, 30.72), sprite = 60, color = 38 },
    {
        resources = {
            'cfx-gabz-davispd',
            'gabz_davispd',
            'gabz_davis_pd',
            'gabz-davispd',
        },
        label = 'MLO: Davis PD',
        coords = vec3(383.42, -1590.41, 29.28),
        sprite = 60,
        color = 38,
    },
    { resource = 'cfx-gabz-sandypd', label = 'MLO: Sandy PD', coords = vec3(1871.45, 3664.96, 33.69), sprite = 60, color = 38 },
    { resource = 'cfx-gabz-paletopd', label = 'MLO: Paleto PD', coords = vec3(-432.18, 6019.61, 31.49), sprite = 60, color = 38 },
    { resource = 'cfx-gabz-parkranger', label = 'MLO: Park Ranger', coords = vec3(388.64, 787.82, 187.47), sprite = 60, color = 25 },

    -- Kiti
    { resource = 'cfx-gabz-pillbox', label = 'MLO: Pillbox', coords = vec3(286.56, -570.57, 43.17), sprite = 61, color = 2 },
    { resource = 'cfx-gabz-pacificbank', label = 'MLO: Pacific Bank', coords = vec3(223.31, 208.30, 105.52), sprite = 108, color = 2 },
    { resource = 'cfx-gabz-townhall', label = 'MLO: Townhall', coords = vec3(-541.0, -210.0, 37.0), sprite = 525, color = 3 },
    { resource = 'cfx-gabz-catcafe', label = 'MLO: Cat Cafe', coords = vec3(-580.86, -1079.08, 22.33), sprite = 89, color = 48 },
    { resource = 'cfx-gabz-vu', label = 'MLO: Vanilla Unicorn', coords = vec3(135.41, -1308.93, 28.99), sprite = 121, color = 48 },
    { resource = 'cfx-gabz-tuners', label = 'MLO: Tuner Shop', coords = vec3(166.72, -3014.12, 5.89), sprite = 72, color = 5 },
    { resource = 'cfx-gabz-ottos', label = 'MLO: Otto\'s Auto', coords = vec3(793.0, -817.0, 27.0), sprite = 72, color = 46 },
    { resource = 'cfx-gabz-harmony', label = 'MLO: Harmony Repair', coords = vec3(1179.0, 2653.99, 37.86), sprite = 72, color = 46 },
    --- Interjeras pagal `cfx-gabz-carmeet/client.lua` (GetInteriorAtCoords ...)
    {
        resources = { 'cfx-gabz-carmeet', 'gabz_carmeet', 'gabz_lscarmeet' },
        label = 'MLO: Car Meet',
        coords = vec3(1113.97, -1806.53, 20.03),
        sprite = 380,
        color = 46,
    },
    { resource = 'cfx-gabz-bowling', label = 'MLO: Bowling', coords = vec3(760.79, -777.72, 26.46), sprite = 103, color = 17 },
    { resources = { 'cfx-gabz-records', 'gabz_recordstudio', 'gabz_studio' }, label = 'MLO: Record Studio', coords = vec3(478.999, -108.676, 63.155), sprite = 136, color = 27 },
    --- Gabz Hub / Downtown supermod įėjimas prie bennų
    { resources = { 'cfx-gabz-hub', 'gabz_hub', 'cfx-gabz-bennys' }, label = 'MLO: Hub', coords = vec3(-237.19, -1327.39, 31.30), sprite = 280, color = 0 },
}
