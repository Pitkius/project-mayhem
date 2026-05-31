--- Maži turf langeliai per visą GTA 5 žemėlapį (~120). Kiekvienas = kelios gatvės.
local TurfCells = {}
local turfIndex = 0

local function addBlock(district, anchorX, anchorY, cols, rows, cellW, cellH, baseZ)
    baseZ = baseZ or 30.0
    for row = 0, rows - 1 do
        for col = 0, cols - 1 do
            turfIndex = turfIndex + 1
            local id = ('turf_%03d'):format(turfIndex)
            local minX = anchorX + col * cellW
            local minY = anchorY + row * cellH
            local maxX = minX + cellW
            local maxY = minY + cellH
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
addBlock('Cypress Flats', 880.0, -2580.0, 3, 3, 100.0, 95.0, 28.0)
addBlock('El Burro Heights', 1480.0, -2180.0, 3, 3, 105.0, 100.0, 45.0)
addBlock('Mirror Park', 1020.0, -580.0, 3, 4, 88.0, 84.0, 55.0)

-- Vakarai
addBlock('Little Seoul', -820.0, -980.0, 3, 3, 90.0, 86.0, 28.0)
addBlock('Del Perro', -1580.0, -640.0, 3, 3, 92.0, 88.0, 32.0)
addBlock('La Puerta', -1180.0, -1320.0, 3, 2, 95.0, 90.0, 12.0)
addBlock('Vinewood', 280.0, 80.0, 3, 3, 100.0, 95.0, 70.0)
addBlock('Rockford Hills', -780.0, -180.0, 2, 3, 95.0, 90.0, 45.0)

-- Uostas / pramonė
addBlock('Terminal', 760.0, -2980.0, 3, 2, 110.0, 100.0, 8.0)
addBlock('Docks', 180.0, -2780.0, 4, 2, 105.0, 98.0, 6.0)
addBlock('La Mesa', 720.0, -1280.0, 3, 2, 92.0, 88.0, 30.0)

-- Blaine County
addBlock('Sandy Shores', 1580.0, 3580.0, 3, 3, 120.0, 115.0, 35.0)
addBlock('Harmony', 520.0, 2580.0, 2, 2, 115.0, 110.0, 42.0)
addBlock('Grapeseed', 2280.0, 4780.0, 2, 3, 125.0, 120.0, 48.0)
addBlock('Paleto Bay', -280.0, 6180.0, 3, 3, 130.0, 125.0, 32.0)
addBlock('Chumash', -3280.0, 980.0, 2, 2, 120.0, 115.0, 12.0)

Config.TurfCells = TurfCells
--- Senasis Config.Turfs API — naudoja tuos pačius mažus langelius
Config.Turfs = TurfCells

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
