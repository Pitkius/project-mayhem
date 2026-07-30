--- MDT V2 evidence locker vocabulary (Phase 6). Shared for server validation + NUI labels.

MdtEvidenceCase = MdtEvidenceCase or {}

--- Physical locker / storage locations (MRPD evidence room, etc.).
MdtEvidenceCase.LOCKER_LOCATIONS = {
    mrpd_main = 'MRPD — pagrindinė saugykla',
    mrpd_narcotics = 'MRPD — narkotikų saugykla',
    mrpd_weapons = 'MRPD — ginklų saugykla',
    sandy_pd = 'Sandy Shores PD saugykla',
    mobile = 'Mobili saugykla / transportas',
    court_hold = 'Teismo laikinas saugojimas',
    other = 'Kita vieta',
}

MdtEvidenceCase.CATEGORIES = {
    weapon = 'Ginklas',
    ammo = 'Šoviniai',
    drugs = 'Narkotinės medžiagos',
    cash = 'Grynieji',
    document = 'Dokumentai',
    electronics = 'Elektronika',
    clothing = 'Drabužiai / aksesuarai',
    biological = 'Biologiniai pėdsakai',
    vehicle_part = 'TP dalis',
    other = 'Kita',
}

local function isKey(map, value)
    return value ~= nil and map[tostring(value)] ~= nil
end

function MdtEvidenceCase.IsLockerLocation(value)
    return isKey(MdtEvidenceCase.LOCKER_LOCATIONS, value)
end

function MdtEvidenceCase.IsCategory(value)
    return isKey(MdtEvidenceCase.CATEGORIES, value)
end

function MdtEvidenceCase.Vocabulary()
    return {
        lockerLocations = MdtEvidenceCase.LOCKER_LOCATIONS,
        categories = MdtEvidenceCase.CATEGORIES,
    }
end
