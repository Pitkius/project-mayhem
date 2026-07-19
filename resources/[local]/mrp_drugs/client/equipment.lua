--- Client: portable įrangos prop + qb-target. Konfigūracija: config_equipment.lua
local QBCore = exports['qb-core']:GetCoreObject()

local EquipmentProps = {}
local EquipmentMeta = {}
local EquipmentBlips = {}
local placing = false
local crafting = false

AddEventHandler('mrp_drugs:client:productionReset', function()
    crafting = false
end)

RegisterNetEvent('mrp_drugs:client:abortProduction', function()
    crafting = false
end)

local function notify(msg, typ)
    QBCore.Functions.Notify(msg, typ or 'primary')
end

local function cfg()
    return Config.DrugEquipment or {}
end

local function typeCfg(itemType)
    return (cfg().types or {})[itemType]
end

local function isInsidePlacementZone(typeConfig, coords)
    if not typeConfig or not typeConfig.cayoOnly then return true end
    local placement = cfg().cayoPlacement or {}
    local center = placement.center or vector3(4840.57, -5174.42, 2.0)
    -- 1800 m sutampa su mrp_cayoperico salos žaidimo riba; serveris tai patikrina pakartotinai.
    local radius = tonumber(placement.radius) or 1800.0
    return #(coords - center) <= radius
end

local TARGET_ICONS = {
    flask = 'fas fa-flask',
    flame = 'fas fa-fire',
    pill = 'fas fa-pills',
    scale = 'fas fa-weight-scale',
    bag = 'fas fa-bag-shopping',
}

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 5000 do
        Wait(10)
        t = t + 10
    end
    return HasModelLoaded(hash)
end

local function deleteProp(id)
    local blip = EquipmentBlips[id]
    if blip and DoesBlipExist(blip) then
        RemoveBlip(blip)
    end
    EquipmentBlips[id] = nil

    local ent = EquipmentProps[id]
    if ent and DoesEntityExist(ent) then
        exports['qb-target']:RemoveTargetEntity(ent)
        DeleteEntity(ent)
    end
    EquipmentProps[id] = nil
    EquipmentMeta[id] = nil
end

local function createOwnerTableBlip(e)
    if not e or e.fixed or e.itemType ~= 'bagging_table' then return end
    local playerData = QBCore.Functions.GetPlayerData()
    if not playerData or playerData.citizenid ~= e.citizenid then return end

    -- 469 = kanapės simbolis; blipas kuriamas tik šio portable stalo savininko klientui.
    local blip = AddBlipForCoord(e.x, e.y, e.z)
    SetBlipSprite(blip, 469)
    SetBlipColour(blip, 2)
    SetBlipScale(blip, 0.78)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString('Jūsų žolės džiovinimo stalas')
    EndTextCommandSetBlipName(blip)
    if GetResourceState('mrp_fonts') == 'started' then
        exports['mrp_fonts']:SetBlipName(blip, 'Jūsų žolės džiovinimo stalas')
    end
    EquipmentBlips[e.id] = blip
end

local function spawnEquipment(e)
    if not e or not e.id then return end
    deleteProp(e.id)
    local t = typeCfg(e.itemType)
    local model = (t and t.prop) or 'prop_tool_bench02'
    if not loadModel(model) then return end

    local obj = CreateObject(joaat(model), e.x, e.y, e.z, false, false, false)
    SetEntityHeading(obj, e.heading or 0.0)
    if e.fixed then
        SetEntityCoords(obj, e.x, e.y, e.z, false, false, false, false)
    else
        PlaceObjectOnGroundProperly(obj)
    end
    FreezeEntityPosition(obj, true)
    EquipmentProps[e.id] = obj
    -- remainingMs yra serverio apskaičiuotas likutis; expiresAt leidžia sklandžiai rodyti MM:SS.
    if e.remainingMs ~= nil then
        e.expiresAt = GetGameTimer() + math.max(0, tonumber(e.remainingMs) or 0)
    end
    EquipmentMeta[e.id] = e
    createOwnerTableBlip(e)
    SetModelAsNoLongerNeeded(joaat(model))
end

local function runSchedule(productId, profile, prod, onDone, craftToken, workspace)
    exports[GetCurrentResourceName()]:RunScheduleMinigame(productId, profile, prod, onDone, craftToken, workspace)
end

local function runEquipmentCraftFlow(productId, equipmentId)
    if crafting then return end
    crafting = true
    QBCore.Functions.TriggerCallback('mrp_drugs:server:startCraftAtEquipment', function(res)
        if not res or not res.ok then
            crafting = false
            return notify((res and res.reason) or 'Gamyba negalima.', 'error')
        end

        local function afterMinigame(success, extra)
            if ScheduleAnimStop then ScheduleAnimStop() end
            QBCore.Functions.TriggerCallback('mrp_drugs:server:finishCraft', function(done)
                crafting = false
                if not done or not done.ok then
                    notify((done and done.reason) or 'Gamyba nepavyko.', 'error')
                    return
                end
                local qLabel = done.qualityLabel and (' · ' .. done.qualityLabel) or ''
                notify(('Pagaminta: %s x%d%s'):format(done.label or done.item, done.amount or 1, qLabel), 'success')
            end, res.token, success, extra)
        end

        notify('Gamyba prie įrangos — neuždaryk proceso.', 'primary', 5000)

        local profile = Config.GetScheduleMinigame and Config.GetScheduleMinigame(productId)
        local prod = Config.Products and Config.Products[productId]
        local prepMs = math.floor((res.craftTimeMs or 20000) * 0.25)

        if res.minigame == 'schedule' then
            DrugProgress.run('mrp_equip_prep', res.label, prepMs, false, true, {
                disableMovement = true,
                disableCarMovement = true,
                disableCombat = true,
            }, nil, function()
                -- Progressbar onFinish argumentų neperduoda; pats callback iškvietimas reiškia sėkmę.
                local equipment = EquipmentMeta[equipmentId]
                local workspace = equipment and {
                    x = equipment.x,
                    y = equipment.y,
                    z = equipment.z,
                    w = equipment.heading or 0.0,
                    -- Tikslus lokalus entity handle išvengia nepatikimos stalo paieškos pagal modelį.
                    entity = EquipmentProps[equipmentId],
                } or nil
                runSchedule(productId, profile, prod, afterMinigame, res.token, workspace)
            end, function()
                afterMinigame(false)
            end)
        else
            DrugProgress.run('mrp_equip_craft', res.label, res.craftTimeMs or 25000, false, true, {
                disableMovement = true,
                disableCarMovement = true,
                disableCombat = true,
            }, nil, function(ok)
                afterMinigame(ok)
            end, function()
                afterMinigame(false)
            end)
        end
    end, equipmentId, productId)
end

local function pickEquipmentProduct(products)
    if not products or #products == 0 then return nil end
    for _, row in ipairs(products) do
        if row.canCraft then return row end
    end
    return products[1]
end

local function useEquipmentDirect(equipmentId)
    if crafting or placing then return end
    QBCore.Functions.TriggerCallback('mrp_drugs:server:getEquipmentMenu', function(res)
        if not res or not res.ok then
            return notify((res and res.reason) or 'Gamyba nepasiekiama.', 'error')
        end
        if #res.products == 0 then
            return notify('Čia negalima gaminti — naudok fiksuotą laboratoriją.', 'error')
        end
        local row = pickEquipmentProduct(res.products)
        if not row then return end
        if not row.canCraft then
            return notify('Trūksta ingredientų.', 'error')
        end
        runEquipmentCraftFlow(row.id, equipmentId)
    end, equipmentId)
end

local function targetIconFor(id)
    local e = EquipmentMeta[id]
    local t = e and typeCfg(e.itemType)
    local key = t and t.icon
    return TARGET_ICONS[key] or 'fas fa-flask'
end

local function refreshTargets()
    local playerData = QBCore.Functions.GetPlayerData()
    local citizenid = playerData and playerData.citizenid
    for id, obj in pairs(EquipmentProps) do
        if obj and DoesEntityExist(obj) then
            local meta = EquipmentMeta[id]
            local t = meta and typeCfg(meta.itemType)
            local isOwner = meta and not meta.fixed and citizenid and meta.citizenid == citizenid
            local canUse = meta and (meta.fixed or not (t and t.ownerOnly) or isOwner)
            local options = {}
            if canUse then
                if meta.itemType == 'bagging_table' and not meta.fixed then
                    -- Atskiri pasirinkimai neleidžia automatiniam recepto parinkimui paleisti seno režimo.
                    options[#options + 1] = {
                        icon = 'fas fa-seedling',
                        label = 'Džiovinti žolę',
                        action = function()
                            runEquipmentCraftFlow('weed_process', id)
                        end,
                    }
                    options[#options + 1] = {
                        icon = 'fas fa-bag-shopping',
                        label = 'Pakuoti žolę',
                        action = function()
                            -- weed_pack paleidžia naujausią fiksuotos kameros 3D režimą po vieną maišelį.
                            runEquipmentCraftFlow('weed_pack', id)
                        end,
                    }
                else
                    options[#options + 1] = {
                        icon = targetIconFor(id),
                        label = (meta and meta.label) or 'Gaminti',
                        action = function()
                            useEquipmentDirect(id)
                        end,
                    }
                end
            end
            if isOwner then
                options[#options + 1] = {
                    icon = 'fas fa-box',
                    label = 'Surinkti įrangą',
                    action = function()
                        TriggerServerEvent('mrp_drugs:server:pickupEquipment', id)
                    end,
                }
            end
            exports['qb-target']:RemoveTargetEntity(obj)
            if #options > 0 then
                exports['qb-target']:AddTargetEntity(obj, {
                    options = options,
                    distance = cfg().interactDist or 2.5,
                })
            end
        end
    end
end

RegisterNetEvent('mrp_drugs:client:syncEquipment', function(list)
    for id in pairs(EquipmentProps) do
        deleteProp(id)
    end
    for _, e in ipairs(list or {}) do
        spawnEquipment(e)
    end
    Wait(200)
    refreshTargets()
end)

RegisterNetEvent('mrp_drugs:client:updateEquipmentState', function(state)
    local id = state and tonumber(state.id)
    local meta = id and EquipmentMeta[id]
    if not meta then return end
    meta.busy = state.busy == true
    meta.remainingMs = math.max(0, tonumber(state.remainingMs) or 0)
    meta.expiresAt = GetGameTimer() + meta.remainingMs
end)

RegisterNetEvent('mrp_drugs:client:removeEquipment', function(equipmentId)
    deleteProp(tonumber(equipmentId))
end)

RegisterNetEvent('mrp_drugs:client:startPlaceEquipment', function(itemType)
    if placing or crafting or not cfg().enabled then return end
    local t = typeCfg(itemType)
    if not t then return notify('Nežinoma įranga.', 'error') end
    if not isInsidePlacementZone(t, GetEntityCoords(PlayerPedId())) then
        return notify('Žolės džiovinimo stalą galima padėti tik Cayo Perico saloje.', 'error')
    end
    local model = t.prop or 'prop_tool_bench02'
    if not loadModel(model) then return notify('Prop modelis nerastas: ' .. model, 'error') end

    placing = true
    local ped = PlayerPedId()
    local preview = CreateObject(joaat(model), 0.0, 0.0, 0.0, false, false, false)
    SetEntityAlpha(preview, cfg().placeGhostAlpha or 170, false)
    SetEntityCollision(preview, false, false)
    FreezeEntityPosition(preview, true)
    notify('[E] Padėti · [SCROLL] Sukti · [BACKSPACE] Atšaukti', 'primary')

    CreateThread(function()
        local heading = GetEntityHeading(ped)
        while placing do
            Wait(0)
            local c = GetEntityCoords(ped)
            local fwd = GetEntityForwardVector(ped)
            local pos = c + fwd * (cfg().placeForwardM or 1.35)
            SetEntityCoords(preview, pos.x, pos.y, pos.z, false, false, false, false)
            PlaceObjectOnGroundProperly(preview)
            if IsControlPressed(0, 241) then heading = heading + 1.2 end
            if IsControlPressed(0, 242) then heading = heading - 1.2 end
            SetEntityHeading(preview, heading)

            if IsControlJustPressed(0, 177) then
                placing = false
            elseif IsControlJustPressed(0, 38) then
                local fc = GetEntityCoords(preview)
                local fh = GetEntityHeading(preview)
                if not isInsidePlacementZone(t, fc) then
                    notify('Žolės džiovinimo stalą galima padėti tik Cayo Perico saloje.', 'error')
                else
                    placing = false
                    TriggerServerEvent('mrp_drugs:server:placeEquipment', itemType, fc.x, fc.y, fc.z, fh)
                end
            end
        end
        if DoesEntityExist(preview) then DeleteEntity(preview) end
        SetModelAsNoLongerNeeded(joaat(model))
    end)
end)

local function formatRemainingTime(milliseconds)
    local totalSeconds = math.max(0, math.ceil((tonumber(milliseconds) or 0) / 1000))
    local minutes = math.floor(totalSeconds / 60)
    local seconds = totalSeconds % 60
    return ('%02d:%02d'):format(minutes, seconds)
end

local function drawTableHologram(coords, text)
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    SetTextScale(0.0, 0.32)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(110, 255, 145, 230)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

CreateThread(function()
    while true do
        local sleep = 750
        local playerCoords = GetEntityCoords(PlayerPedId())
        for id, meta in pairs(EquipmentMeta) do
            local t = meta and typeCfg(meta.itemType)
            local entity = EquipmentProps[id]
            if t and tonumber(t.idleTimeoutMs) and not meta.fixed and not meta.busy
                and meta.expiresAt and entity and DoesEntityExist(entity) then
                local entityCoords = GetEntityCoords(entity)
                local drawDistance = tonumber(t.hologramDistance) or 20.0
                if #(playerCoords - entityCoords) <= drawDistance then
                    sleep = 0
                    -- hologramHeight 1.25 = tekstas virš stalo; didesnis skaičius pakelia hologramą.
                    local height = tonumber(t.hologramHeight) or 1.25
                    local remainingMs = math.max(0, meta.expiresAt - GetGameTimer())
                    drawTableHologram(
                        vector3(entityCoords.x, entityCoords.y, entityCoords.z + height),
                        ('STALAS SUBYRĖS PO %s'):format(formatRemainingTime(remainingMs))
                    )
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(EquipmentProps) do
        deleteProp(id)
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('mrp_drugs:server:requestEquipmentSync')
end)

CreateThread(function()
    Wait(3000)
    if LocalPlayer.state.isLoggedIn then
        TriggerServerEvent('mrp_drugs:server:requestEquipmentSync')
    end
end)
