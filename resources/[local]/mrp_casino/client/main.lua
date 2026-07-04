local QBCore = exports['qb-core']:GetCoreObject()

Casino = Casino or {}
Casino.banned = false
Casino.bannedUntil = ''

local function notify(msg, ntype)
    QBCore.Functions.Notify(msg, ntype or 'primary')
end

function Casino.isBanned()
    return Casino.banned == true
end

function Casino.isInside()
    local casino = Config.Casino or {}
    local center = casino.center
    if not center then return false end
    local coords = GetEntityCoords(PlayerPedId())
    return #(coords - center) <= (casino.radius or 90.0)
end

local function drawText3D(coords, text, scale)
    if GetResourceState('mrp_fonts') == 'started' then
        exports['mrp_fonts']:DrawText3D(coords.x, coords.y, coords.z, text, {
            scale = scale or 0.42,
            center = true,
            background = true,
        })
        return
    end
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    SetTextScale(scale or 0.42, scale or 0.42)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 230)
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

Casino.drawText3D = drawText3D

local function promptBet(title)
    if GetResourceState('qb-input') ~= 'started' then
        notify('qb-input neįkeltas.', 'error')
        return nil
    end
    local lim = Config.Limits or {}
    local r = exports['qb-input']:ShowInput({
        header = title or 'Statymas žetonais',
        submitText = 'Statyti',
        inputs = {
            {
                text = ('Žetonai (%s - %s)'):format(lim.minBet or 50, lim.maxBet or 50000),
                name = 'bet',
                type = 'number',
                isRequired = true,
            },
        },
    })
    if not r or not r.bet then return nil end
    return tonumber(r.bet)
end

Casino.promptBet = promptBet

local function canUseCasino()
    if Casino.isBanned() then
        notify('Pasiekėte dienos laimėjimų limitą. Informacija — kazino kasoje.', 'error')
        return false
    end
    if not Casino.isInside() then
        notify('Turite būti kazino.', 'error')
        return false
    end
    return true
end

Casino.canUseCasino = canUseCasino

local function ejectFromCasino()
    local exterior
    local exits = Config.CasinoExits or {}
    if exits[1] and exits[1].exterior then
        exterior = exits[1].exterior
    else
        local blip = Config.Casino and Config.Casino.blip and Config.Casino.blip.coords
        exterior = blip and vector4(blip.x, blip.y, blip.z, 328.0) or vector4(924.78, 46.85, 81.11, 328.0)
    end
    local ped = PlayerPedId()
    SetEntityCoords(ped, exterior.x, exterior.y, exterior.z, false, false, false, false)
    SetEntityHeading(ped, exterior.w or 0.0)
    notify('Pasiekėte dienos limitą — negalite lošti iki rytojaus.', 'error')
end

RegisterNetEvent('mrp_casino:client:casinoBanned', function(untilDay)
    Casino.banned = true
    Casino.bannedUntil = untilDay or ''
    if Casino.isInside() then
        ejectFromCasino()
    end
end)

local function refreshStatus()
    QBCore.Functions.TriggerCallback('mrp_casino:server:getStatus', function(data)
        if not data then return end
        Casino.banned = data.banned == true
        Casino.bannedUntil = data.bannedUntil or ''
    end)
end

local function setupBlip()
    local blipCfg = Config.Casino and Config.Casino.blip
    if not blipCfg or not blipCfg.coords then return end
    local c = blipCfg.coords
    local blip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(blip, blipCfg.sprite or 679)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, blipCfg.scale or 0.9)
    SetBlipColour(blip, blipCfg.color or 46)
    SetBlipAsShortRange(blip, true)
    if GetResourceState('mrp_fonts') == 'started' then
        pcall(function() exports['mrp_fonts']:SetBlipName(blip, blipCfg.label or 'Casino') end)
    else
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(blipCfg.label or 'Casino')
        EndTextCommandSetBlipName(blip)
    end
end

local function addBoxTarget(id, coords, label, icon, action)
    exports['qb-target']:AddBoxZone(id, coords, 1.4, 1.4, {
        name = id,
        heading = 0.0,
        minZ = coords.z - 1.0,
        maxZ = coords.z + 1.2,
        debugPoly = false,
    }, {
        options = {
            {
                icon = icon,
                label = label,
                canInteract = function()
                    return not Casino.isBanned()
                end,
                action = action,
            },
        },
        distance = 2.2,
    })
end

local function setupTargets()
    if GetResourceState('qb-target') ~= 'started' then return end

    local wheel = Config.Wheel
    if wheel then
        local interact = wheel.movePos or wheel.coords
        if interact then
            addBoxTarget('casino_wheel', interact, 'Laimės ratas (24h)', 'fas fa-dharmachakra', function()
                TriggerEvent('mrp_casino:client:openWheel')
            end)
        end
    end

    for _, tbl in ipairs(Config.BlackjackTables or {}) do
        addBoxTarget('casino_' .. tbl.id, tbl.coords, 'Blackjack', 'fas fa-playing-card', function()
            TriggerEvent('mrp_casino:client:openBlackjack', tbl.id)
        end)
    end

    for _, tbl in ipairs(Config.RouletteTables or {}) do
        addBoxTarget('casino_' .. tbl.id, tbl.coords, 'Ruletė', 'fas fa-circle-notch', function()
            TriggerEvent('mrp_casino:client:openRoulette', tbl.id)
        end)
    end

    for _, machine in ipairs(Config.SlotMachines or {}) do
        addBoxTarget('casino_' .. machine.id, machine.coords, 'Lošimo automatas', 'fas fa-coins', function()
            TriggerEvent('mrp_casino:client:openSlots', machine.id)
        end)
    end
end

CreateThread(function()
    Wait(1500)
    if Casino.loadIpl then Casino.loadIpl() end
    setupBlip()
    while GetResourceState('qb-target') ~= 'started' do Wait(500) end
    setupTargets()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    refreshStatus()
end)

CreateThread(function()
    local wasInside = false
    while true do
        local inside = Casino.isInside()
        if inside ~= wasInside then
            wasInside = inside
            TriggerServerEvent('mrp_casino:server:setPlayerInside', inside)
        end
        Wait(inside and 1500 or 3000)
    end
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    if LocalPlayer.state.isLoggedIn then
        refreshStatus()
        TriggerServerEvent('mrp_casino:server:setPlayerInside', Casino.isInside())
    end
end)

exports('IsCasinoBanned', function()
    return Casino.isBanned()
end)

exports('IsInsideCasino', function()
    return Casino.isInside()
end)
