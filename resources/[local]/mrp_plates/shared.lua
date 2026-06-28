MRPPlates = MRPPlates or {}

local function clean(plate)
    return tostring(plate or ''):upper():gsub('%s+', ' '):match('^%s*(.-)%s*$') or ''
end

--- Saugojimui DB / UI: visada „123 ABC“ (3 skaitmenys, tarpas, 3 raidės).
function MRPPlates.Normalize(plate)
    local raw = clean(plate)
    local digits, letters = raw:match('^(%d%d%d)%s*(%u%u%u)$')
    if digits and letters then
        return ('%s %s'):format(digits, letters)
    end
    local compact = raw:gsub('%s+', '')
    digits, letters = compact:match('^(%d+)(%u+)$')
    if digits and letters and #digits >= 3 and #letters >= 3 then
        return ('%s %s'):format(digits:sub(1, 3), letters:sub(1, 3))
    end
    return raw:sub(1, 8)
end

--- GTA rodo max 8 simbolius — vienas tarpas kairėje pastumia tekstą nuo violetinės juostos.
function MRPPlates.FormatForRender(plate, padLeft)
    local norm = MRPPlates.Normalize(plate)
    local digits, letters = norm:match('^(%d%d%d) (%u%u%u)$')
    if not digits then
        return norm:sub(1, 8)
    end
    padLeft = math.max(0, math.min(tonumber(padLeft) or 1, 1))
    local out = ('%s%s %s'):format(string.rep(' ', padLeft), digits, letters)
    return out:sub(1, 8)
end

function MRPPlates.IsValid(plate)
    local norm = MRPPlates.Normalize(plate)
    return norm:match('^%d%d%d %u%u%u$') ~= nil
end
