local QBCore = exports['qb-core']:GetCoreObject()

local function playerJobName()
    local P = QBCore.Functions.GetPlayerData()
    return P and P.job and P.job.name or nil
end

local function floorAllowed(floor)
    if not floor.jobs or #floor.jobs == 0 then return true end
    local job = playerJobName()
    if not job then return false end
    for _, allowed in ipairs(floor.jobs) do
        if allowed == job then return true end
    end
    return false
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
    if not bestIdx or bestDist > 12.0 then return nil end
    return bestIdx
end

local function teleportToFloor(floor)
    local ped = PlayerPedId()
    local c = floor.coords
    DoScreenFadeOut(350)
    while not IsScreenFadedOut() do Wait(0) end
    RequestCollisionAtCoord(c.x, c.y, c.z)
    SetEntityCoords(ped, c.x, c.y, c.z, false, false, false, false)
    SetEntityHeading(ped, c.w or 0.0)
    local timeout = GetGameTimer() + 2500
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do
        Wait(0)
    end
    Wait(150)
    DoScreenFadeIn(350)
    QBCore.Functions.Notify(('Atvykai: %s'):format(floor.label or 'aukštas'), 'success', 3500)
end

RegisterNetEvent('mrp_ambulance:client:useElevator', function(data)
    if GetResourceState('qb-menu') ~= 'started' then
        return QBCore.Functions.Notify('Reikia qb-menu.', 'error')
    end
    local elevatorId = type(data) == 'table' and data.elevatorId or nil
    if not elevatorId then return end

    local elevator
    for _, el in ipairs(Config.PillboxElevators or {}) do
        if el.id == elevatorId then
            elevator = el
            break
        end
    end
    if not elevator then return end

    local currentIdx = nearestFloorIndex(elevator, GetEntityCoords(PlayerPedId()))
    local menu = {
        { header = elevator.label or 'Liftas', isMenuHeader = true },
    }

    for i, floor in ipairs(elevator.floors or {}) do
        if i ~= currentIdx then
            local restricted = not floorAllowed(floor)
            menu[#menu + 1] = {
                header = floor.label or ('Aukštas %s'):format(i),
                txt = restricted and 'Prieiga tik EMS / policijai' or (floor.desc or ''),
                params = {
                    isAction = true,
                    event = function()
                        if restricted then
                            return QBCore.Functions.Notify('Šis aukštas – tik EMS / policijai.', 'error')
                        end
                        teleportToFloor(floor)
                    end,
                },
            }
        end
    end

    if #menu < 2 then
        return QBCore.Functions.Notify('Nėra kitų aukštų iš šio lifto.', 'error')
    end

    menu[#menu + 1] = {
        header = 'Uždaryti',
        params = { event = 'qb-menu:client:closeMenu' },
    }
    TriggerEvent('qb-menu:client:openMenu', menu, false, true)
end)

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do
        Wait(300)
    end

    for _, elevator in ipairs(Config.PillboxElevators or {}) do
        for pi, panel in ipairs(elevator.panels or {}) do
            local zoneId = ('mrp_pillbox_lift_%s_%s'):format(elevator.id, pi)
            exports['qb-target']:AddBoxZone(zoneId, panel.coords, panel.length or 0.5, panel.width or 0.5, {
                name = zoneId,
                heading = panel.heading or 0.0,
                debugPoly = false,
                minZ = panel.coords.z - 1.1,
                maxZ = panel.coords.z + 1.35,
            }, {
                options = {
                    {
                        type = 'client',
                        event = 'mrp_ambulance:client:useElevator',
                        icon = 'fas fa-elevator',
                        label = elevator.label or 'Liftas',
                        elevatorId = elevator.id,
                    },
                },
                distance = 2.0,
            })
        end
    end
end)
