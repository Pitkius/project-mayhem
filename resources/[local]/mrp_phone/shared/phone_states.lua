PhoneStates = PhoneStates or {}

PhoneStates.ACTIVE = 'active'
PhoneStates.LOCKED = 'locked'
PhoneStates.FROZEN = 'frozen'
PhoneStates.EVIDENCE = 'evidence'
PhoneStates.DESTROYED = 'destroyed'

local VALID = {
    active = true,
    locked = true,
    frozen = true,
    evidence = true,
    destroyed = true,
}

function PhoneStates.Normalize(s)
    s = tostring(s or ''):lower()
    if VALID[s] then return s end
    return PhoneStates.ACTIVE
end

function PhoneStates.CanOpen(status)
    status = PhoneStates.Normalize(status)
    return status == PhoneStates.ACTIVE or status == PhoneStates.LOCKED
end

function PhoneStates.BlocksUse(status)
    status = PhoneStates.Normalize(status)
    return status == PhoneStates.FROZEN
        or status == PhoneStates.EVIDENCE
        or status == PhoneStates.DESTROYED
end
