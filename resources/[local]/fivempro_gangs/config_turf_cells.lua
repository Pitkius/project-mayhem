--- Turf zonos: ~40 RP rajonų (Los Santos + Sandy Shores + Harmony + Paleto Bay).
--- Ne generinis tinklelis — tik vietos kur vyksta gaujų RP.
local TurfCells = {}

local function addTurf(num, id, label, district, minX, minY, maxX, maxY)
    local cx = (minX + maxX) * 0.5
    local cy = (minY + maxY) * 0.5
    local w = maxX - minX
    local h = maxY - minY
    TurfCells[id] = {
        label = label,
        district = district,
        minX = minX,
        minY = minY,
        maxX = maxX,
        maxY = maxY,
        center = vector3(cx, cy, 30.0),
        radius = math.sqrt(w * w + h * h) * 0.5,
        cell_num = num,
    }
end

-- Los Santos — pietūs
addTurf(1,  'turf_001', 'Grove Street',        'Grove Street',        -80.0,   -2120.0,  320.0,  -1780.0)
addTurf(2,  'turf_002', 'Davis',               'Davis',              -420.0,   -1880.0,   80.0,  -1580.0)
addTurf(3,  'turf_003', 'Chamberlain Hills',   'Chamberlain Hills',  -380.0,   -1680.0,  -40.0,  -1380.0)
addTurf(4,  'turf_004', 'Rancho',              'Rancho',              280.0,   -2180.0,  720.0,  -1780.0)
addTurf(5,  'turf_005', 'Strawberry',          'Strawberry',           40.0,   -1720.0,  420.0,  -1420.0)
addTurf(6,  'turf_006', 'Forum Drive',         'Forum Drive',        -420.0,   -1580.0,  -40.0,  -1280.0)
addTurf(7,  'turf_007', 'South LS',            'South LS',            720.0,   -2280.0, 1180.0,  -1880.0)

-- Los Santos — rytai / pramonė
addTurf(8,  'turf_008', 'La Mesa',             'La Mesa',             680.0,   -1480.0, 1120.0,  -1080.0)
addTurf(9,  'turf_009', 'El Burro Heights',    'El Burro Heights',   1180.0,   -1880.0, 1580.0,  -1480.0)
addTurf(10, 'turf_010', 'Cypress Flats',       'Cypress Flats',       820.0,   -2280.0, 1220.0,  -1880.0)
addTurf(11, 'turf_011', 'Murrieta Heights',    'Murrieta Heights',   1080.0,   -1580.0, 1480.0,  -1180.0)

-- Los Santos — vakarai
addTurf(12, 'turf_012', 'Little Seoul',        'Little Seoul',       -980.0,   -1080.0, -520.0,   -680.0)
addTurf(13, 'turf_013', 'Vespucci',            'Vespucci',          -1380.0,   -1380.0, -920.0,   -980.0)
addTurf(14, 'turf_014', 'Del Perro',           'Del Perro',         -1680.0,    -880.0,-1220.0,   -480.0)

-- Los Santos — centras / downtown
addTurf(15, 'turf_015', 'Pillbox / Mission Row','Mission Row',        -120.0,   -1180.0,  480.0,   -780.0)
addTurf(16, 'turf_016', 'Legion Square',       'Legion Square',       -80.0,   -1020.0,  380.0,   -620.0)
addTurf(17, 'turf_017', 'Textile City',        'Textile City',        380.0,    -980.0,  780.0,   -580.0)
addTurf(18, 'turf_018', 'Downtown LS',         'Downtown LS',        -280.0,    -780.0,  280.0,   -380.0)

-- Los Santos — šiaurė / Vinewood
addTurf(19, 'turf_019', 'Mirror Park',         'Mirror Park',         880.0,    -720.0, 1280.0,   -320.0)
addTurf(20, 'turf_020', 'East Vinewood',       'East Vinewood',       680.0,     -80.0, 1080.0,    320.0)
addTurf(21, 'turf_021', 'Vinewood',            'Vinewood',            180.0,      80.0,  580.0,    480.0)
addTurf(22, 'turf_022', 'Alta',                'Alta',                180.0,    -580.0,  580.0,   -180.0)
addTurf(23, 'turf_023', 'Hawick',              'Hawick',              280.0,    -380.0,  680.0,     80.0)
addTurf(24, 'turf_024', 'Burton',              'Burton',             -580.0,    -480.0, -180.0,    -80.0)
addTurf(25, 'turf_025', 'Rockford Hills',      'Rockford Hills',     -980.0,    -280.0, -480.0,    180.0)
addTurf(26, 'turf_026', 'Richman',             'Richman',           -1680.0,     180.0,-1180.0,    580.0)

-- Papildomos LS zonos
addTurf(27, 'turf_027', 'La Puerta Docks',     'La Puerta',          -680.0,   -1680.0, -280.0,  -1280.0)
addTurf(28, 'turf_028', 'Maze Bank Area',      'Pillbox Hill',        -380.0,    -880.0,   80.0,   -480.0)
addTurf(29, 'turf_029', 'Vinewood Hills',      'Vinewood Hills',     -280.0,     380.0,  280.0,    880.0)
addTurf(30, 'turf_030', 'East LS Industrial',  'La Mesa',            1120.0,   -1280.0, 1520.0,   -880.0)

-- Blaine County
addTurf(31, 'turf_031', 'Sandy Shores',        'Sandy Shores',       1680.0,   3380.0, 2180.0,   3880.0)
addTurf(32, 'turf_032', 'Sandy Shores North',  'Sandy Shores',       1480.0,   3880.0, 1980.0,   4380.0)
addTurf(33, 'turf_033', 'Harmony',             'Harmony',             380.0,   2480.0,  880.0,   2980.0)
addTurf(34, 'turf_034', 'Grapeseed',           'Grapeseed',          2280.0,   4480.0, 2780.0,   4980.0)
addTurf(35, 'turf_035', 'Paleto Bay',          'Paleto Bay',         -480.0,   6080.0,   80.0,   6580.0)
addTurf(36, 'turf_036', 'Paleto Forest',       'Paleto Bay',         -280.0,   5580.0,  220.0,   6080.0)

-- Papildomos LS detalės (užpildo ~40)
addTurf(37, 'turf_037', 'Davis South',         'Davis',              -280.0,   -2080.0,  120.0,  -1780.0)
addTurf(38, 'turf_038', 'Rancho Docks',        'Rancho',              280.0,   -2480.0,  680.0,  -2080.0)
addTurf(39, 'turf_039', 'Cypress Warehouses',  'Cypress Flats',       480.0,   -2480.0,  880.0,  -2080.0)
addTurf(40, 'turf_040', 'Del Perro Beach',     'Del Perro',         -1480.0,   -1280.0,-1080.0,   -880.0)

Config.TurfCells = TurfCells
Config.Turfs = TurfCells
Config.TurfGrid = nil

Config.TurfExcludedZones = {}
Config.TurfAllowedCity = {
    minX = -4000.0,
    maxX = 4500.0,
    minY = -4000.0,
    maxY = 6625.0,
}

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
