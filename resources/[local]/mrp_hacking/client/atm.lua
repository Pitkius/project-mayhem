local QBCore = exports['qb-core']:GetCoreObject()

local session = nil
local atmProp = nil
local dropBlip = nil
local chainAnchor = nil ---@type vector3|nil
local chainVehicle = nil

local function hasHackTablet()
    return QBCore.Functions.HasItem('basic_tablet', 1)
        or QBCore.Functions.HasItem('advanced_tablet', 1)
        or QBCore.Functions.HasItem('military_tablet', 1)
end

local function clearDropBlip()
    if dropBlip and DoesBlipExist(dropBlip) then RemoveBlip(dropBlip) end
    dropBlip = nil
end

local function clearAtmProp()
    if atmProp and DoesEntityExist(atmProp) then DeleteEntity(atmProp) end
    atmProp = nil
end

local function clearChainVisual()
    chainAnchor = nil
    chainVehicle = nil
end

local function resetSession()
    if session and session.coords then
        TriggerServerEvent('mrp_hacking:server:atmRelease', session.coords)
    end
    clearAtmProp()
    clearDropBlip()
    clearChainVisual()
    session = nil
end

local function vehicleAllowed(veh)
    if not veh or veh == 0 then return false end
    local cls = GetVehicleClass(veh)
    if Config.Atm.AllowedVehicleClasses[cls] == false then return false end
    return true
end

local function getAtmAnchorPos()
    if session and session.entity and session.entity ~= 0 and DoesEntityExist(session.entity) then
        local c = GetEntityCoords(session.entity)
        return vector3(c.x, c.y, c.z + 0.55)
    end
    if session and session.coords then
        return vector3(session.coords.x, session.coords.y, session.coords.z + 0.55)
    end
    return nil
end

local function getVehicleRearPos(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    local bones = { 'boot', 'bumper_r', 'chassis', 'bodyshell' }
    for _, name in ipairs(bones) do
        local idx = GetEntityBoneIndexByName(veh, name)
        if idx ~= -1 then
            return GetWorldPositionOfEntityBone(veh, idx)
        end
    end
    local c = GetEntityCoords(veh)
    local fwd = GetEntityForwardVector(veh)
    return vector3(c.x - fwd.x * 2.35, c.y - fwd.y * 2.35, c.z + 0.35)
end

local function findNearestAttachVehicle(pcoords, maxDist)
    local best, bestD = 0, maxDist + 1.0
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if DoesEntityExist(veh) and vehicleAllowed(veh) then
            local rear = getVehicleRearPos(veh)
            if rear then
                local d = #(pcoords - rear)
                if d <= maxDist and d < bestD then
                    bestD = d
                    best = veh
                end
            end
        end
    end
    return best
end

local function drawChainRope(fromPos, toPos)
    local col = Config.Atm.ChainRopeColor or { r = 120, g = 118, b = 125, a = 230 }
    local segments = 14
    local sag = Config.Atm.ChainRopeSag or 0.45
    local prev = fromPos
    for i = 1, segments do
        local t = i / segments
        local x = fromPos.x + (toPos.x - fromPos.x) * t
        local y = fromPos.y + (toPos.y - fromPos.y) * t
        local z = fromPos.z + (toPos.z - fromPos.z) * t - math.sin(t * math.pi) * sag
        local pt = vector3(x, y, z)
        DrawLine(prev.x, prev.y, prev.z, pt.x, pt.y, pt.z, col.r, col.g, col.b, col.a)
        DrawLine(prev.x + 0.03, prev.y, prev.z, pt.x + 0.03, pt.y, pt.z, col.r - 15, col.g - 15, col.b - 15, col.a - 30)
        DrawLine(prev.x - 0.03, prev.y, prev.z, pt.x - 0.03, pt.y, pt.z, col.r - 15, col.g - 15, col.b - 15, col.a - 30)
        prev = pt
    end
    DrawMarker(28, toPos.x, toPos.y, toPos.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.14, 0.14, 0.14, 200, 180, 80, 180, false, false, 2, false, false, false, false)
    DrawMarker(28, fromPos.x, fromPos.y, fromPos.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.12, 0.12, 0.12, 200, 180, 80, 160, false, false, 2, false, false, false, false)
end

RegisterNetEvent('mrp_hacking:client:hackSuccess', function(tierId, coords, ctx)
    if tierId ~= 'atm' or not session then return end
    session.phase = 'hacked'
    QBCore.Functions.Notify('ATM apsauga apeita. Gali gręžti.', 'success')
end)

RegisterNetEvent('mrp_hacking:client:hackFailed', function(tierId)
    if tierId ~= 'atm' then return end
    resetSession()
end)

RegisterNetEvent('mrp_hacking:client:atmDrillOk', function(coords)
    if not session then return end
    session.phase = 'drilled'
    chainAnchor = getAtmAnchorPos()
    QBCore.Functions.Notify('Prieik prie automobilio galo ir spausk ALT (grandinė).', 'primary')
end)

RegisterNetEvent('mrp_hacking:client:atmChainOk', function(coords)
    if not session then return end
    session.phase = 'chained'
    clearChainVisual()
    QBCore.Functions.Notify('Sėsk į stiprią mašiną ir tempk ATM (vairuok ~50m).', 'primary')
    if not spawnPulledAtm() then
        session.pendingAtmSpawn = true
    end
end)

RegisterNetEvent('mrp_hacking:client:atmGoCrack', function(dropIndex)
    if not session then return end
    session.phase = 'crack'
    session.dropIndex = dropIndex
    clearChainVisual()
    local drop = Config.Atm.Dropoffs[dropIndex]
    if drop then
        clearDropBlip()
        dropBlip = AddBlipForCoord(drop.coords.x, drop.coords.y, drop.coords.z)
        SetBlipSprite(dropBlip, 478)
        SetBlipColour(dropBlip, 1)
        exports['mrp_fonts']:SetBlipName(dropBlip, drop.label or 'ATM drop')
        QBCore.Functions.Notify('Nuvežk ATM į saugią vietą ir išlaužk.', 'success')
    end
end)

RegisterNetEvent('mrp_hacking:client:atmFinished', function()
    resetSession()
end)

local function getVehicleAttachBone(veh)
    if not veh or veh == 0 then return -1, nil end
    local bones = { 'boot', 'bumper_r', 'chassis', 'bodyshell' }
    for _, name in ipairs(bones) do
        local idx = GetEntityBoneIndexByName(veh, name)
        if idx ~= -1 then return idx, name end
    end
    return -1, nil
end

function spawnPulledAtm()
    clearAtmProp()
    local ped = PlayerPedId()
    local veh = chainVehicle
    if (not veh or veh == 0 or not DoesEntityExist(veh)) and session then
        veh = session.chainVehicle
    end
    if (not veh or veh == 0) then
        veh = GetVehiclePedIsIn(ped, false)
    end
    if veh == 0 or not DoesEntityExist(veh) then return false end
    local model = joaat(Config.Atm.AttachedModel or 'prop_atm_01')
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end
    local rear = getVehicleRearPos(veh)
    if not rear then return false end
    local boneIdx, boneName = getVehicleAttachBone(veh)
    if boneIdx == -1 then boneIdx = 0 end
    atmProp = CreateObject(model, rear.x, rear.y, rear.z - 0.35, true, true, false)
    AttachEntityToEntity(atmProp, veh, boneIdx, 0.0, -1.85, 0.35, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
    session.chainVehicle = veh
    session.pullStart = GetEntityCoords(veh)
    return true
end

local function tryAttachChain()
    if not session or session.phase ~= 'drilled' then return end
    local ped = PlayerPedId()
    local pcoords = GetEntityCoords(ped)
    local maxD = Config.Atm.ChainAttachMaxDist or 4.2
    local veh = findNearestAttachVehicle(pcoords, maxD)
    if veh == 0 then
        return QBCore.Functions.Notify('Nėra tinkamo automobilio šalia galo — priartėk su SUV/pickup.', 'error')
    end
    local rear = getVehicleRearPos(veh)
    if not rear or #(pcoords - rear) > maxD then
        return QBCore.Functions.Notify('Eik arčiau automobilio galinės dalies.', 'error')
    end
    chainVehicle = veh
    session.chainVehicle = veh

    local mg = (Config.RobberyMinigames or {}).chain
    local anim = (Config.RobberyAnims or {}).chain
    local ok = exports['mrp_hacking']:RunPhysicalMinigame(mg.mode, {
        label = mg.label,
        anim = anim,
        data = mg.data or {},
    })
    if not ok then
        return QBCore.Functions.Notify('Grandinės tvirtinimas atšauktas.', 'error')
    end
    TriggerServerEvent('mrp_hacking:server:atmChainDone', session.coords)
end

local function startAtmSession(entity)
    local coords = GetEntityCoords(entity)
    QBCore.Functions.TriggerCallback('mrp_hacking:server:atmCanStart', function(res)
        if not res or not res.ok then
            return QBCore.Functions.Notify((res and res.msg) or 'Negalima.', 'error')
        end
        session = { entity = entity, coords = { x = coords.x, y = coords.y, z = coords.z }, phase = 'idle' }
        TriggerServerEvent('mrp_hacking:server:atmClaim', session.coords)
        exports['mrp_hacking']:StartHack('atm', coords, function(ok)
            if not ok then resetSession() end
        end)
    end, { x = coords.x, y = coords.y, z = coords.z })
end

local function doDrill()
    if not session or session.phase ~= 'hacked' then return end
    local mg = (Config.RobberyMinigames or {}).atm_drill
    local anim = (Config.RobberyAnims or {}).drill
    local ok = exports['mrp_hacking']:RunPhysicalMinigame(mg.mode, {
        label = mg.label,
        anim = anim,
        data = mg.data or {},
    })
    if ok then
        TriggerServerEvent('mrp_hacking:server:atmDrillDone', session.coords)
    else
        QBCore.Functions.Notify('Gręžimas nepavyko.', 'error')
    end
end

local function tryPullComplete()
    if not session or session.phase ~= 'chained' or not session.pullStart then return end
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then return end
    if not vehicleAllowed(veh) then return end
    local dist = #(GetEntityCoords(veh) - vector3(session.pullStart.x, session.pullStart.y, session.pullStart.z))
    if dist < (Config.Atm.PullMinDistance or 45) then return end
    session.phase = 'delivered'
    local dropIdx = math.random(1, #(Config.Atm.Dropoffs or {}))
    TriggerServerEvent('mrp_hacking:server:atmPulled', session.coords, dropIdx)
end

local function startCrackHack()
    exports['mrp_hacking']:StartHack('atm', GetEntityCoords(PlayerPedId()), function(ok)
        TriggerServerEvent('mrp_hacking:server:atmCrackResult', ok, not ok, session.dropIndex)
    end)
end

CreateThread(function()
    while true do
        if session and session.phase == 'chained' and session.pendingAtmSpawn then
            local ped = PlayerPedId()
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= 0 and vehicleAllowed(veh) then
                session.chainVehicle = veh
                if spawnPulledAtm() then
                    session.pendingAtmSpawn = nil
                    QBCore.Functions.Notify('ATM prikabintas prie automobilio — tempk!', 'success')
                end
            end
            Wait(500)
        else
            Wait(800)
        end
    end
end)

CreateThread(function()
    while true do
        if session and session.phase == 'chained' then
            tryPullComplete()
            Wait(500)
        else
            Wait(1200)
        end
    end
end)

CreateThread(function()
    local attachKey = Config.Atm.ChainAttachControl or 19
    while true do
        if session and session.phase == 'drilled' then
            local ped = PlayerPedId()
            local pcoords = GetEntityCoords(ped)
            local anchor = chainAnchor or getAtmAnchorPos()
            local maxD = Config.Atm.ChainAttachMaxDist or 4.2
            local veh = findNearestAttachVehicle(pcoords, maxD)
            local rear = veh ~= 0 and getVehicleRearPos(veh) or nil

            if anchor and rear then
                drawChainRope(anchor, rear)
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName('~INPUT_CHARACTER_WHEEL~ (ALT) — prikabinti grandinę prie automobilio')
                EndTextCommandDisplayHelp(0, false, true, -1)
            elseif anchor then
                drawChainRope(anchor, pcoords + vector3(0.0, 0.0, 0.4))
            end

            if IsControlJustPressed(0, attachKey) then
                tryAttachChain()
            end
            Wait(0)
        else
            Wait(400)
        end
    end
end)

CreateThread(function()
    while true do
        if session and session.phase == 'crack' and session.dropIndex then
            local drop = Config.Atm.Dropoffs[session.dropIndex]
            if drop then
                local p = GetEntityCoords(PlayerPedId())
                if #(p - drop.coords) < (drop.radius or 12) then
                    DrawMarker(1, drop.coords.x, drop.coords.y, drop.coords.z - 1.0, 0, 0, 0, 0, 0, 0, 2.5, 2.5, 1.0, 255, 80, 80, 120, false, false, 2, false, false, false, false)
                    if IsControlJustPressed(0, 38) then
                        startCrackHack()
                    end
                end
            end
            Wait(0)
        else
            Wait(600)
        end
    end
end)

CreateThread(function()
    exports['qb-target']:AddTargetModel(Config.Atm.Models, {
        options = {
            {
                icon = 'fas fa-laptop-code',
                label = 'ATM hack',
                canInteract = function()
                    if session then return false end
                    return hasHackTablet()
                end,
                action = function(entity) startAtmSession(entity) end,
            },
            {
                icon = 'fas fa-screwdriver',
                label = 'Gręžti ATM',
                canInteract = function()
                    if not session or session.phase ~= 'hacked' then return false end
                    return QBCore.Functions.HasItem(Config.DrillItem or 'drill', 1)
                end,
                action = function() doDrill() end,
            },
        },
        distance = 1.8,
    })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    resetSession()
end)
