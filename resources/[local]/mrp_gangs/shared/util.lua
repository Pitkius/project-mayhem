GangUtils = GangUtils or {}

--- SetEntityOrphanMode is only on newer FXServer builds; skip if missing.
function GangUtils.SetEntityOrphanMode(entity, mode)
    if type(SetEntityOrphanMode) ~= 'function' then return false end
    if not entity or entity == 0 then return false end
    SetEntityOrphanMode(entity, mode)
    return true
end

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

--- Shoelace polygon centroid (falls back to vertex average).
function GangUtils.PolygonCentroid(vertices)
    if type(vertices) ~= 'table' or #vertices == 0 then return nil end
    if #vertices < 3 then
        return { x = tonumber(vertices[1].x) or 0.0, y = tonumber(vertices[1].y) or 0.0 }
    end
    local area2, cx, cy = 0.0, 0.0, 0.0
    local n = #vertices
    for i = 1, n do
        local a = vertices[i]
        local b = vertices[(i % n) + 1]
        local cross = (tonumber(a.x) or 0.0) * (tonumber(b.y) or 0.0)
            - (tonumber(b.x) or 0.0) * (tonumber(a.y) or 0.0)
        area2 = area2 + cross
        cx = cx + ((tonumber(a.x) or 0.0) + (tonumber(b.x) or 0.0)) * cross
        cy = cy + ((tonumber(a.y) or 0.0) + (tonumber(b.y) or 0.0)) * cross
    end
    if math.abs(area2) < 0.0001 then
        local sx, sy = 0.0, 0.0
        for i = 1, n do
            sx = sx + (tonumber(vertices[i].x) or 0.0)
            sy = sy + (tonumber(vertices[i].y) or 0.0)
        end
        return { x = sx / n, y = sy / n }
    end
    return { x = cx / (3.0 * area2), y = cy / (3.0 * area2) }
end

function GangUtils.FindTerritoryAt(x, y, territoryType)
    -- Prefer smaller polygons first when overlaps exist (street borders).
    local ordered = {}
    for territoryId, territory in pairs(Config.Territories or {}) do
        if not territoryType or territory.type == territoryType then
            ordered[#ordered + 1] = { id = territoryId, territory = territory }
        end
    end
    table.sort(ordered, function(a, b)
        local va, vb = a.territory.vertices or {}, b.territory.vertices or {}
        return #va < #vb
    end)
    for i = 1, #ordered do
        local entry = ordered[i]
        if GangUtils.PointInPolygon(x, y, entry.territory.vertices) then
            return entry.id, entry.territory
        end
    end
    return nil
end
