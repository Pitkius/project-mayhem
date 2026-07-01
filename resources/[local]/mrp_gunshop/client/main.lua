local QBCore = exports['qb-core']:GetCoreObject()

local spawnedPeds = {}
local blips = {}

local function loadModel(model)
    if type(model) == 'string' then model = joaat(model) end
    if not IsModelInCdimage(model) then return false end
    RequestModel(model)
    local t = 0
    while not HasModelLoaded(model) and t < 100 do
        Wait(10)
        t = t + 1
    end
    return HasModelLoaded(model)
end

local function createBlip(coords, cfg)
    if not coords or not cfg then return end
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, cfg.sprite or 110)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, cfg.scale or 0.85)
    SetBlipColour(blip, cfg.colour or cfg.color or 1)
    SetBlipAsShortRange(blip, true)
    local label = cfg.label or 'Ginklų parduotuvė'
    if GetResourceState('mrp_fonts') == 'started' then
        pcall(function()
            exports['mrp_fonts']:SetBlipName(blip, label)
        end)
    else
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(label)
        EndTextCommandSetBlipName(blip)
    end
    blips[#blips + 1] = blip
end

local function spawnShopPed(loc)
    local key = loc.id or tostring(#spawnedPeds + 1)
    if spawnedPeds[key] and DoesEntityExist(spawnedPeds[key]) then return spawnedPeds[key] end
    local model = Config.PedModel or 's_m_y_ammucity_01'
    if not loadModel(model) then return nil end
    local c = loc.coords
    local ped = CreatePed(0, model, c.x, c.y, c.z - 1.0, c.w, false, false)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    if Config.PedScenario then
        TaskStartScenarioInPlace(ped, Config.PedScenario, 0, true)
    end
    SetModelAsNoLongerNeeded(joaat(model))
    spawnedPeds[key] = ped

    exports['qb-target']:AddTargetEntity(ped, {
        options = {
            {
                type = 'server',
                event = 'mrp_gunshop:server:openShop',
                icon = 'fas fa-gun',
                label = 'Ginklų parduotuvė',
            },
        },
        distance = 2.5,
    })

    return ped
end

CreateThread(function()
    Wait(1500)
    for _, loc in ipairs(Config.Locations or {}) do
        if loc.blip ~= false then
            createBlip(loc.coords, Config.Blip)
        end
        spawnShopPed(loc)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, ped in pairs(spawnedPeds) do
        if ped and DoesEntityExist(ped) then
            DeleteEntity(ped)
        end
    end
    for _, blip in ipairs(blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
end)
