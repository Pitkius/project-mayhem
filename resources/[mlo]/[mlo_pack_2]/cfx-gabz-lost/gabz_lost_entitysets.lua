local CLUBHOUSE_COORDS = vector3(994.4787, -122.9949, 73.11467)
local GARAGE_COORDS = vector3(972.16, -118.05, 74.35)
local ENTRANCE_COORDS = vector3(981.3867, -102.3285, 74.3489)

local VANILLA_BIKER_IPL = 'bkr_biker_interior_placement_interior_1_biker_dlc_int_02_milo'

local function requestCollision(coords)
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
end

local function waitInteriorAt(coords, attempts)
    attempts = attempts or 250
    for _ = 1, attempts do
        requestCollision(coords)
        local id = GetInteriorAtCoords(coords.x, coords.y, coords.z)
        if id ~= 0 and IsValidInterior(id) and IsInteriorReady(id) then
            return id
        end
        if id ~= 0 then
            LoadInterior(id)
        end
        Wait(50)
    end
    return GetInteriorAtCoords(coords.x, coords.y, coords.z)
end

local function enableProp(interiorId, prop, color)
    EnableInteriorProp(interiorId, prop)
    if color then
        SetInteriorPropColor(interiorId, prop, color)
    end
end

local function setupClubhouse(interiorId)
    PinInteriorInMemory(interiorId)
    LoadInterior(interiorId)

    enableProp(interiorId, 'walls_02', 8)
    enableProp(interiorId, 'Furnishings_02', 8)
    enableProp(interiorId, 'decorative_02')
    enableProp(interiorId, 'mural_03')
    enableProp(interiorId, 'lower_walls_default', 8)
    enableProp(interiorId, 'mod_booth')
    enableProp(interiorId, 'gun_locker')
    enableProp(interiorId, 'cash_small')
    enableProp(interiorId, 'id_small')
    enableProp(interiorId, 'weed_small')

    RefreshInterior(interiorId)
end

local function setupGarage(interiorId)
    if interiorId == 0 then return end
    PinInteriorInMemory(interiorId)
    LoadInterior(interiorId)
    RefreshInterior(interiorId)
end

local function loadLostMc()
    RemoveIpl(VANILLA_BIKER_IPL)

    RequestIpl('gabz_biker_milo_')
    RequestIpl('lost_garage_milo_')

    Wait(500)

    requestCollision(ENTRANCE_COORDS)
    requestCollision(CLUBHOUSE_COORDS)

    local clubhouseId = waitInteriorAt(CLUBHOUSE_COORDS)
    if clubhouseId == 0 then
        clubhouseId = waitInteriorAt(ENTRANCE_COORDS, 120)
    end
    if clubhouseId == 0 then
        print('^1[cfx-gabz-lost]^7 Clubhouse interjeras neužsikrovė — patikrink mapdata ir ytyp.')
        return
    end

    setupClubhouse(clubhouseId)
    PinInteriorInMemory(clubhouseId)

    local garageId = waitInteriorAt(GARAGE_COORDS, 120)
    if garageId ~= 0 and garageId ~= clubhouseId then
        setupGarage(garageId)
    end
end

CreateThread(function()
    Wait(2500)
    loadLostMc()
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    CreateThread(function()
        Wait(2000)
        loadLostMc()
    end)
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    CreateThread(function()
        Wait(4000)
        loadLostMc()
    end)
end)

exports('ReloadLostMc', loadLostMc)
