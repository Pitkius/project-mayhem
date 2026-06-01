--- Turf tinklelis: tolygūs kvadratai per Los Santos (be uostų, oro uosto, kalvų).
local TurfCells = {}
local turfIndex = 0

local CELL_W = 98.0
local CELL_H = 98.0
local GRID_MIN_X = -1680.0
local GRID_MIN_Y = -1980.0
local GRID_MAX_X = 1560.0
local GRID_MAX_Y = 460.0

local ExcludedZones = {
    { minX = -1950.0, maxX = -380.0,  minY = -3250.0, maxY = -1500.0 },
    { minX = -750.0,  maxX = 1350.0,  minY = -3450.0, maxY = -2420.0 },
    { minX = 520.0,   maxX = 1750.0,  minY = -2720.0, maxY = -2280.0 },
    { minX = -420.0,  maxX = 1520.0,  minY = 520.0,   maxY = 1500.0 },
    { minX = -3200.0, maxX = -1550.0, minY = -250.0,  maxY = 2200.0 },
    { minX = -2800.0, maxX = 5000.0,  minY = 1650.0,  maxY = 8000.0 },
    { minX = 1550.0,  maxX = 5000.0,  minY = -1200.0, maxY = 8000.0 },
}

Config.TurfExcludedZones = ExcludedZones
Config.TurfAllowedCity = {
    minX = GRID_MIN_X,
    maxX = GRID_MAX_X,
    minY = GRID_MIN_Y,
    maxY = GRID_MAX_Y,
}

local DistrictCenters = {
    { name = 'Grove Street', x = 95.0, y = -1930.0 },
    { name = 'Davis', x = -150.0, y = -1750.0 },
    { name = 'Strawberry', x = 250.0, y = -1500.0 },
    { name = 'Rancho', x = 450.0, y = -2050.0 },
    { name = 'Chamberlain Hills', x = -200.0, y = -1650.0 },
    { name = 'Mission Row', x = 450.0, y = -1000.0 },
    { name = 'Textile City', x = 500.0, y = -850.0 },
    { name = 'Downtown LS', x = 200.0, y = -950.0 },
    { name = 'Mirror Park', x = 1100.0, y = -550.0 },
    { name = 'Murrieta Heights', x = 1350.0, y = -1550.0 },
    { name = 'Little Seoul', x = -750.0, y = -950.0 },
    { name = 'Del Perro', x = -1450.0, y = -700.0 },
    { name = 'Vinewood', x = 350.0, y = 150.0 },
    { name = 'Rockford Hills', x = -650.0, y = -100.0 },
    { name = 'La Mesa', x = 850.0, y = -1250.0 },
    { name = 'Vespucci', x = -1150.0, y = -1250.0 },
    { name = 'Vespucci Canals', x = -1050.0, y = -1100.0 },
    { name = 'Pillbox Hill', x = -200.0, y = -650.0 },
    { name = 'Alta', x = 350.0, y = -500.0 },
    { name = 'Burton', x = -450.0, y = -350.0 },
    { name = 'Hawick', x = 250.0, y = -300.0 },
    { name = 'Richman', x = -1500.0, y = 200.0 },
    { name = 'West Vinewood', x = 200.0, y = 300.0 },
    { name = 'East Vinewood', x = 750.0, y = 350.0 },
    { name = 'Legion Square', x = 200.0, y = -900.0 },
    { name = 'Maze Bank', x = 150.0, y = -800.0 },
    { name = 'Pillbox South', x = -180.0, y = -920.0 },
}

local function cellCenterInExcluded(cx, cy)
    for _, z in ipairs(ExcludedZones) do
        if cx >= z.minX and cx <= z.maxX and cy >= z.minY and cy <= z.maxY then
            return true
        end
    end
    return false
end

local function districtFor(cx, cy)
    local bestName = 'Los Santos'
    local bestDist = math.huge
    for _, d in ipairs(DistrictCenters) do
        local dx = cx - d.x
        local dy = cy - d.y
        local dist = dx * dx + dy * dy
        if dist < bestDist then
            bestDist = dist
            bestName = d.name
        end
    end
    return bestName
end

for minX = GRID_MIN_X, GRID_MAX_X - CELL_W, CELL_W do
    for minY = GRID_MIN_Y, GRID_MAX_Y - CELL_H, CELL_H do
        local maxX = minX + CELL_W
        local maxY = minY + CELL_H
        local cx = minX + CELL_W * 0.5
        local cy = minY + CELL_H * 0.5
        if not cellCenterInExcluded(cx, cy) then
            turfIndex = turfIndex + 1
            local id = ('turf_%03d'):format(turfIndex)
            local district = districtFor(cx, cy)
            TurfCells[id] = {
                label = district,
                district = district,
                minX = minX,
                minY = minY,
                maxX = maxX,
                maxY = maxY,
                center = vector3(cx, cy, 30.0),
                radius = math.sqrt(CELL_W * CELL_W + CELL_H * CELL_H) * 0.5,
                cell_num = turfIndex,
                grid_col = math.floor((minX - GRID_MIN_X) / CELL_W) + 1,
                grid_row = math.floor((minY - GRID_MIN_Y) / CELL_H) + 1,
            }
        end
    end
end

Config.TurfCells = TurfCells
Config.Turfs = TurfCells
Config.TurfGrid = {
    cellW = CELL_W,
    cellH = CELL_H,
    minX = GRID_MIN_X,
    minY = GRID_MIN_Y,
    maxX = GRID_MAX_X,
    maxY = GRID_MAX_Y,
}

--- Fiksuotos gaujų spalvos legendai (jei DB spalva nepriskirta)
Config.FactionColors = {
    { id = 'neutral', label = 'Neutralu', color = '#64748B', patterns = {} },
    { id = 'grove', label = 'Grove / Families', color = '#22C55E', patterns = { 'grove', 'families', 'gsf' } },
    { id = 'ballas', label = 'Ballas', color = '#A855F7', patterns = { 'ballas', 'purple' } },
    { id = 'vagos', label = 'Vagos', color = '#EAB308', patterns = { 'vagos', 'vago' } },
    { id = 'marabunta', label = 'Marabunta', color = '#3B82F6', patterns = { 'mara', 'marabunta', 'azteca' } },
    { id = 'bloods', label = 'Bloods', color = '#EF4444', patterns = { 'blood', 'red' } },
    { id = 'cartel', label = 'Cartel', color = '#171717', patterns = { 'cartel', 'sinaloa', 'mafia' } },
}

function Config.GetTurfCell(turfId)
    if not turfId then return nil end
    return TurfCells[tostring(turfId)]
end

function Config.FindTurfAt(x, y)
    x = tonumber(x) or 0.0
    y = tonumber(y) or 0.0
    local bestId, bestCell, bestArea = nil, nil, math.huge
    for id, cell in pairs(TurfCells) do
        if x >= cell.minX and x <= cell.maxX and y >= cell.minY and y <= cell.maxY then
            local area = (cell.maxX - cell.minX) * (cell.maxY - cell.minY)
            if area < bestArea then
                bestArea = area
                bestId = id
                bestCell = cell
            end
        end
    end
    return bestId, bestCell
end

function Config.PlayerInTurfCell(src, turfId)
    local cell = Config.GetTurfCell(turfId)
    if not cell then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    return p.x >= cell.minX - 2.0 and p.x <= cell.maxX + 2.0
        and p.y >= cell.minY - 2.0 and p.y <= cell.maxY + 2.0
end

function Config.FactionColorForOwner(ownerName, ownerHex)
    local name = string.lower(tostring(ownerName or ''))
    if name == '' or name == 'neutralu' or name == 'laisva' or name == 'neutral' then
        return '#64748B'
    end
    for i = 2, #Config.FactionColors do
        local f = Config.FactionColors[i]
        for _, pat in ipairs(f.patterns or {}) do
            if name:find(pat, 1, true) then return f.color end
        end
    end
    if ownerHex and ownerHex ~= '' and ownerHex ~= '#FFFFFF' then return ownerHex end
    return '#64748B'
end
