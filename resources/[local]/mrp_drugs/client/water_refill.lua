local QBCore = exports['qb-core']:GetCoreObject()

local refillBusy = false
local drawTextActive = false

local function weedGrowCfg()
    return Config.WeedGrow or {}
end

local function hasWateringCan()
    local itemName = weedGrowCfg().waterCanItem or 'watering_can'
    return QBCore.Functions.HasItem(itemName, 1)
end

local function isNearNaturalWater()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local maxDist = tonumber(weedGrowCfg().waterNaturalMaxDistance) or 4.0

    if IsEntityInWater(ped) or IsPedSwimming(ped) then
        return true
    end

    local found, waterZ = GetWaterHeight(coords.x, coords.y, coords.z)
    if found and math.abs(coords.z - waterZ) <= maxDist then
        return true
    end

    if TestVerticalProbeAgainstAllWater(coords.x, coords.y, coords.z + 0.75, 0, 1) then
        local ok, probeZ = GetWaterHeight(coords.x, coords.y, coords.z)
        if ok and math.abs(coords.z - probeZ) <= maxDist then
            return true
        end
    end

    return false
end

local function setDrawText(active, text)
    if active and not drawTextActive then
        exports['qb-core']:DrawText(text or '[E] Pripildyti laistytuvą', 'left')
        drawTextActive = true
    elseif not active and drawTextActive then
        exports['qb-core']:HideText()
        drawTextActive = false
    end
end

local function startWaterRefill()
    if refillBusy or not hasWateringCan() or not isNearNaturalWater() then return end
    refillBusy = true
    setDrawText(false)

    local cfg = weedGrowCfg()
    local duration = tonumber(cfg.waterNaturalRefillMs) or 6000
    DrugProgress.run(
        'weed_water_refill',
        'Pripildomas laistytuvas…',
        duration,
        false,
        true,
        {
            disableMovement = true,
            disableCarMovement = true,
            disableCombat = true,
        },
        {
            animDict = 'amb@world_human_gardener_plant@male@base',
            anim = 'base',
            flags = 49,
        },
        function()
            refillBusy = false
            if not isNearNaturalWater() then
                return QBCore.Functions.Notify('Per toli nuo vandens.', 'error')
            end
            TriggerServerEvent('mrp_drugs:server:refillWateringCanFromWater')
        end,
        function()
            refillBusy = false
            QBCore.Functions.Notify('Atšaukta.', 'error')
        end
    )
end

CreateThread(function()
    while true do
        local sleep = 1000
        if not refillBusy and hasWateringCan() and isNearNaturalWater() then
            sleep = 0
            setDrawText(true, '[E] Pripildyti laistytuvą')
            if IsControlJustReleased(0, 38) then
                startWaterRefill()
            end
        else
            setDrawText(false)
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    setDrawText(false)
end)
