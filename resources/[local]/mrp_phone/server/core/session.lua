PhoneSession = PhoneSession or {}

--- [src] = { phoneId, phoneType, unlockedAt, expiresAt }
local sessions = {}

local function ttlSec()
    return tonumber(Config.Phone and Config.Phone.SessionTtlSec) or 900
end

function PhoneSession.Set(src, phoneId, phoneType)
    src = tonumber(src)
    if not src or not phoneId then return end
    local now = os.time()
    sessions[src] = {
        phoneId = phoneId,
        phoneType = PhoneTypes.Normalize(phoneType),
        unlockedAt = now,
        expiresAt = now + ttlSec(),
    }
end

function PhoneSession.Clear(src)
    sessions[tonumber(src) or src] = nil
end

function PhoneSession.Get(src)
    src = tonumber(src)
    local s = src and sessions[src]
    if not s then return nil end
    if os.time() > (s.expiresAt or 0) then
        sessions[src] = nil
        return nil
    end
    return s
end

function PhoneSession.Require(src)
    local s = PhoneSession.Get(src)
    if not s then return nil, 'Telefonas neužrakintas / sesija baigėsi.' end
    return s
end

function PhoneSession.Touch(src)
    local s = PhoneSession.Get(src)
    if not s then return end
    s.expiresAt = os.time() + ttlSec()
end

AddEventHandler('playerDropped', function()
    PhoneSession.Clear(source)
end)
