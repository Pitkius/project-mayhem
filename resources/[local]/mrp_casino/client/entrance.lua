local QBCore = exports['qb-core']:GetCoreObject()

local transitioning = false

local function notify(msg, ntype)
    QBCore.Functions.Notify(msg, ntype or 'primary')
end

local function pointInBox(point, center, length, width, heading)
    local rad = math.rad(heading or 0.0)
    local dx = point.x - center.x
    local dy = point.y - center.y
    local localX = dx * math.cos(rad) + dy * math.sin(rad)
    local localY = -dx * math.sin(rad) + dy * math.cos(rad)
    return math.abs(localX) <= (width or 2.0) / 2.0 and math.abs(localY) <= (length or 2.0) / 2.0
end

local function seamlessMove(dest, heading)
    if transitioning then return end
    transitioning = true

    Casino.loadIpl(true)

    local ped = PlayerPedId()
    for _ = 1, 20 do
        RequestCollisionAtCoord(dest.x, dest.y, dest.z)
        Wait(0)
    end

    SetEntityCoordsNoOffset(ped, dest.x, dest.y, dest.z, false, false, false)
    if heading then SetEntityHeading(ped, heading) end
    Casino.prepareInteriorAt(dest.x, dest.y, dest.z)

    Wait(100)
    transitioning = false
end

local function tryEnter(cfg)
    if transitioning then return end
    if Casino.isBanned and Casino.isBanned() then
        notify('Jūs laikinai negalite įeiti į kazino.', 'error')
        return
    end
    local dest = cfg.interior
    if not dest then return end
    seamlessMove(vector3(dest.x, dest.y, dest.z), dest.w)
end

local function tryExit(cfg)
    if transitioning then return end
    local dest = cfg.exterior
    if not dest then return end
    seamlessMove(vector3(dest.x, dest.y, dest.z), dest.w)
end

--- Durų zonos — įėjimas/išėjimas be juodo ekrano (IPL jau užkrautas)
CreateThread(function()
    Wait(1500)
    while true do
        local sleep = 500
        local ped = PlayerPedId()
        local p = GetEntityCoords(ped)
        local casino = Config.Casino or {}

        if casino.walkIn ~= false then
            if p.z > 0.0 then
                for _, cfg in ipairs(Config.CasinoEntrances or {}) do
                    if cfg.coords and pointInBox(p, cfg.coords, cfg.length, cfg.width, cfg.heading) then
                        sleep = 0
                        if IsPedOnFoot(ped) and (IsControlPressed(0, 32) or #(p - cfg.coords) < 1.0) then
                            tryEnter(cfg)
                        end
                    end
                end
            else
                for _, cfg in ipairs(Config.CasinoExits or {}) do
                    if cfg.coords and pointInBox(p, cfg.coords, cfg.length or 2.0, cfg.width or 2.0, 0.0) then
                        sleep = 0
                        if IsPedOnFoot(ped) and (IsControlPressed(0, 32) or #(p - cfg.coords) < 1.0) then
                            tryExit(cfg)
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

--- Atsarginis qb-target (jei reikia rankinio įėjimo)
CreateThread(function()
    if not Config.Casino or Config.Casino.walkIn == false then return end
    Wait(2000)
    while GetResourceState('qb-target') ~= 'started' do Wait(400) end

    for _, cfg in ipairs(Config.CasinoEntrances or {}) do
        local c = cfg.coords
        if not c then goto continue end
        exports['qb-target']:AddBoxZone('casino_enter_' .. cfg.id, c, cfg.length or 2.2, cfg.width or 2.6, {
            name = 'casino_enter_' .. cfg.id,
            heading = cfg.heading or 0.0,
            minZ = c.z - 1.2,
            maxZ = c.z + 1.4,
            debugPoly = false,
        }, {
            options = {
                {
                    icon = 'fas fa-door-open',
                    label = 'Įeiti į kazino',
                    action = function() tryEnter(cfg) end,
                },
            },
            distance = 2.5,
        })
        ::continue::
    end

    for _, cfg in ipairs(Config.CasinoExits or {}) do
        local c = cfg.coords
        if not c then goto continue end
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
                    label = 'Išeiti iš kazino',
                    action = function() tryExit(cfg) end,
                },
            },
            distance = 2.5,
        })
        ::continue::
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
