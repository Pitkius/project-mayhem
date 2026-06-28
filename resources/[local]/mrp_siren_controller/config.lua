Config = {}

Config.OpenKey = 'F6'
Config.ValidateDistance = 28.0
--- F6 meniu: vairuotojas gali vairuoti kol pultas atidarytas
Config.KeepInputWhileOpen = true
--- Bet kuri sėdynė (vairuotojas / keleivis / gale) gali jungti sirenas
Config.AllowPassengerControl = true

--- Chat komandos (/pdsirenai, /pdiranga, /emssirenai, /emsdiranga) – tik adminams; žaidėjai naudoja itemus arba F6.
Config.CommandsAdminOnly = true

Config.EmergencyKit = {
    emsKitItem = 'ems_emergency_kit',
    returnKitItemOnRemove = true,
}

Config.Jobs = {
    police = {
        jobName = 'police',
        label = 'Policija',
        defaultVehicleLabel = 'Police Buffalo',
        command = 'pdsirenai',
        kitCommand = 'pdiranga',
        minGrade = 0,
        kitMinGrade = 0,
        modeStateKey = 'ltPdSirenMode',
        kitStateKey = 'ltPdKit',
        serverEvent = 'mrp_ltpd:server:setPdEmergencyMode',
        kitServerEvent = 'mrp_ltpd:server:setPdEmergencyKit',
        clearOnExitEvent = 'mrp_ltpd:server:clearPdEmergencyOnExit',
        permCheck = 'pd_siren_controller',
        kitPermCheck = 'pd_emergency_kit',
        useLtpdPerms = true,
    },
    ambulance = {
        jobName = 'ambulance',
        label = 'Greitoji pagalba',
        defaultVehicleLabel = 'EMS Ambulance',
        command = 'emssirenai',
        kitCommand = 'emsdiranga',
        minGrade = 0,
        modeStateKey = 'ltEmsSirenMode',
        kitStateKey = 'ltEmsKit',
        serverEvent = 'mrp_siren:server:setEmsEmergencyMode',
        kitServerEvent = 'mrp_siren:server:setEmsEmergencyKit',
        clearOnExitEvent = 'mrp_siren:server:clearEmsEmergencyOnExit',
        useLtpdPerms = false,
    },
}

Config.FleetVehicles = {
    police = { 'police', 'police2', 'police3', 'policeb', 'sheriff', 'sheriff2', 'riot', 'polmav', 'buzzard2' },
    ambulance = { 'ambulance', 'ambulance2', 'lguard' },
}

Config.ToneSounds = {
    wail = 'VEHICLES_HORNS_SIREN_1',
    yelp = 'VEHICLES_HORNS_SIREN_2',
    priority = 'VEHICLES_HORNS_POLICE_WARNING',
    airhorn = 'VEHICLES_HORNS_AMBULANCE_WARNING',
}

Config.ToneIntervals = {
    wail = 820,
    yelp = 520,
    priority = 380,
}
