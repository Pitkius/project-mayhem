local QBCore = exports['qb-core']:GetCoreObject()

WeedDrying = WeedDrying or {}

local session = nil
local plantEntities = {}
local targetCreated = false
local collecting = false
local requestSession
local collectRequestId = 0

local function cfg()
    return Config.WeedDrying or {}
end

local function stationCoords()
    local c = cfg().coords or vector4(1144.5762, -1661.0204, 36.6147, 203.0073)
    return vector3(c.x, c.y, c.z)
end

local function visualCoords()
    local c = cfg().visualCoords or vector4(1144.2369, -1660.1793, 36.8147, 207.3685)
    return vector3(c.x, c.y, c.z)
end

local function remainingSeconds()
    if not session then return 0 end
    local remainingMs = (tonumber(session.expiresAtGameTimer) or GetGameTimer()) - GetGameTimer()
    return math.max(0, math.ceil(remainingMs / 1000))
end

local function isReady()
    return session ~= nil and remainingSeconds() <= 0
end

local function formatTime(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    return ('%02d:%02d'):format(math.floor(seconds / 60), seconds % 60)
end

local function clearPlants()
    for _, entity in ipairs(plantEntities) do
        if entity and DoesEntityExist(entity) then DeleteEntity(entity) end
    end
    plantEntities = {}
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(10) end
    return HasModelLoaded(hash) and hash or nil
end

local function setEntityScale(entity, scale)
    if not entity or not DoesEntityExist(entity) then return end
    local forward, right, up, position = GetEntityMatrix(entity)
    SetEntityMatrix(entity, forward * scale, right * scale, up * scale, position)
end

local function offsetPoint(origin, heading, side, forward, up)
    local angle = math.rad(heading)
    local right = vector3(math.cos(angle), math.sin(angle), 0.0)
    local front = vector3(-math.sin(angle), math.cos(angle), 0.0)
    return origin + right * side + front * forward + vector3(0.0, 0.0, up or 0.0)
end

local function spawnPlants()
    if not session or #plantEntities > 0 then return end
    local potModel = loadModel('bkr_prop_weed_bucket_01a')
    local plantModel = loadModel('bkr_prop_weed_med_01a') or loadModel('prop_weed_02')
    if not potModel or not plantModel then
        return QBCore.Functions.Notify('Nepavyko užkrauti džiūstančių augalų vazonų.', 'error')
    end

    -- Vazonai ir augalai yra lokalūs: juos mato tik aktyvios sesijos savininkas.
    local c = cfg().visualCoords or vector4(1144.2369, -1660.1793, 36.8147, 207.3685)
    local origin = vector3(c.x, c.y, c.z)
    local heading = tonumber(c.w) or 203.0073
    local count = math.max(1, tonumber(cfg().visualPlantCount) or 10)
    for i = 1, count do
        local row = math.floor((i - 1) / 5)
        local column = (i - 1) % 5
        local itemHeading = heading + ((column - 2) * 4.0)
        local pos = offsetPoint(origin, heading, -1.12 + column * 0.56, -0.38 + row * 0.76, 0.0)

        local pot = CreateObjectNoOffset(potModel, pos.x, pos.y, pos.z, false, false, false)
        if pot and pot ~= 0 then
            SetEntityAsMissionEntity(pot, true, true)
            SetEntityHeading(pot, itemHeading)
            setEntityScale(pot, 0.92)
            SetEntityCollision(pot, false, false)
            SetEntityVisible(pot, true, false)
            FreezeEntityPosition(pot, true)
            plantEntities[#plantEntities + 1] = pot
        end

        local plant = CreateObjectNoOffset(plantModel, pos.x, pos.y, pos.z + 0.24, false, false, false)
        if plant and plant ~= 0 then
            SetEntityAsMissionEntity(plant, true, true)
            SetEntityHeading(plant, itemHeading)
            setEntityScale(plant, 0.48)
            SetEntityCollision(plant, false, false)
            SetEntityVisible(plant, true, false)
            FreezeEntityPosition(plant, true)
            plantEntities[#plantEntities + 1] = plant
        end
    end
    SetModelAsNoLongerNeeded(potModel)
    SetModelAsNoLongerNeeded(plantModel)
end

local function setSession(data)
    clearPlants()
    if type(data) ~= 'table' or not data.quantity then
        session = nil
        return
    end
    session = data
    session.expiresAtGameTimer = GetGameTimer() + math.max(0, tonumber(data.remainingSeconds) or 0) * 1000
    if #(GetEntityCoords(PlayerPedId()) - stationCoords()) <= 100.0 then spawnPlants() end
end

RegisterNetEvent('mrp_drugs:client:setWeedDryingSession', setSession)

local function collect()
    if collecting or not session then return end
    collecting = true
    collectRequestId = collectRequestId + 1
    local requestId = collectRequestId
    QBCore.Functions.TriggerCallback('mrp_drugs:server:collectWeedDrying', function(response)
        if requestId ~= collectRequestId then return end
        collecting = false
        if not response or not response.ok then
            requestSession()
            return QBCore.Functions.Notify((response and response.reason) or 'Nepavyko surinkti žolės.', 'error')
        end
        setSession(nil)
        QBCore.Functions.Notify(response.reason or 'Žolė surinkta.', response.ready and 'success' or 'error', 6500)
    end)
    CreateThread(function()
        Wait(10000)
        if collecting and requestId == collectRequestId then
            collecting = false
            collectRequestId = collectRequestId + 1
            requestSession()
            QBCore.Functions.Notify('Serveris neatsakė. Džiovinimo būsena atnaujinta.', 'error')
        end
    end)
end

local function setupTarget()
    if targetCreated or GetResourceState('qb-target') ~= 'started' then return end
    targetCreated = true
    -- Surinkimo zona yra ant pačių gulinčių augalų, o ne ant UI paleidimo taško.
    exports['qb-target']:AddCircleZone('mrp_weed_drying_collect', visualCoords(), 2.4, {
        name = 'mrp_weed_drying_collect',
        debugPoly = false,
        useZ = true,
    }, {
        options = {
            {
                icon = 'fas fa-box-open',
                label = 'Pasiimti išdžiovintą žolę',
                action = collect,
                canInteract = function()
                    return session ~= nil and isReady() and not collecting
                end,
            },
            {
                icon = 'fas fa-exclamation-triangle',
                label = 'Nutraukti džiovinimą (grįš tik 20%)',
                action = collect,
                canInteract = function()
                    return session ~= nil and not isReady() and not collecting
                end,
            },
        },
        distance = tonumber(cfg().interactDistance) or 4.0,
    })
end

local function drawHologram(coords, text)
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    if GetResourceState('mrp_fonts') == 'started' then
        exports['mrp_fonts']:ApplyTextFont()
    else
        SetTextFont(4)
    end
    SetTextScale(0.36, 0.36)
    SetTextProportional(1)
    SetTextColour(214, 255, 224, 245)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

requestSession = function()
    QBCore.Functions.TriggerCallback('mrp_drugs:server:getWeedDryingSession', function(response)
        if response and response.ok then setSession(response.session) end
    end)
end

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do Wait(250) end
    setupTarget()
    Wait(1500)
    requestSession()

    while true do
        local sleep = 1000
        if session then
            local coords = GetEntityCoords(PlayerPedId())
            local distance = #(coords - visualCoords())
            if distance <= 100.0 and #plantEntities == 0 then spawnPlants() end
            if distance > 120.0 and #plantEntities > 0 then clearPlants() end
            if distance <= (tonumber(cfg().hologramDistance) or 22.0) then
                sleep = 0
                local text
                if isReady() then
                    text = ('ŽOLĖ IŠDŽIUVO · ALT – PASIIMTI · x%d'):format(session.quantity)
                else
                    text = ('ŽOLĖ DŽIŪSTA · LIKO %s · x%d'):format(formatTime(remainingSeconds()), session.quantity)
                end
                local c = visualCoords()
                drawHologram(vector3(c.x, c.y, c.z + 1.15), text)
            end
        end
        Wait(sleep)
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(1500)
    requestSession()
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    setSession(nil)
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    clearPlants()
    if targetCreated and GetResourceState('qb-target') == 'started' then
        exports['qb-target']:RemoveZone('mrp_weed_drying_collect')
    end
end)

function WeedDrying.Start(amount, onDone)
    QBCore.Functions.TriggerCallback('mrp_drugs:server:startWeedDrying', function(response)
        if response and response.ok then setSession(response.session) end
        if onDone then onDone(response) end
    end, amount)
end
