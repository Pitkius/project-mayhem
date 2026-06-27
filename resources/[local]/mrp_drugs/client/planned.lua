--- Planuojamos vietos — dev žymėjimas žemėlapyje (kol nėra pilnos logikos)

local plannedBlips = {}

local function clearPlannedBlips()
    for _, blip in ipairs(plannedBlips) do
        if blip and DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    plannedBlips = {}
end

local function setupPlannedBlips()
    clearPlannedBlips()

    for siteId, site in pairs(Config.PlannedSites or {}) do
        if site.showBlip ~= false and site.coords then
            local c = site.coords
            local blipCfg = site.blip or {}
            local blip = AddBlipForCoord(c.x, c.y, c.z)
            SetBlipSprite(blip, blipCfg.sprite or 1)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, blipCfg.scale or 0.75)
            SetBlipColour(blip, blipCfg.color or 0)
            SetBlipAsShortRange(blip, blipCfg.shortRange ~= false)
            local label = blipCfg.label or site.label or ('Planuojama: ' .. siteId)
            if GetResourceState('mrp_fonts') == 'started' then
                exports['mrp_fonts']:SetBlipName(blip, label)
            else
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentString(label)
                EndTextCommandSetBlipName(blip)
            end
            plannedBlips[#plannedBlips + 1] = blip
        end
    end
end

CreateThread(function()
    Wait(1500)
    setupPlannedBlips()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    clearPlannedBlips()
end)
