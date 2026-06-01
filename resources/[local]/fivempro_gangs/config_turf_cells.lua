--- Turf langeliai tik Los Santos miesto rajonuose (gaujų zonos).
--- Nėra: oro uostų, uostų, pramonės prie jūros, Blaine County, kalvų už miesto.
local TurfCells = {}
local turfIndex = 0

--- Stačiakampiai, kur negalima turf (centroidas viduje = praleidžiama)
local ExcludedZones = {
    { minX = -1950.0, maxX = -380.0,  minY = -3250.0, maxY = -1500.0 }, -- LSIA + aplinkkeliai
    { minX = -750.0,  maxX = 1350.0,  minY = -3450.0, maxY = -2420.0 }, -- Uostas, Terminal, Elysian
    { minX = 520.0,   maxX = 1750.0,  minY = -2720.0, maxY = -2280.0 }, -- Cypress / pramonė prie vandens
    { minX = -420.0,  maxX = 1520.0,  minY = 520.0,   maxY = 1500.0 },  -- Vinewood Hills / kalnai
    { minX = -3200.0, maxX = -1550.0, minY = -250.0,  maxY = 2200.0 },  -- Chumash, Tongva, Banham
    { minX = -2800.0, maxX = 5000.0,  minY = 1650.0,  maxY = 8000.0 },  -- Už LS (dykuma, Sandy, Paleto…)
    { minX = 1550.0,  maxX = 5000.0,  minY = -1200.0, maxY = 8000.0 },  -- Rytai už miesto (Zancudo, dykuma)
}

--- Miesto ribos (turf centroidas turi būti viduje)
local AllowedCity = {
    minX = -1750.0,
    maxX = 1580.0,
    minY = -2050.0,
    maxY = 480.0,
}

local function cellCenterInExcluded(cx, cy)
    for _, z in ipairs(ExcludedZones) do
        if cx >= z.minX and cx <= z.maxX and cy >= z.minY and cy <= z.maxY then
            return true
        end
    end
    return false
end

local function cellAllowed(minX, minY, maxX, maxY)
    local cx = (minX + maxX) * 0.5
    local cy = (minY + maxY) * 0.5
    if cx < AllowedCity.minX or cx > AllowedCity.maxX then return false end
    if cy < AllowedCity.minY or cy > AllowedCity.maxY then return false end
    if cellCenterInExcluded(cx, cy) then return false end
    return true
end

local function addBlock(district, anchorX, anchorY, cols, rows, cellW, cellH, baseZ)
    baseZ = baseZ or 30.0
    for row = 0, rows - 1 do
        for col = 0, cols - 1 do
            local minX = anchorX + col * cellW
            local minY = anchorY + row * cellH
            local maxX = minX + cellW
            local maxY = minY + cellH
            if cellAllowed(minX, minY, maxX, maxY) then
                turfIndex = turfIndex + 1
                local id = ('turf_%03d'):format(turfIndex)
                TurfCells[id] = {
                    label = district,
                    district = district,
                    minX = minX,
                    minY = minY,
                    maxX = maxX,
                    maxY = maxY,
                    center = vector3(minX + cellW * 0.5, minY + cellH * 0.5, baseZ),
                    radius = math.sqrt(cellW * cellW + cellH * cellH) * 0.5,
                    cell_num = turfIndex,
                }
            end
        end
    end
end

-- Pietų LS (gaujų rajonai)
addBlock('Grove Street', 40.0, -2020.0, 3, 4, 78.0, 72.0, 25.0)
addBlock('Davis', -180.0, -1820.0, 5, 5, 82.0, 78.0, 28.0)
addBlock('Strawberry', 180.0, -1580.0, 4, 4, 80.0, 76.0, 30.0)
addBlock('Rancho', 260.0, -2100.0, 4, 4, 82.0, 78.0, 28.0)
addBlock('Chamberlain Hills', -280.0, -1700.0, 3, 4, 80.0, 76.0, 32.0)

-- Centras / Rytai
addBlock('Mission Row', 380.0, -1040.0, 3, 3, 88.0, 84.0, 30.0)
addBlock('Textile City', 360.0, -880.0, 3, 3, 86.0, 82.0, 30.0)
addBlock('Downtown LS', 80.0, -980.0, 4, 3, 95.0, 90.0, 35.0)
addBlock('Mirror Park', 1020.0, -580.0, 3, 4, 88.0, 84.0, 55.0)
addBlock('El Burro Heights', 1480.0, -2180.0, 2, 2, 105.0, 100.0, 45.0)
addBlock('Murrieta Heights', 1280.0, -1580.0, 3, 3, 92.0, 88.0, 38.0)

-- Vakarai / centras
addBlock('Little Seoul', -820.0, -980.0, 3, 3, 90.0, 86.0, 28.0)
addBlock('Del Perro', -1580.0, -640.0, 3, 3, 92.0, 88.0, 32.0)
addBlock('Vinewood', 280.0, 80.0, 3, 3, 100.0, 95.0, 70.0)
addBlock('Rockford Hills', -780.0, -180.0, 2, 3, 95.0, 90.0, 45.0)
addBlock('La Mesa', 720.0, -1280.0, 3, 2, 92.0, 88.0, 30.0)
addBlock('La Mesa East', 980.0, -1180.0, 3, 3, 88.0, 84.0, 32.0)

-- Miesto rajonai (be pakrantės uosto)
addBlock('Vespucci', -1280.0, -1380.0, 4, 4, 72.0, 68.0, 8.0)
addBlock('Vespucci Canals', -1180.0, -1180.0, 3, 3, 70.0, 66.0, 6.0)
addBlock('Pillbox Hill', -280.0, -680.0, 3, 3, 78.0, 74.0, 38.0)
addBlock('Alta', 280.0, -520.0, 3, 3, 76.0, 72.0, 42.0)
addBlock('Burton', -520.0, -380.0, 3, 3, 74.0, 70.0, 38.0)
addBlock('Hawick', 180.0, -280.0, 3, 3, 72.0, 68.0, 45.0)
addBlock('Richman', -1680.0, 120.0, 3, 3, 88.0, 84.0, 55.0)
addBlock('West Vinewood', 120.0, 220.0, 4, 3, 82.0, 78.0, 62.0)
addBlock('East Vinewood', 680.0, 280.0, 3, 3, 86.0, 82.0, 68.0)
addBlock('Maze Bank', 120.0, -820.0, 2, 2, 80.0, 76.0, 32.0)
addBlock('Legion Square', 180.0, -920.0, 2, 2, 78.0, 74.0, 30.0)
addBlock('Pillbox South', -180.0, -920.0, 3, 2, 76.0, 72.0, 32.0)

Config.TurfCells = TurfCells
Config.Turfs = TurfCells
Config.TurfExcludedZones = ExcludedZones
Config.TurfAllowedCity = AllowedCity

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
