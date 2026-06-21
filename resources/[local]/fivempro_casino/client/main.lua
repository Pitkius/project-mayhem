local QBCore = exports['qb-core']:GetCoreObject()

Casino = Casino or {}
Casino.banned = false
Casino.bannedUntil = ''
local cachedStatus = nil

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
    if GetResourceState('fivempro_fonts') == 'started' then
        exports['fivempro_fonts']:DrawText3D(coords.x, coords.y, coords.z, text, {
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

local function loadCasinoIpl()
    if not Config.Casino or Config.Casino.loadVanillaIpl ~= true then return end
    for _, ipl in ipairs({ 'vw_casino_main', 'vw_casino_garage', 'vw_casino_carpark' }) do
        RequestIpl(ipl)
    end
end

local function promptBet(title)
    if GetResourceState('qb-input') ~= 'started' then
        notify('qb-input neįkeltas.', 'error')
        return nil
    end
    local lim = Config.Limits or {}
    local r = exports['qb-input']:ShowInput({
        header = title or 'Statymas',
        submitText = 'Statyti',
        inputs = {
            {
                text = ('Suma ($%s - $%s)'):format(lim.minBet or 50, lim.maxBet or 50000),
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
        notify('Pasiekėte dienos laimėjimų limitą ($50,000). Grįžkite rytoj.', 'error')
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
    local exit = Config.Casino and Config.Casino.exit
    if not exit then return end
    local ped = PlayerPedId()
    SetEntityCoords(ped, exit.x, exit.y, exit.z, false, false, false, false)
    SetEntityHeading(ped, exit.w or 0.0)
    notify('Jūs išvaryti iš kazino iki rytojaus — dienos laimėjimų limitas pasiektas.', 'error')
end

RegisterNetEvent('fivempro_casino:client:casinoBanned', function(untilDay)
    Casino.banned = true
    Casino.bannedUntil = untilDay or ''
    if Casino.isInside() then
        ejectFromCasino()
    end
end)

local function refreshStatus()
    QBCore.Functions.TriggerCallback('fivempro_casino:server:getStatus', function(data)
        if not data then return end
        cachedStatus = data
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
    if GetResourceState('fivempro_fonts') == 'started' then
        pcall(function() exports['fivempro_fonts']:SetBlipName(blip, blipCfg.label or 'Casino') end)
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
    if wheel and wheel.coords then
        addBoxTarget('casino_wheel', wheel.coords, 'Laimės ratas (24h)', 'fas fa-dharmachakra', function()
            TriggerEvent('fivempro_casino:client:openWheel')
        end)
    end

    for _, tbl in ipairs(Config.BlackjackTables or {}) do
        addBoxTarget('casino_' .. tbl.id, tbl.coords, 'Blackjack', 'fas fa-playing-card', function()
            TriggerEvent('fivempro_casino:client:openBlackjack', tbl.id)
        end)
    end

    for _, tbl in ipairs(Config.RouletteTables or {}) do
        addBoxTarget('casino_' .. tbl.id, tbl.coords, 'Ruletė', 'fas fa-circle-notch', function()
            TriggerEvent('fivempro_casino:client:openRoulette', tbl.id)
        end)
    end

    for _, machine in ipairs(Config.SlotMachines or {}) do
        addBoxTarget('casino_' .. machine.id, machine.coords, 'Lošimo automatas', 'fas fa-coins', function()
            TriggerEvent('fivempro_casino:client:openSlots', machine.id)
        end)
    end
end

CreateThread(function()
    Wait(1500)
    loadCasinoIpl()
    setupBlip()
    while GetResourceState('qb-target') ~= 'started' do Wait(500) end
    setupTargets()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    refreshStatus()
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    if LocalPlayer.state.isLoggedIn then refreshStatus() end
end)

-- Limito rodymas kazino zonoje
CreateThread(function()
    while true do
        if Casino.isInside() then
            refreshStatus()
            Wait(8000)
        else
            cachedStatus = nil
            Wait(2000)
        end
    end
end)

CreateThread(function()
    while true do
        local sleep = 1000
        if Casino.isInside() and cachedStatus and not Casino.isBanned() then
            sleep = 0
            local c = GetEntityCoords(PlayerPedId())
            local used = (cachedStatus.maxDailyWin or 50000) - (cachedStatus.remaining or 0)
            drawText3D(vector3(c.x, c.y, c.z + 1.05), ('Kazino limitas: $%s / $%s'):format(used, cachedStatus.maxDailyWin or 50000), 0.30)
        end
        Wait(sleep)
    end
end)

exports('IsCasinoBanned', function()
    return Casino.isBanned()
end)

exports('IsInsideCasino', function()
    return Casino.isInside()
end)
