Config = {}

--[[
  mrp_siren_controller — F6 sirenos ir emergency kit (police / EMS).

  Integracija:
    · police — leidimai per mrp_ltpd Config.Permissions (useLtpdPerms)
    · Config.FleetVehicles — modeliai, kuriems leidžiama F6 (mrpd*, polmav…)
    · statebag sinchronizacija — matoma visiems klientams

  Itemai: pd_emergency_kit (police), ems_emergency_kit (EMS)
]]

Config.OpenKey = 'F6'
Config.ValidateDistance = 28.0
--- MRPD / fleet: E veikia kaip vanilla policijos mašinoje (full <-> off).
Config.VanillaEToggle = true
Config.VanillaEToggleControl = 86 -- INPUT_VEH_HORN (E)
Config.VanillaEToggleDebounceMs = 450
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

-- F6: Non-ELS + ELS (ELS šviesas jungia ApplyEmergencyMode bridge).
Config.FleetVehicles = {
    police = {
        'mrpd1', 'mrpd2', 'mrpd3', 'mrpd4', 'mrpd5', 'mrpd6', 'mrpd7', 'mrpd8',
        'mrpd9', 'mrpd10', 'mrpd11', 'mrpd12', 'mrpd24', 'mrpd25', 'mrpd26',
        'mrpd13', 'mrpd14', 'mrpd15', 'mrpd16', 'mrpd23',
        'mrpd17', 'mrpd18', 'mrpd19', 'mrpd20',
        'mrpd21', 'mrpd22',
        'polmav', 'buzzard2',
    },
    ambulance = { 'ambulance', 'ambulance2', 'lguard', 'ems1', 'ems2', 'granger' },
}

--- Modeliai, kuriems F6 režimą map'inam į ELS-FiveM (ne SetVehicleSiren).
--- mrpd16/mrpd23 = native carcols (ne ELS extras).
Config.ElsFleetVehicles = {
    'mrpd13', 'mrpd14', 'mrpd15', 'mrpd21', 'mrpd22',
    'ems1', 'ems2',
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
