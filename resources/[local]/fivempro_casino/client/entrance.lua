local QBCore = exports['qb-core']:GetCoreObject()

local CASINO_IPLS = {
    'vw_casino_main',
    'vw_casino_garage',
    'vw_casino_carpark',
    'vw_casino_penthouse',
    'hei_dlc_windows_casino',
    'hei_dlc_casino_door',
    'hei_dlc_casino_aircon',
}

local CASINO_IPLS_REMOVE = {
    'hei_dlc_casino_door_broken',
    'hei_dlc_casino_door_broken2',
    'hei_dlc_vw_roofdoors_locked',
}

local teleporting = false

local function notify(msg, ntype)
    QBCore.Functions.Notify(msg, ntype or 'primary')
end

function Casino.loadIpl()
    if not Config.Casino or Config.Casino.loadVanillaIpl ~= true then return end
    for _, ipl in ipairs(CASINO_IPLS_REMOVE) do
        RemoveIpl(ipl)
    end
    for _, ipl in ipairs(CASINO_IPLS) do
        RequestIpl(ipl)
    end
end

local function prepareInteriorAt(x, y, z)
    for _ = 1, 24 do
        RequestCollisionAtCoord(x, y, z)
        Wait(0)
    end
    local interiorId = GetInteriorAtCoords(x, y, z)
    if interiorId and interiorId ~= 0 then
        PinInteriorInMemory(interiorId)
        LoadInterior(interiorId)
        RefreshInterior(interiorId)
    end
end

local function fadeTeleport(coords, heading)
    if teleporting then return end
    teleporting = true

    Casino.loadIpl()

    DoScreenFadeOut(400)
    while not IsScreenFadedOut() do Wait(0) end

    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
    if heading then
        SetEntityHeading(ped, heading)
    end

    prepareInteriorAt(coords.x, coords.y, coords.z)

    Wait(350)
    DoScreenFadeIn(400)
    teleporting = false
end

local function enterCasino()
    if Casino.isBanned and Casino.isBanned() then
        notify('Jūs laikinai negalite įeiti į kazino.', 'error')
        return
    end
    local spawn = (Config.Casino and Config.Casino.interiorSpawn)
        or vector4(1089.1294, 207.2294, -48.9997, 320.0139)
    fadeTeleport(vector3(spawn.x, spawn.y, spawn.z), spawn.w)
    notify('Sveiki atvykę į Diamond Casino.', 'success')
end

local function exitCasino(exitCfg)
    local dest = exitCfg and exitCfg.exterior
    if not dest then
        dest = (Config.Casino and Config.Casino.blip and Config.Casino.blip.coords)
            and vector4(Config.Casino.blip.coords.x, Config.Casino.blip.coords.y, Config.Casino.blip.coords.z, 328.0)
            or vector4(924.78, 46.85, 81.11, 328.0)
    end
    fadeTeleport(vector3(dest.x, dest.y, dest.z), dest.w)
end

local function addEntranceTarget(cfg)
    local c = cfg.coords
    if not c then return end
    exports['qb-target']:AddBoxZone('casino_enter_' .. cfg.id, c, cfg.length or 2.2, cfg.width or 2.2, {
        name = 'casino_enter_' .. cfg.id,
        heading = cfg.heading or 0.0,
        minZ = c.z - 1.2,
        maxZ = c.z + 1.4,
        debugPoly = false,
    }, {
        options = {
            {
                icon = 'fas fa-door-open',
                label = cfg.label or 'Įeiti į kazino',
                action = enterCasino,
            },
        },
        distance = 2.5,
    })
end

local function addExitTarget(cfg)
    local c = cfg.coords
    if not c then return end
    exports['qb-target']:AddBoxZone('casino_exit_' .. cfg.id, c, cfg.length or 2.0, cfg.width or 2.0, {
        name = 'casino_exit_' .. cfg.id,
        heading = 0.0,
        minZ = c.z - 1.0,
        maxZ = c.z + 1.2,
        debugPoly = false,
    }, {
        options = {
            {
                icon = 'fas fa-door-closed',
                label = cfg.label or 'Išeiti iš kazino',
                action = function()
                    exitCasino(cfg)
                end,
            },
        },
        distance = 2.5,
    })
end

local function setupEntrances()
    if GetResourceState('qb-target') ~= 'started' then return end
    for _, cfg in ipairs(Config.CasinoEntrances or {}) do
        addEntranceTarget(cfg)
    end
    for _, cfg in ipairs(Config.CasinoExits or {}) do
        addExitTarget(cfg)
    end
end

CreateThread(function()
    Wait(800)
    Casino.loadIpl()
    while GetResourceState('qb-target') ~= 'started' do Wait(400) end
    setupEntrances()
end)

-- IPL užkraunamas ir artėjant prie kazino išorės
CreateThread(function()
    local blip = Config.Casino and Config.Casino.blip and Config.Casino.blip.coords
    while true do
        local sleep = 2500
        if blip then
            local p = GetEntityCoords(PlayerPedId())
            if #(p - blip) < 220.0 then
                Casino.loadIpl()
                sleep = 8000
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, cfg in ipairs(Config.CasinoEntrances or {}) do
        pcall(function() exports['qb-target']:RemoveZone('casino_enter_' .. cfg.id) end)
    end
    for _, cfg in ipairs(Config.CasinoExits or {}) do
        pcall(function() exports['qb-target']:RemoveZone('casino_exit_' .. cfg.id) end)
    end
end)
