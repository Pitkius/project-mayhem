--- Canonical MDT V2 permission names (RBAC). Mapped to job+grade+onduty in config.lua.

MdtPermissions = MdtPermissions or {}

--- Registry used for validation (unknown perm names always deny unless admin bypass).
MdtPermissions.ALL = {
    --- Police MDT
    MDT_OPEN = true,
    MDT_SEARCH = true,
    MDT_SEARCH_FULL = true,
    MDT_EDIT = true,
    MDT_FINE = true,
    MDT_WANTED = true,
    MDT_ARREST = true,
    MDT_REPORT = true,
    MDT_BODYCAM = true,
    MDT_CCTV = true,
    MDT_EVIDENCE = true,
    MDT_LICENSE = true,
    MDT_FINGERPRINT = true,
    MDT_INTERROGATION = true,
    MDT_ADMIN = true,
    --- Incident engine
    INCIDENT_CREATE = true,
    INCIDENT_VIEW = true,
    INCIDENT_ASSIGN = true,
    INCIDENT_TRANSITION = true,
    INCIDENT_CLOSE = true,
    --- EMS / Mechanic service MDT variants
    EMS_MDT_OPEN = true,
    EMS_MDT_INVOICE = true,
    EMS_MDT_REPORT = true,
    EMS_INCIDENT_VIEW = true,
    EMS_INCIDENT_CREATE = true,
    EMS_INCIDENT_TRANSITION = true,
    MECH_MDT_OPEN = true,
    MECH_MDT_INVOICE = true,
    MECH_MDT_REPORT = true,
    MECH_INCIDENT_VIEW = true,
    MECH_INCIDENT_CREATE = true,
    MECH_INCIDENT_TRANSITION = true,
    --- Dispatch / service call creation (on-duty member of that service)
    DISPATCH_CREATE_CALL = true,
}

function MdtPermissions.IsKnown(perm)
    return perm ~= nil and MdtPermissions.ALL[tostring(perm)] == true
end
