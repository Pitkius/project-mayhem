local QBCore = exports['qb-core']:GetCoreObject()

local teleporting = false
local lastMenuMs = 0
local zoneIds = {}

local function playerData()
    return QBCore.Functions.GetPlayerData()
end

local function playerJobName()
    local P = playerData()
    return P and P.job and P.job.name or nil
end

local function playerOnDuty()
    local P = playerData()
    return P and P.job and P.job.onduty == true
end

local function jobInList(job, list)
    if not list or #list == 0 then return true end
    if not job then return false end
    for _, allowed in ipairs(list) do
        if allowed == job then return true end
    end
    return false
end

local function elevatorAllowed(elevator)
    if not jobInList(playerJobName(), elevator.jobs) then return false end
    if elevator.requireDuty and not playerOnDuty() then return false end
    return true
end

local function floorAllowed(elevator, floor)
    if not elevatorAllowed(elevator) then return false end
    return jobInList(playerJobName(), floor.jobs)
end

local function findElevator(id)
    for _, el in ipairs(Config.Elevators or {}) do
        if el.id == id then return el end
    end
    return nil
end

local function nearestFloorIndex(elevator, coords)
    local bestIdx, bestDist = nil, 999.0
    for i, floor in ipairs(elevator.floors or {}) do
        local fc = floor.coords
        local dist = #(coords - vector3(fc.x, fc.y, fc.z))
        if dist < bestDist then
            bestDist = dist
            bestIdx = i
        end
    end
    if not bestIdx or bestDist > 14.0 then return nil end
    return bestIdx
end

local function panelPoints(elevator)
    local defL = tonumber(Config.DefaultPanelLength) or 1.35
    local defW = tonumber(Config.DefaultPanelWidth) or 1.35
    if elevator.panels and #elevator.panels > 0 then
        local out = {}
        for _, panel in ipairs(elevator.panels) do
            out[#out + 1] = {
                coords = panel.coords,
                heading = panel.heading or 0.0,
                length = panel.length or defL,
                width = panel.width or defW,
            }
        end
        return out
    end
    local out = {}
    for _, floor in ipairs(elevator.floors or {}) do
        local c = floor.coords
        out[#out + 1] = {
            coords = vector3(c.x, c.y, c.z),
            heading = c.w or 0.0,
            length = defL,
            width = defW,
        }
    end
    return out
end

local function teleportToFloor(floor)
    if teleporting then return end
    teleporting = true
    local ped = PlayerPedId()
    local c = floor.coords
    local fade = tonumber(Config.FadeMs) or 350

    DoScreenFadeOut(fade)
    while not IsScreenFadedOut() do Wait(0) end

    RequestCollisionAtCoord(c.x, c.y, c.z)
    SetEntityCoordsNoOffset(ped, c.x, c.y, c.z, false, false, false)
    SetEntityHeading(ped, c.w or 0.0)

    local timeout = GetGameTimer() + 2500
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do
        Wait(0)
    end
    Wait(120)
    DoScreenFadeIn(fade)
    teleporting = false
    QBCore.Functions.Notify(('Atvykai: %s'):format(floor.label or 'aukštas'), 'success', 3500)
end

local function openElevatorMenu(elevatorId)
    if teleporting then return end
    if GetResourceState('qb-menu') ~= 'started' then
        return QBCore.Functions.Notify('Reikia qb-menu.', 'error')
    end

    local now = GetGameTimer()
    if now - lastMenuMs < 400 then return end
    lastMenuMs = now

    local elevator = findElevator(elevatorId)
    if not elevator then return end

    if not elevatorAllowed(elevator) then
        return QBCore.Functions.Notify('Šis liftas – tik tarnybai.', 'error')
    end

    local currentIdx = nearestFloorIndex(elevator, GetEntityCoords(PlayerPedId()))
    local menu = {
        { header = elevator.label or 'Liftas', isMenuHeader = true },
    }

    for i, floor in ipairs(elevator.floors or {}) do
        if i ~= currentIdx then
            local allowed = floorAllowed(elevator, floor)
            local jobHint = floor.jobs and table.concat(floor.jobs, ', ') or nil
            menu[#menu + 1] = {
                header = floor.label or ('Aukštas %s'):format(i),
                txt = (not allowed and ('Prieiga: %s'):format(jobHint or 'tarnyba'))
                    or (floor.desc or ''),
                disabled = not allowed,
                params = {
                    isAction = true,
                    event = function()
                        if not floorAllowed(elevator, floor) then
                            return QBCore.Functions.Notify('Neturi prieigos prie šio aukšto.', 'error')
                        end
                        teleportToFloor(floor)
                    end,
                },
            }
        end
    end

    if #menu < 2 then
        return QBCore.Functions.Notify('Nėra kitų aukštų.', 'error')
    end

    menu[#menu + 1] = {
        header = 'Uždaryti',
        params = { event = 'qb-menu:client:closeMenu' },
    }
    TriggerEvent('qb-menu:client:openMenu', menu, false, true)
end

RegisterNetEvent('mrp_elevators:client:use', function(data)
    local id = type(data) == 'table' and (data.elevatorId or data.id) or data
    if id then openElevatorMenu(tostring(id)) end
end)

local function clearTargetZones()
    if GetResourceState('qb-target') ~= 'started' then
        zoneIds = {}
        return
    end
    for _, zoneId in ipairs(zoneIds) do
        pcall(function()
            exports['qb-target']:RemoveZone(zoneId)
        end)
    end
    zoneIds = {}
end

local function registerTargetZones()
    clearTargetZones()
    if GetResourceState('qb-target') ~= 'started' then
        print('[mrp_elevators] qb-target neįjungtas — liftai neveiks.')
        return
    end

    local minZOff = tonumber(Config.PanelMinZ) or 1.15
    local maxZOff = tonumber(Config.PanelMaxZ) or 1.45
    local dist = tonumber(Config.InteractDistance) or 2.2

    for _, elevator in ipairs(Config.Elevators or {}) do
        local elevId = elevator.id
        local elevLabel = elevator.label or 'Liftas'
        for pi, panel in ipairs(panelPoints(elevator)) do
            local zoneId = ('mrp_elev_%s_%s'):format(elevId, pi)
            local ok = pcall(function()
                exports['qb-target']:AddBoxZone(zoneId, panel.coords, panel.length, panel.width, {
                    name = zoneId,
                    heading = panel.heading or 0.0,
                    debugPoly = false,
                    minZ = panel.coords.z - minZOff,
                    maxZ = panel.coords.z + maxZOff,
                }, {
                    options = {
                        {
                            type = 'client',
                            event = 'mrp_elevators:client:use',
                            icon = 'fas fa-elevator',
                            label = elevLabel,
                            elevatorId = elevId,
                            canInteract = function()
                                return elevatorAllowed(elevator)
                            end,
                        },
                    },
                    distance = dist,
                })
            end)
            if ok then
                zoneIds[#zoneIds + 1] = zoneId
            else
                print(('[mrp_elevators] Nepavyko registruoti zonos %s'):format(zoneId))
            end
        end
    end
    print(('[mrp_elevators] qb-target zonos: %d'):format(#zoneIds))
end

CreateThread(function()
    local waited = 0
    while GetResourceState('qb-target') ~= 'started' and waited < 90 do
        Wait(500)
        waited = waited + 1
    end
    Wait(300)
    registerTargetZones()
end)

AddEventHandler('onResourceStart', function(res)
    if res == 'qb-target' or res == GetCurrentResourceName() then
        SetTimeout(500, registerTargetZones)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        clearTargetZones()
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    SetTimeout(800, registerTargetZones)
end)

--- Debug: tavo coords + artimiausi lifto aukštai (F8)
RegisterCommand('lifto', function()
    local pcoords = GetEntityCoords(PlayerPedId())
    local heading = GetEntityHeading(PlayerPedId())
    print(('[mrp_elevators] tavo pozicija: %.4f, %.4f, %.4f, %.2f'):format(
        pcoords.x, pcoords.y, pcoords.z, heading))
    print(('[mrp_elevators] qb-target zonos: %d'):format(#zoneIds))
    for _, elevator in ipairs(Config.Elevators or {}) do
        for i, floor in ipairs(elevator.floors or {}) do
            local c = floor.coords
            local d = #(pcoords - vector3(c.x, c.y, c.z))
            if d < 40.0 then
                print(('  %s floor#%d %s dist=%.1fm @ %.2f,%.2f,%.2f'):format(
                    elevator.id, i, floor.label or '?', d, c.x, c.y, c.z))
            end
        end
    end
    QBCore.Functions.Notify('Lifto info atspausdinta F8 konsolėje.', 'primary')
end, false)
