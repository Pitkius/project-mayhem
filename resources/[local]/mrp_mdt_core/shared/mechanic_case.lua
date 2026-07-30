--- MDT V2 mechanic repair case vocabulary (Phase 5). Shared so the NUI renders the
--- same labels the server validates against.

MdtMechanicCase = MdtMechanicCase or {}

--- How the repair call ended.
MdtMechanicCase.DISPOSITIONS = {
    pending = 'Tiriama',
    repaired_on_scene = 'Remontas vietoje',
    towed = 'Nutempta',
    impounded = 'Konfiskuota / impound',
    declined = 'Klientas atsisakė',
    no_fault = 'Gedimo neaptikta',
    referred = 'Perduota kitai dirbtuvei',
    parts_ordered = 'Užsakytos dalys',
}

--- Chief fault / complaint categories.
MdtMechanicCase.FAULTS = {
    engine = 'Variklis',
    transmission = 'Transmisija',
    electrical = 'Elektrika',
    brakes = 'Stabdžiai',
    suspension = 'Važiuoklė',
    body = 'Kėbulas',
    tires = 'Padangos / ratai',
    fuel = 'Kuro sistema',
    cooling = 'Aušinimas',
    accident = 'Po eismo įvykio',
    towing = 'Nutempimas',
    inspection = 'Apžiūra / diagnostika',
    other = 'Kita',
}

--- Diagnostic checks logged on scene (append-only rows).
MdtMechanicCase.DIAG_TYPES = {
    obd_scan = 'OBD / klaidų skaitymas',
    compression = 'Kompresijos testas',
    battery = 'Akumuliatorius / starteris',
    fluids = 'Skysčių lygiai',
    visual = 'Vizualinė apžiūra',
    road_test = 'Bandymas kelyje',
    alignment = 'Geometrija / suvedimas',
    other = 'Kita',
}

MdtMechanicCase.DIAG_RESULTS = {
    pass = 'Gerai',
    fail = 'Gedimas',
    warning = 'Dėmesio',
    unknown = 'Neaišku',
}

--- Repair work performed (append-only rows).
MdtMechanicCase.WORK_TYPES = {
    repair = 'Remontas',
    replace = 'Keitimas',
    adjust = 'Reguliavimas',
    bleed = 'Išpūtimas / valymas',
    tow_hook = 'Prisikabinimas / tempimas',
    unlock = 'Atrakimas',
    refuel = 'Kuro papildymas',
    wash = 'Plovimas',
    other = 'Kita',
}

--- Parts replaced (append-only rows).
MdtMechanicCase.PART_CATEGORIES = {
    engine = 'Variklio dalys',
    transmission = 'Transmisija',
    brakes = 'Stabdžiai',
    suspension = 'Važiuoklė',
    electrical = 'Elektrika',
    body = 'Kėbulas',
    tires = 'Padangos',
    fluids = 'Skysčiai / filtrai',
    consumable = 'Sąnaudos',
    other = 'Kita',
}

--- Typed pointers (mdt_incident_refs.ref_type) for mechanic incidents.
MdtMechanicCase.REF_TYPES = {
    invoice = { label = 'Sąskaita', table = 'fivempro_service_invoices' },
    tow = { label = 'Nutempimas', stub = true },
    photo = { label = 'Fotofiksacija', stub = true },
    other = { label = 'Kita', stub = true },
}

MdtMechanicCase.MECHANIC_ROLES = {
    lead = 'Vadovaujantis mechanikas',
    assist = 'Padėjo',
    supervisor = 'Vyresnysis mechanikas',
    tow = 'Vilkikas / tempimas',
    scene = 'Vietos darbai',
}

MdtMechanicCase.PARTY_ROLES = {
    client = 'Klientas',
    owner = 'Savininkas',
    driver = 'Vairuotojas',
    witness = 'Liudytojas',
    other = 'Kita',
}

MdtMechanicCase.VEHICLE_ROLES = {
    subject = 'Remontuojamas TP',
    towed = 'Nutemptas',
    impounded = 'Impound',
    other = 'Kita',
}

local function isKey(map, value)
    return value ~= nil and map[tostring(value)] ~= nil
end

function MdtMechanicCase.IsDisposition(value) return isKey(MdtMechanicCase.DISPOSITIONS, value) end
function MdtMechanicCase.IsFault(value) return isKey(MdtMechanicCase.FAULTS, value) end
function MdtMechanicCase.IsDiagType(value) return isKey(MdtMechanicCase.DIAG_TYPES, value) end
function MdtMechanicCase.IsDiagResult(value) return isKey(MdtMechanicCase.DIAG_RESULTS, value) end
function MdtMechanicCase.IsWorkType(value) return isKey(MdtMechanicCase.WORK_TYPES, value) end
function MdtMechanicCase.IsPartCategory(value) return isKey(MdtMechanicCase.PART_CATEGORIES, value) end
function MdtMechanicCase.IsRefType(value) return isKey(MdtMechanicCase.REF_TYPES, value) end
function MdtMechanicCase.IsMechanicRole(value) return isKey(MdtMechanicCase.MECHANIC_ROLES, value) end
function MdtMechanicCase.IsPartyRole(value) return isKey(MdtMechanicCase.PARTY_ROLES, value) end
function MdtMechanicCase.IsVehicleRole(value) return isKey(MdtMechanicCase.VEHICLE_ROLES, value) end

function MdtMechanicCase.RefTable(refType)
    local entry = MdtMechanicCase.REF_TYPES[tostring(refType or '')]
    return entry and entry.table or nil
end

function MdtMechanicCase.Vocabulary()
    return {
        dispositions = MdtMechanicCase.DISPOSITIONS,
        faults = MdtMechanicCase.FAULTS,
        diagTypes = MdtMechanicCase.DIAG_TYPES,
        diagResults = MdtMechanicCase.DIAG_RESULTS,
        workTypes = MdtMechanicCase.WORK_TYPES,
        partCategories = MdtMechanicCase.PART_CATEGORIES,
        refTypes = MdtMechanicCase.REF_TYPES,
        mechanicRoles = MdtMechanicCase.MECHANIC_ROLES,
        partyRoles = MdtMechanicCase.PARTY_ROLES,
        vehicleRoles = MdtMechanicCase.VEHICLE_ROLES,
    }
end
