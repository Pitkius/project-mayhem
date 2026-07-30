--- MDT V2 police case vocabulary (Phase 3). Shared so the NUI can render the
--- same labels the server validates against. Keys are canonical snake_case.

MdtPoliceCase = MdtPoliceCase or {}

--- How the case ended for the subject(s).
MdtPoliceCase.DISPOSITIONS = {
    pending = 'Tiriama',
    no_action = 'Be veiksmų',
    warning = 'Žodinis įspėjimas',
    citation = 'Bauda',
    arrest = 'Areštas',
    referred = 'Perduota prokuratūrai',
    unfounded = 'Nepasitvirtino',
}

--- Use-of-force ladder (lowest → highest).
MdtPoliceCase.FORCE_TYPES = {
    none = 'Nenaudota',
    presence = 'Pareigūno buvimas',
    verbal = 'Žodinis nurodymas',
    restraint = 'Antrankiai / surakinimas',
    hands = 'Fizinė jėga',
    baton = 'Tonfa',
    spray = 'Dujos',
    taser = 'Elektros impulsinis prietaisas',
    k9 = 'Tarnybinis šuo',
    vehicle = 'Transporto priemonė (PIT / blokavimas)',
    firearm = 'Šaunamasis ginklas',
}

MdtPoliceCase.FORCE_INJURIES = {
    none = 'Nėra',
    minor = 'Lengvi',
    serious = 'Sunkūs',
    fatal = 'Mirtis',
}

--- Force levels that flag the case as `weapon_involved`.
MdtPoliceCase.ARMED_FORCE_TYPES = {
    taser = true,
    firearm = true,
}

--- Equipment logged on scene (not weapons — those go on the force row).
MdtPoliceCase.TOOL_TYPES = {
    handcuffs = 'Antrankiai',
    spikes = 'Dygliai',
    ram = 'Prasilaužimo įranga',
    radar = 'Radaras',
    breathalyzer = 'Alkotesteris',
    drugtest = 'Narkotikų testas',
    fingerprint_kit = 'Atspaudų rinkinys',
    evidence_kit = 'Įkalčių rinkinys',
    k9 = 'Tarnybinis šuo',
    drone = 'Dronas',
    helicopter = 'Sraigtasparnis',
    barrier = 'Kelio užtvaros',
    other = 'Kita',
}

MdtPoliceCase.SEIZED_CATEGORIES = {
    weapon = 'Ginklas',
    ammo = 'Šoviniai',
    drugs = 'Narkotinės medžiagos',
    cash = 'Grynieji',
    vehicle = 'Transporto priemonė',
    document = 'Dokumentai',
    electronics = 'Elektronika',
    evidence = 'Įkaltis',
    other = 'Kita',
}

--- Typed pointers into rows owned by other resources (mdt_incident_refs.ref_type).
--- `stub = true` — the owning system lands in Phase 6, only the handle is stored now.
MdtPoliceCase.REF_TYPES = {
    fine = { label = 'Bauda', table = 'ltpd_fines' },
    arrest = { label = 'Areštas', table = 'ltpd_arrests' },
    fingerprint = { label = 'Pirštų atspaudai', table = 'ltpd_fingerprints' },
    interrogation = { label = 'Apklausa', table = 'ltpd_interrogations' },
    wanted = { label = 'Paieškomumas', table = 'ltpd_wanted' },
    bodycam = { label = 'Kūno kamera', table = 'ltpd_bodycam_sessions' },
    cctv = { label = 'Vaizdo stebėjimas', table = 'ltpd_cctv_views' },
    photo = { label = 'Fotofiksacija', stub = true },
    evidence = { label = 'Įkalčių saugykla', table = 'mdt_evidence_items' },
    warrant = { label = 'Orderis', stub = true },
    other = { label = 'Kita', stub = true },
}

MdtPoliceCase.OFFICER_ROLES = {
    lead = 'Bylos vadovas',
    assist = 'Padėjo',
    supervisor = 'Vadovaujantis pareigūnas',
    transport = 'Konvojavimas',
    scene = 'Vietos apsauga',
    investigator = 'Tyrėjas',
}

--- Party roles the PD UI offers (subset of MdtIncidentLinks party roles).
MdtPoliceCase.PARTY_ROLES = {
    suspect = 'Įtariamasis',
    victim = 'Nukentėjęs',
    witness = 'Liudytojas',
    complainant = 'Pareiškėjas',
    driver = 'Vairuotojas',
    passenger = 'Keleivis',
    owner = 'Savininkas',
    other = 'Kita',
}

MdtPoliceCase.VEHICLE_ROLES = {
    suspect_vehicle = 'Įtariamojo TP',
    victim_vehicle = 'Nukentėjusio TP',
    involved = 'Susijusi TP',
    towed = 'Nuvilkta',
    impounded = 'Areštuota',
    recovered = 'Rasta / grąžinta',
    evidence = 'Įkaltis',
}

local function isKey(map, value)
    return value ~= nil and map[tostring(value)] ~= nil
end

function MdtPoliceCase.IsDisposition(value) return isKey(MdtPoliceCase.DISPOSITIONS, value) end
function MdtPoliceCase.IsForceType(value) return isKey(MdtPoliceCase.FORCE_TYPES, value) end
function MdtPoliceCase.IsInjury(value) return isKey(MdtPoliceCase.FORCE_INJURIES, value) end
function MdtPoliceCase.IsToolType(value) return isKey(MdtPoliceCase.TOOL_TYPES, value) end
function MdtPoliceCase.IsSeizedCategory(value) return isKey(MdtPoliceCase.SEIZED_CATEGORIES, value) end
function MdtPoliceCase.IsRefType(value) return isKey(MdtPoliceCase.REF_TYPES, value) end
function MdtPoliceCase.IsOfficerRole(value) return isKey(MdtPoliceCase.OFFICER_ROLES, value) end

function MdtPoliceCase.RefTable(refType)
    local entry = MdtPoliceCase.REF_TYPES[tostring(refType or '')]
    return entry and entry.table or nil
end

--- Everything the NUI needs to build its selects in one payload.
function MdtPoliceCase.Vocabulary()
    return {
        dispositions = MdtPoliceCase.DISPOSITIONS,
        forceTypes = MdtPoliceCase.FORCE_TYPES,
        injuries = MdtPoliceCase.FORCE_INJURIES,
        toolTypes = MdtPoliceCase.TOOL_TYPES,
        seizedCategories = MdtPoliceCase.SEIZED_CATEGORIES,
        refTypes = MdtPoliceCase.REF_TYPES,
        officerRoles = MdtPoliceCase.OFFICER_ROLES,
        partyRoles = MdtPoliceCase.PARTY_ROLES,
        vehicleRoles = MdtPoliceCase.VEHICLE_ROLES,
    }
end
