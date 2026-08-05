PhonePin = PhonePin or {}

local function cfg()
    return (Config.Phone and Config.Phone.Pin) or {}
end

function PhonePin.IsValidFormat(pin)
    pin = tostring(pin or '')
    local len = tonumber(cfg().length) or 4
    if #pin ~= len then return false end
    return pin:match('^%d+$') ~= nil
end

function PhonePin.Hash(pin)
    return GetPasswordHash(tostring(pin or ''))
end

function PhonePin.Verify(pin, hash)
    if not hash or hash == '' then return false end
    return VerifyPasswordHash(tostring(pin or ''), tostring(hash)) == true
end

function PhonePin.LockoutSeconds()
    return tonumber(cfg().lockoutSeconds) or 600
end

function PhonePin.FailsBeforeLockout()
    return tonumber(cfg().failsBeforeLockout) or 3
end

function PhonePin.FailsBeforeLockedStatus()
    return tonumber(cfg().failsBeforeLockedStatus) or 10
end
