--[[
  Client: civilio įvadinė Dark Net misija.
  Reaguoja į serverio būseną (intro_state). Kiekvienas žingsnis patvirtinamas serveryje.

    1 → kontakto NPC + blipas (pasikalbėti)
    2 → paimti siuntą (zona + propas)
    3 → pristatyti siuntą (zona + propas)
    4 → baigta (nieko nerodom)
]]

local QBCore = exports['qb-core']:GetCoreObject()

local introState = 0
local ents = {}   -- laikini objektai/blipai/zonos

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 5000 do Wait(10); t = t + 10 end
    return HasModelLoaded(hash)
end

local function clearEnts()
    for _, e in ipairs(ents) do
        if e.zone then pcall(function() exports['qb-target']:RemoveZone(e.zone) end) end
        if e.entity and DoesEntityExist(e.entity) then
            pcall(function() exports['qb-target']:RemoveTargetEntity(e.entity) end)
            DeleteEntity(e.entity)
        end
        if e.blip then RemoveBlip(e.blip) end
        if e.radiusBlip then RemoveBlip(e.radiusBlip) end
    end
    ents = {}
end

local function addBlip(coords, sprite, color, scale, label, shortRange)
    local b = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(b, sprite or 480)
    SetBlipColour(b, color or 5)
    SetBlipScale(b, scale or 0.85)
    SetBlipAsShortRange(b, shortRange == true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label or 'Kontaktas')
    EndTextCommandSetBlipName(b)
    return b
end

local function addRadiusBlip(coords, radius)
    local b = AddBlipForRadius(coords.x, coords.y, coords.z, radius)
    SetBlipColour(b, 5)
    SetBlipAlpha(b, 90)
    return b
end

-- Kontakto NPC
local function spawnContact()
    local cfg = Config.IntroMission.contactNpc
    if not loadModel(cfg.model) then return end
    local c = cfg.coords
    local ped = CreatePed(4, joaat(cfg.model), c.x, c.y, c.z - 1.0, c.w or 0.0, false, true)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    if cfg.scenario then TaskStartScenarioInPlace(ped, cfg.scenario, 0, true) end
    SetModelAsNoLongerNeeded(joaat(cfg.model))

    local rec = { entity = ped }
    if cfg.blip and cfg.blip.enabled ~= false then
        rec.blip = addBlip(c, cfg.blip.sprite, cfg.blip.color, cfg.blip.scale, cfg.blip.label or cfg.label)
    end
    ents[#ents + 1] = rec

    if GetResourceState('qb-target') == 'started' then
        exports['qb-target']:AddTargetEntity(ped, {
            options = {
                {
                    icon = 'fas fa-user-secret',
                    label = 'Pasikalbėti',
                    action = function()
                        QBCore.Functions.TriggerCallback('mrp_drugs:server:introMeetContact', function(res)
                            if res and res.ok then
                                QBCore.Functions.Notify('Paimk siuntą pažymėtoje vietoje.', 'primary', 7000)
                            else
                                QBCore.Functions.Notify((res and res.reason) or 'Ne dabar.', 'error')
                            end
                        end)
                    end,
                },
            },
            distance = 2.5,
        })
    end
end

-- Siuntos propas (pickup arba delivery)
local function spawnPackage(stepCfg, callbackName, doneMsg)
    if not loadModel(stepCfg.prop or 'prop_cs_package_01') then return end
    local c = stepCfg.coords
    local z = c.z
    local found, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z + 2.0, false)
    if found then z = gz end
    local ent = CreateObject(joaat(stepCfg.prop or 'prop_cs_package_01'), c.x, c.y, z, false, false, false)
    PlaceObjectOnGroundProperly(ent)
    FreezeEntityPosition(ent, true)
    SetModelAsNoLongerNeeded(joaat(stepCfg.prop or 'prop_cs_package_01'))

    local rec = { entity = ent }
    if stepCfg.radius and stepCfg.radius > 0 then
        rec.radiusBlip = addRadiusBlip(c, stepCfg.radius)
    end
    rec.blip = addBlip(c, 480, 5, 0.8, stepCfg.label or 'Siunta', true)
    ents[#ents + 1] = rec

    if GetResourceState('qb-target') == 'started' then
        exports['qb-target']:AddTargetEntity(ent, {
            options = {
                {
                    icon = 'fas fa-box',
                    label = stepCfg.label or 'Siunta',
                    action = function()
                        local dur = tonumber(stepCfg.durationMs) or 5000
                        local function finish()
                            QBCore.Functions.TriggerCallback(callbackName, function(res)
                                if res and res.ok then
                                    QBCore.Functions.Notify(doneMsg, 'success', 7000)
                                else
                                    QBCore.Functions.Notify((res and res.reason) or 'Nepavyko.', 'error')
                                end
                            end)
                        end
                        if DrugProgress and DrugProgress.run then
                            DrugProgress.run('mrp_intro', stepCfg.label or 'Siunta', dur, false, true, {
                                disableMovement = true, disableCarMovement = true, disableCombat = true,
                            }, nil, finish, nil)
                        else
                            finish()
                        end
                    end,
                },
            },
            distance = (stepCfg.pickDistance or 2.5) + 0.5,
        })
    end
end

local function refresh()
    clearEnts()
    if not (Config.IntroMission and Config.IntroMission.enabled) then return end
    if introState == 1 then
        spawnContact()
    elseif introState == 2 then
        spawnPackage(Config.IntroMission.packagePickup, 'mrp_drugs:server:introPickup', 'Pristatyk siuntą į pažymėtą vietą.')
    elseif introState == 3 then
        spawnPackage(Config.IntroMission.delivery, 'mrp_drugs:server:introDeliver', 'Prieiga suteikta. Patikrink telefoną.')
    end
end

RegisterNetEvent('mrp_drugs:client:playerStateSync', function(state)
    if type(state) ~= 'table' then return end
    local newState = tonumber(state.introState) or 0
    if newState ~= introState then
        introState = newState
        refresh()
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearEnts()
end)
