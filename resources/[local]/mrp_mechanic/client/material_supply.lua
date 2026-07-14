local QBCore = exports['qb-core']:GetCoreObject()

local supplyPed = nil

local function isMechanicOnDuty()
    local P = QBCore.Functions.GetPlayerData()
    return P.job and P.job.name == Config.JobName and P.job.onduty == true
end

local function loadModel(hash)
    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(10) end
end

local function openMaterialSellMenu()
    QBCore.Functions.TriggerCallback('mrp_mechanic:server:getMaterialSellList', function(res)
        if not res or not res.ok then
            return QBCore.Functions.Notify(res and res.message or 'Klaida.', 'error')
        end
        local rows = {
            { header = 'Parduoti mechanikams', txt = 'Žaliavų priėmimo punktas', isMenuHeader = true },
        }
        for _, row in ipairs(res.items or {}) do
            rows[#rows + 1] = {
                header = ('%s x%s'):format(row.label, row.count),
                txt = ('$%s / vnt. · iš viso $%s'):format(row.price, row.total),
                params = {
                    isAction = true,
                    event = function()
                        local input = exports['qb-input']:ShowInput({
                            header = row.label,
                            submitText = 'Parduoti',
                            inputs = {
                                { text = ('Kiekis (1-%s)'):format(row.count), name = 'amount', type = 'number', isRequired = true },
                            },
                        })
                        if not input or not input.amount then return end
                        TriggerServerEvent('mrp_mechanic:server:sellMaterialToSupply', row.item, tonumber(input.amount) or 1)
                    end,
                },
            }
        end
        if #(res.items or {}) == 0 then
            rows[#rows + 1] = { header = 'Tuščia', txt = 'Neturi mechanikams tinkamų žaliavų', isMenuHeader = true }
        else
            rows[#rows + 1] = {
                header = 'Parduoti viską',
                txt = ('Iš viso $%s'):format(res.grandTotal or 0),
                params = {
                    isAction = true,
                    event = function()
                        TriggerServerEvent('mrp_mechanic:server:sellAllMaterialsToSupply')
                    end,
                },
            }
        end
        TriggerEvent('qb-menu:client:openMenu', rows, false, true)
    end)
end

local function openMaterialBuyMenu()
    if not isMechanicOnDuty() then
        return QBCore.Functions.Notify('Tik mechanikams tarnyboje.', 'error')
    end
    QBCore.Functions.TriggerCallback('mrp_mechanic:server:getMaterialBuyList', function(res)
        if not res or not res.ok then
            return QBCore.Functions.Notify(res and res.message or 'Klaida.', 'error')
        end
        local rows = {
            { header = 'Mechanikų žaliavų sandėlis', txt = 'Pirkti iš kasėjų pristatytų atsargų', isMenuHeader = true },
        }
        for _, row in ipairs(res.items or {}) do
            rows[#rows + 1] = {
                header = ('%s (likutis %s)'):format(row.label, row.stock),
                txt = ('$%s / vnt.'):format(row.price),
                params = {
                    isAction = true,
                    event = function()
                        local input = exports['qb-input']:ShowInput({
                            header = row.label,
                            submitText = 'Pirkti',
                            inputs = {
                                { text = ('Kiekis (1-%s)'):format(row.stock), name = 'amount', type = 'number', isRequired = true },
                            },
                        })
                        if not input or not input.amount then return end
                        TriggerServerEvent('mrp_mechanic:server:buyMaterialFromSupply', row.item, tonumber(input.amount) or 1)
                    end,
                },
            }
        end
        if #(res.items or {}) == 0 then
            rows[#rows + 1] = { header = 'Sandėlis tuščias', txt = 'Laukite kol kasėjai pristatys žaliavas', isMenuHeader = true }
        end
        TriggerEvent('qb-menu:client:openMenu', rows, false, true)
    end)
end

RegisterNetEvent('mrp_mechanic:client:openMaterialSellMenu', function()
    openMaterialSellMenu()
end)

RegisterNetEvent('mrp_mechanic:client:openMaterialBuyMenu', function()
    openMaterialBuyMenu()
end)

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do Wait(300) end

    local cfg = Config.MaterialSupply
    if not cfg or not cfg.coords then return end

    if cfg.ped and cfg.ped.coords then
        local c = cfg.ped.coords
        loadModel(cfg.ped.model)
        supplyPed = CreatePed(4, cfg.ped.model, c.x, c.y, c.z - 1.0, c.w, false, true)
        SetEntityAsMissionEntity(supplyPed, true, true)
        SetBlockingOfNonTemporaryEvents(supplyPed, true)
        FreezeEntityPosition(supplyPed, true)
        SetEntityInvincible(supplyPed, true)
        if cfg.ped.scenario then
            TaskStartScenarioInPlace(supplyPed, cfg.ped.scenario, 0, true)
        end

        exports['qb-target']:AddTargetEntity(supplyPed, {
            options = {
                {
                    type = 'client',
                    event = 'mrp_mechanic:client:openMaterialSellMenu',
                    icon = 'fas fa-hand-holding-dollar',
                    label = 'Parduoti žaliavas mechanikams',
                },
                {
                    type = 'client',
                    event = 'mrp_mechanic:client:openMaterialBuyMenu',
                    icon = 'fas fa-boxes-stacked',
                    label = 'Pirkti žaliavas (mechanikas)',
                    canInteract = function()
                        return isMechanicOnDuty()
                    end,
                },
            },
            distance = 2.5,
        })
    else
        exports['qb-target']:AddBoxZone('mrp_mech_material_supply', cfg.coords, cfg.length or 2.0, cfg.width or 2.2, {
            name = 'mrp_mech_material_supply',
            heading = cfg.heading or 0.0,
            debugPoly = false,
            minZ = cfg.coords.z - 1.1,
            maxZ = cfg.coords.z + 2.2,
        }, {
            options = {
                {
                    type = 'client',
                    event = 'mrp_mechanic:client:openMaterialSellMenu',
                    icon = 'fas fa-hand-holding-dollar',
                    label = cfg.label or 'Parduoti žaliavas mechanikams',
                },
                {
                    type = 'client',
                    event = 'mrp_mechanic:client:openMaterialBuyMenu',
                    icon = 'fas fa-boxes-stacked',
                    label = 'Pirkti žaliavas (mechanikas)',
                    canInteract = function()
                        return isMechanicOnDuty()
                    end,
                },
            },
            distance = 2.5,
        })
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if supplyPed and DoesEntityExist(supplyPed) then DeleteEntity(supplyPed) end
end)
