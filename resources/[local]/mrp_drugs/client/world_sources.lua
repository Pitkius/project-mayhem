--[[
  Client: pasaulio žaliavų NPC (alkoholis, vape, tabletės).
  Aguonų laukas tvarkomas per harvest sistemą (client/mushrooms.lua) ir blipą (client/main.lua).
]]

local QBCore = exports['qb-core']:GetCoreObject()

local peds = {}
local blips = {}

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 5000 do Wait(10); t = t + 10 end
    return HasModelLoaded(hash)
end

local function addBlip(cfg, coords)
    if not cfg or cfg.enabled == false then return end
    local b = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(b, cfg.sprite or 480)
    SetBlipColour(b, cfg.color or 5)
    SetBlipScale(b, cfg.scale or 0.7)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(cfg.label or 'Šaltinis')
    EndTextCommandSetBlipName(b)
    blips[#blips + 1] = b
end

local function doGather(sourceKey)
    local cfg = (Config.WorldSources or {})[sourceKey]
    if not cfg then return end
    local dur = tonumber(cfg.durationMs) or 6000
    local function finish()
        QBCore.Functions.TriggerCallback('mrp_drugs:server:worldGather', function(res)
            if res and res.ok then
                QBCore.Functions.Notify(('Gavai %s× %s'):format(res.amount, res.label or res.item), 'success')
            else
                QBCore.Functions.Notify((res and res.reason) or 'Nepavyko.', 'error')
            end
        end, sourceKey)
    end
    if DrugProgress and DrugProgress.run then
        DrugProgress.run('mrp_world_' .. sourceKey, cfg.actionLabel or 'Renkama…', dur, false, true, {
            disableMovement = true, disableCarMovement = true, disableCombat = true,
        }, nil, finish, nil)
    else
        finish()
    end
end

local function spawnSource(sourceKey)
    local cfg = (Config.WorldSources or {})[sourceKey]
    if not cfg or cfg.enabled == false or not cfg.coords then return end
    if not loadModel(cfg.model) then return end
    local c = cfg.coords
    local ped = CreatePed(4, joaat(cfg.model), c.x, c.y, c.z - 1.0, c.w or 0.0, false, true)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    if cfg.scenario then TaskStartScenarioInPlace(ped, cfg.scenario, 0, true) end
    SetModelAsNoLongerNeeded(joaat(cfg.model))
    peds[#peds + 1] = ped

    addBlip(cfg.blip, c)

    if GetResourceState('qb-target') == 'started' then
        exports['qb-target']:AddTargetEntity(ped, {
            options = {
                {
                    icon = 'fas fa-hand-holding',
                    label = cfg.actionLabel or 'Pasiimti žaliavą',
                    action = function() doGather(sourceKey) end,
                },
            },
            distance = 2.5,
        })
    end
end

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do Wait(300) end
    Wait(1000)
    for _, key in ipairs({ 'alcoholFarmer', 'vapeChemist', 'pillsContact' }) do
        spawnSource(key)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, ped in ipairs(peds) do
        if DoesEntityExist(ped) then
            pcall(function() exports['qb-target']:RemoveTargetEntity(ped) end)
            DeleteEntity(ped)
        end
    end
    for _, b in ipairs(blips) do RemoveBlip(b) end
end)
