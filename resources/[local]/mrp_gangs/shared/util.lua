GangUtils = GangUtils or {}

function GangUtils.Clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

function GangUtils.Round(value)
    return math.floor((tonumber(value) or 0) + 0.5)
end

function GangUtils.Copy(value)
    if type(value) ~= 'table' then return value end
    local copy = {}
    for key, nested in pairs(value) do
        copy[GangUtils.Copy(key)] = GangUtils.Copy(nested)
    end
    return copy
end

function GangUtils.Contains(list, value)
    for _, entry in ipairs(list or {}) do
        if entry == value then return true end
    end
    return false
end

function GangUtils.RandomToken(prefix)
    local entropy = ('%s:%s:%s:%s'):format(
        tostring(prefix or 'token'),
        tostring(os.time()),
        tostring(math.random(100000, 999999)),
        tostring(GetGameTimer and GetGameTimer() or 0)
    )
    return entropy:gsub('[^%w:.-]', '')
end

function GangUtils.CoordsToTable(coords)
    if not coords then return nil end
    return {
        x = tonumber(coords.x) or 0.0,
        y = tonumber(coords.y) or 0.0,
        z = tonumber(coords.z) or 0.0,
        w = tonumber(coords.w) or 0.0,
    }
end

function GangUtils.TableToVector3(coords)
    if not coords then return nil end
    return vector3(tonumber(coords.x) or 0.0, tonumber(coords.y) or 0.0, tonumber(coords.z) or 0.0)
end

function GangUtils.Distance2D(left, right)
    if not left or not right then return math.huge end
    local dx = (tonumber(left.x) or 0.0) - (tonumber(right.x) or 0.0)
    local dy = (tonumber(left.y) or 0.0) - (tonumber(right.y) or 0.0)
    return math.sqrt(dx * dx + dy * dy)
end

function GangUtils.PointInPolygon(x, y, vertices)
    x = tonumber(x) or 0.0
    y = tonumber(y) or 0.0
    if type(vertices) ~= 'table' or #vertices < 3 then return false end
    local inside = false
    local previous = #vertices
    for current = 1, #vertices do
        local a = vertices[current]
        local b = vertices[previous]
        local crosses = ((a.y > y) ~= (b.y > y))
            and (x < ((b.x - a.x) * (y - a.y) / ((b.y - a.y) + 0.0)) + a.x)
        if crosses then inside = not inside end
        previous = current
    end
    return inside
end

function GangUtils.FindTerritoryAt(x, y, territoryType)
    for territoryId, territory in pairs(Config.Territories or {}) do
        if (not territoryType or territory.type == territoryType)
            and GangUtils.PointInPolygon(x, y, territory.vertices) then
            return territoryId, territory
        end
    end
    return nil
end
