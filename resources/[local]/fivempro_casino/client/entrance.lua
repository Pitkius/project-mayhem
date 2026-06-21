local QBCore = exports['qb-core']:GetCoreObject()

local teleporting = false

local function notify(msg, ntype)
    QBCore.Functions.Notify(msg, ntype or 'primary')
end

local function fadeTeleport(coords, heading)
    if teleporting then return end
    teleporting = true

    Casino.loadIpl(true)

    DoScreenFadeOut(400)
    while not IsScreenFadedOut() do Wait(0) end

    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
    if heading then
        SetEntityHeading(ped, heading)
    end

    Casino.prepareInteriorAt(coords.x, coords.y, coords.z)

    Wait(500)
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
    while GetResourceState('qb-target') ~= 'started' do Wait(400) end
    setupEntrances()
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
