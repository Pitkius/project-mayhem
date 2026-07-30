--- MDT V2 EMS medical case vocabulary (Phase 4). Shared so the NUI renders the
--- same labels the server validates against.

MdtMedicalCase = MdtMedicalCase or {}

--- How the call ended for the patient(s).
MdtMedicalCase.DISPOSITIONS = {
    pending = 'Tiriama',
    treated_on_scene = 'Gydyta vietoje',
    transported = 'Hospitalizuotas / transportuotas',
    refused_care = 'Atmesta pagalba',
    deceased = 'Mirtis vietoje',
    referred = 'Perduota kitai tarnybai',
    no_patient = 'Paciento nėra',
}

MdtMedicalCase.TRIAGE_LEVELS = {
    green = 'Žalia (lengva)',
    yellow = 'Geltona (vidutinė)',
    red = 'Raudona (kritinė)',
    black = 'Juoda (miręs / be pagalbos)',
}

--- Chief complaint / presentation categories.
MdtMedicalCase.PRESENTATIONS = {
    trauma = 'Trauma / sužalojimai',
    cardiac = 'Širdies / kraujotakos',
    respiratory = 'Kvėpavimo',
    overdose = 'Apsinuodijimas / perdozavimas',
    burn = 'Nudegimai',
    neuro = 'Neurologiniai',
    obstetric = 'Gimdymas / akušerija',
    psychiatric = 'Psichiatriniai',
    illness = 'Liga / bendra',
    other = 'Kita',
}

--- Procedures logged on scene (append-only rows).
MdtMedicalCase.ACTION_TYPES = {
    assessment = 'Apžiūra / triažas',
    cpr = 'Pirmoji pagalba (CPR)',
    defibrillation = 'Defibriliacija',
    intubation = 'Intubacija / OPA',
    wound_care = 'Žaizdos tvarkymas',
    splint = 'Imobilizacija / tvarstis',
    iv_access = 'IV prieiga',
    blood_draw = 'Kraujo paėmimas',
    oxygen = 'Deguonies terapija',
    extrication = 'Ištraukimas iš TP',
    other = 'Kita',
}

MdtMedicalCase.MED_ROUTES = {
    oral = 'Per burną',
    iv = 'Intraveninė',
    im = 'Intramuskulinė',
    topical = 'Išorinė',
    inhalation = 'Įkvepiamoji',
    other = 'Kita',
}

MdtMedicalCase.EQUIPMENT_TYPES = {
    defibrillator = 'Defibriliatorius',
    stretcher = 'Neštys',
    oxygen = 'Deguonies balionas',
    splint = 'Tvarstis',
    bandage = 'Tvarsčiai / tvarsčiai',
    tourniquet = 'Turniketas',
    monitor = 'Monitorius',
    wheelchair = 'Vežimėlis',
    other = 'Kita',
}

--- Typed pointers (mdt_incident_refs.ref_type) for EMS incidents.
MdtMedicalCase.REF_TYPES = {
    invoice = { label = 'Sąskaita', table = 'fivempro_service_invoices' },
    photo = { label = 'Fotofiksacija', stub = true },
    other = { label = 'Kita', stub = true },
}

MdtMedicalCase.MEDIC_ROLES = {
    lead = 'Vadovaujantis medikas',
    assist = 'Padėjo',
    supervisor = 'Vyresnysis medikas',
    transport = 'Transportas',
    scene = 'Vietos apsauga',
}

MdtMedicalCase.PARTY_ROLES = {
    patient = 'Pacientas',
    bystander = 'Stebėtojas',
    witness = 'Liudytojas',
    driver = 'Vairuotojas',
    passenger = 'Keleivis',
    other = 'Kita',
}

local function isKey(map, value)
    return value ~= nil and map[tostring(value)] ~= nil
end

function MdtMedicalCase.IsDisposition(value) return isKey(MdtMedicalCase.DISPOSITIONS, value) end
function MdtMedicalCase.IsTriage(value) return isKey(MdtMedicalCase.TRIAGE_LEVELS, value) end
function MdtMedicalCase.IsPresentation(value) return isKey(MdtMedicalCase.PRESENTATIONS, value) end
function MdtMedicalCase.IsActionType(value) return isKey(MdtMedicalCase.ACTION_TYPES, value) end
function MdtMedicalCase.IsMedRoute(value) return isKey(MdtMedicalCase.MED_ROUTES, value) end
function MdtMedicalCase.IsEquipmentType(value) return isKey(MdtMedicalCase.EQUIPMENT_TYPES, value) end
function MdtMedicalCase.IsRefType(value) return isKey(MdtMedicalCase.REF_TYPES, value) end
function MdtMedicalCase.IsMedicRole(value) return isKey(MdtMedicalCase.MEDIC_ROLES, value) end

function MdtMedicalCase.RefTable(refType)
    local entry = MdtMedicalCase.REF_TYPES[tostring(refType or '')]
    return entry and entry.table or nil
end

function MdtMedicalCase.Vocabulary()
    return {
        dispositions = MdtMedicalCase.DISPOSITIONS,
        triageLevels = MdtMedicalCase.TRIAGE_LEVELS,
        presentations = MdtMedicalCase.PRESENTATIONS,
        actionTypes = MdtMedicalCase.ACTION_TYPES,
        medRoutes = MdtMedicalCase.MED_ROUTES,
        equipmentTypes = MdtMedicalCase.EQUIPMENT_TYPES,
        refTypes = MdtMedicalCase.REF_TYPES,
        medicRoles = MdtMedicalCase.MEDIC_ROLES,
        partyRoles = MdtMedicalCase.PARTY_ROLES,
    }
end
