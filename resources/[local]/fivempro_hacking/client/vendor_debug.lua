local QBCore = exports['qb-core']:GetCoreObject()
local debugPed = nil
local debugBlip = nil

local function vendorCfg()
    return Config.DebugHeistVendor or {}
end

local function createBlip()
    local cfg = vendorCfg()
    if not cfg.enabled or not cfg.coords then return end
    if debugBlip and DoesBlipExist(debugBlip) then return end
    local bl = cfg.Blip or {}
    local c = cfg.coords
    debugBlip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(debugBlip, bl.sprite or 478)
    SetBlipDisplay(debugBlip, 4)
    SetBlipScale(debugBlip, bl.scale or 0.88)
    SetBlipColour(debugBlip, bl.colour or 1)
    SetBlipAsShortRange(debugBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(bl.label or 'TEST: Heist įrankiai')
    EndTextCommandSetBlipName(debugBlip)
end

local function spawnDebugVendor()
    local cfg = vendorCfg()
    if not cfg.enabled then return end
    if debugPed and DoesEntityExist(debugPed) then return end

    createBlip()

    local c = cfg.coords
    local hash = tonumber(cfg.pedModel) or joaat('s_m_y_dealer_01')

    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(10)
    end

    debugPed = CreatePed(0, hash, c.x, c.y, c.z, c.w, false, true)
    SetEntityAsMissionEntity(debugPed, true, true)
    SetBlockingOfNonTemporaryEvents(debugPed, true)
    FreezeEntityPosition(debugPed, true)
    SetEntityInvincible(debugPed, true)
    if cfg.scenario then
        TaskStartScenarioInPlace(debugPed, cfg.scenario, 0, true)
    end

    if GetResourceState('qb-target') ~= 'started' then return end

    exports['qb-target']:AddTargetEntity(debugPed, {
        options = {
            {
                type = 'client',
                event = 'fivempro_hacking:client:debugOpenHeistShop',
                icon = 'fas fa-mask',
                label = 'Heist įrankiai ($1) — shop',
            },
            {
                icon = 'fas fa-shopping-basket',
                label = 'Heist įrankiai ($1) — meniu',
                action = function()
                    local rows = { { header = 'TEST heist itemai ($1)', isMenuHeader = true } }
                    for _, e in ipairs(Config.DebugHeistShopItems or {}) do
                        local it = QBCore.Shared.Items[e.item]
                        if it then
                            rows[#rows + 1] = {
                                header = ('%s — $%s'):format(it.label, e.price or 1),
                                txt = ('Svoris: %sg • %s'):format(it.weight or 0, e.item),
                                params = {
                                    isAction = true,
                                    event = function()
                                        TriggerServerEvent('fivempro_hacking:server:debugBuyHeistItem', e.item)
                                    end,
                                },
                            }
                        end
                    end
                    TriggerEvent('qb-menu:client:openMenu', rows, false, true)
                end,
            },
            {
                icon = 'fas fa-usb-drive',
                label = 'Flashdrive OS / exploit ($1)',
                action = function()
                    local offers = Config.DebugHeistFlashOffers or {}
                    local rows = { { header = 'TEST flashdrive', isMenuHeader = true } }
                    for i, e in ipairs(offers) do
                        local label = QBCore.Shared.Items[e.item] and QBCore.Shared.Items[e.item].label or e.item
                        local extra = ''
                        if e.payload and e.payload.payload_id then
                            extra = ' [' .. tostring(e.payload.payload_id) .. ']'
                        end
                        rows[#rows + 1] = {
                            header = ('%s — $%s%s'):format(label, e.price or 1, extra),
                            params = {
                                isAction = true,
                                event = function()
                                    TriggerServerEvent('fivempro_hacking:server:debugBuyFlashOffer', i)
                                end,
                            },
                        }
                    end
                    TriggerEvent('qb-menu:client:openMenu', rows, false, true)
                end,
            },
        },
        distance = 2.85,
    })
end

RegisterNetEvent('fivempro_hacking:client:debugOpenHeistShop', function()
    TriggerServerEvent('fivempro_hacking:server:debugOpenHeistShop')
end)

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do
        Wait(350)
    end
    Wait(1200)
    spawnDebugVendor()
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if debugPed and DoesEntityExist(debugPed) then
        DeleteEntity(debugPed)
    end
    if debugBlip and DoesBlipExist(debugBlip) then
        RemoveBlip(debugBlip)
    end
end)
