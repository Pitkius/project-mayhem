--- Diamond Casino — GTA Online vanilla MLO (IPL) įkėlimas.
--- Be šių IPL išorė lieka tuščia, interjeras neatsiranda.

Casino = Casino or {}

local CASINO_BUILD = 2060

local CASINO_IPLS_REMOVE = {
    'hei_dlc_casino_door_broken',
    'hei_dlc_casino_door_broken2',
    'hei_dlc_vw_roofdoors_locked',
}

--- Pilnas Diamond Casino & Resort IPL sąrašas (GTA Online mpvinewood).
local CASINO_IPLS = {
    -- Išorė / stiklinės durys
    'hei_dlc_windows_casino',
    'hei_dlc_casino_aircon',
    'hei_dlc_casino_door',
    'vw_dlc_casino_door',
    'vw_dlc_casino_door_lod',
    'vw_casino_billboard',
    'vw_casino_billboard_lod',
    -- Vinewood papildymai aplink kazino pastatą
    'vw_ch3_additions',
    'vw_ch3_additions_long_0',
    'vw_ch3_additions_strm_0',
    'vw_int_placement_vw',
    -- Interjerai
    'vw_casino_main',
    'vw_casino_garage',
    'vw_casino_carpark',
    'vw_casino_penthouse',
    'vw_dlc_casino_apart',
}

local CASINO_MAIN_PROBE = vector3(1100.0, 220.0, -50.0)
local CASINO_MAIN_TYPE = 'vw_casino_main'
local CASINO_EXTERIOR_PROBE = vector3(924.78, 46.85, 81.11)

local PENTHOUSE_INTERIOR_ID = 274689
local PENTHOUSE_PROBE = vector3(976.636, 70.295, 115.164)

local iplReady = false
local mpDlcLoaded = false

local function enableIpl(name, activate)
    if activate then
        if not IsIplActive(name) then
            RequestIpl(name)
        end
    elseif IsIplActive(name) then
        RemoveIpl(name)
    end
end

local function ensureMpDlcMaps()
    if mpDlcLoaded then return end
    if GetGameBuildNumber() < CASINO_BUILD then return end
    pcall(function()
        LoadMpDlcMaps()
        EnableMpDlcMaps(true)
    end)
    mpDlcLoaded = true
end

local function activateInteriorEntitySet(interiorId, propName)
    if not interiorId or interiorId == 0 then return end
    if not IsInteriorEntitySetActive(interiorId, propName) then
        ActivateInteriorEntitySet(interiorId, propName)
    end
end

local function setupPenthouseDefaults()
    local interiorId = GetInteriorAtCoords(PENTHOUSE_PROBE.x, PENTHOUSE_PROBE.y, PENTHOUSE_PROBE.z)
    if interiorId == 0 then
        interiorId = PENTHOUSE_INTERIOR_ID
    end
    if not interiorId or interiorId == 0 or not IsValidInterior(interiorId) then return end

    PinInteriorInMemory(interiorId)
    activateInteriorEntitySet(interiorId, 'Set_Pent_Tint_Shell')
    SetInteriorEntitySetColor(interiorId, 'Set_Pent_Tint_Shell', 1)
    activateInteriorEntitySet(interiorId, 'Set_Pent_Pattern_01')
    SetInteriorEntitySetColor(interiorId, 'Set_Pent_Pattern_01', 1)
    activateInteriorEntitySet(interiorId, 'Set_Pent_Spa_Bar_Open')
    activateInteriorEntitySet(interiorId, 'Set_Pent_Media_Bar_Open')
    activateInteriorEntitySet(interiorId, 'Set_Pent_Dealer')
    RefreshInterior(interiorId)
end

local function waitForIpls(timeoutMs)
    timeoutMs = timeoutMs or 12000
    local deadline = GetGameTimer() + timeoutMs
    while GetGameTimer() < deadline do
        local allActive = true
        for _, ipl in ipairs(CASINO_IPLS) do
            if not IsIplActive(ipl) then
                allActive = false
                RequestIpl(ipl)
                break
            end
        end
        if allActive then return true end
        Wait(50)
    end
    return false
end

function Casino.waitInteriorAt(coords, interiorType, attempts)
    attempts = attempts or 200
    for _ = 1, attempts do
        RequestCollisionAtCoord(coords.x, coords.y, coords.z)
        local id = GetInteriorAtCoords(coords.x, coords.y, coords.z)
        if (not id or id == 0) and interiorType then
            id = GetInteriorAtCoordsWithType(coords.x, coords.y, coords.z, interiorType)
        end
        if id and id ~= 0 and IsValidInterior(id) then
            PinInteriorInMemory(id)
            LoadInterior(id)
            if IsInteriorReady(id) then
                RefreshInterior(id)
                return id
            end
        end
        Wait(50)
    end
    if interiorType then
        return GetInteriorAtCoordsWithType(coords.x, coords.y, coords.z, interiorType)
    end
    return GetInteriorAtCoords(coords.x, coords.y, coords.z)
end

function Casino.prepareInteriorAt(x, y, z)
    Casino.loadIpl(true)
    local coords = vector3(x, y, z)
    local interiorType
    if #(coords - CASINO_MAIN_PROBE) < 120.0 or z < 0.0 then
        interiorType = CASINO_MAIN_TYPE
    end
    return Casino.waitInteriorAt(coords, interiorType, 240)
end

function Casino.loadIpl(forceRefresh)
    if not Config.Casino or Config.Casino.loadVanillaIpl ~= true then return end
    if GetGameBuildNumber() < CASINO_BUILD then
        print(('[mrp_casino] Reikia game build >= %d (dabartinis: %d)'):format(CASINO_BUILD, GetGameBuildNumber()))
        return
    end

    ensureMpDlcMaps()

    for _, ipl in ipairs(CASINO_IPLS_REMOVE) do
        enableIpl(ipl, false)
    end
    for _, ipl in ipairs(CASINO_IPLS) do
        enableIpl(ipl, true)
    end

    if forceRefresh or not iplReady then
        waitForIpls(15000)
        setupPenthouseDefaults()
        Casino.waitInteriorAt(CASINO_MAIN_PROBE, CASINO_MAIN_TYPE, 120)
        iplReady = true
    end
end

-- Pradinis įkėlimas
CreateThread(function()
    Wait(500)
    Casino.loadIpl(true)
end)

-- Išorė: IPL kol žaidėjas arti kazino
CreateThread(function()
    while true do
        local sleep = 3000
        local p = GetEntityCoords(PlayerPedId())
        if #(p - CASINO_EXTERIOR_PROBE) < 250.0 then
            Casino.loadIpl(false)
            RequestCollisionAtCoord(CASINO_EXTERIOR_PROBE.x, CASINO_EXTERIOR_PROBE.y, CASINO_EXTERIOR_PROBE.z)
            sleep = 10000
        end
        Wait(sleep)
    end
end)

-- Interjeras: palaikyti kol žaidėjas kazino zonoje
CreateThread(function()
    while true do
        local sleep = 4000
        local casino = Config.Casino or {}
        local center = casino.center
        if center then
            local p = GetEntityCoords(PlayerPedId())
            if #(p - center) < (casino.radius or 90.0) + 30.0 then
                Casino.loadIpl(false)
                Casino.waitInteriorAt(CASINO_MAIN_PROBE, CASINO_MAIN_TYPE, 40)
                sleep = 15000
            end
        end
        Wait(sleep)
    end
end)
