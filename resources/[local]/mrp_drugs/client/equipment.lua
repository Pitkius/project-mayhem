--- Client: portable įrangos prop + qb-target. Konfigūracija: config_equipment.lua
local QBCore = exports['qb-core']:GetCoreObject()

local EquipmentProps = {}
local EquipmentMeta = {}
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
    local ent = EquipmentProps[id]
    if ent and DoesEntityExist(ent) then
        exports['qb-target']:RemoveTargetEntity(ent)
        DeleteEntity(ent)
    end
    EquipmentProps[id] = nil
    EquipmentMeta[id] = nil
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
    EquipmentMeta[e.id] = e
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
            }, nil, function(ok)
                if not ok then return afterMinigame(false) end
                local equipment = EquipmentMeta[equipmentId]
                local workspace = equipment and {
                    x = equipment.x,
                    y = equipment.y,
                    z = equipment.z,
                    w = equipment.heading or 0.0,
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
    for id, obj in pairs(EquipmentProps) do
        if obj and DoesEntityExist(obj) then
            local meta = EquipmentMeta[id]
            local options = {
                {
                    icon = targetIconFor(id),
                    label = (meta and meta.label) or 'Gaminti',
                    action = function()
                        useEquipmentDirect(id)
                    end,
                },
            }
            if meta and not meta.fixed then
                options[#options + 1] = {
                    icon = 'fas fa-box',
                    label = 'Surinkti įrangą',
                    action = function()
                        TriggerServerEvent('mrp_drugs:server:pickupEquipment', id)
                    end,
                }
            end
            exports['qb-target']:RemoveTargetEntity(obj)
            exports['qb-target']:AddTargetEntity(obj, {
                options = options,
                distance = cfg().interactDist or 2.5,
            })
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

RegisterNetEvent('mrp_drugs:client:startPlaceEquipment', function(itemType)
    if placing or crafting or not cfg().enabled then return end
    local t = typeCfg(itemType)
    if not t then return notify('Nežinoma įranga.', 'error') end
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
                placing = false
                TriggerServerEvent('mrp_drugs:server:placeEquipment', itemType, fc.x, fc.y, fc.z, fh)
            end
        end
        if DoesEntityExist(preview) then DeleteEntity(preview) end
        SetModelAsNoLongerNeeded(joaat(model))
    end)
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
