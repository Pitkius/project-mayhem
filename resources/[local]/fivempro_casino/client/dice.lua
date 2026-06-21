local QBCore = exports['qb-core']:GetCoreObject()

local activeRolls = {}

local function headCoordsForPlayer(serverId)
    local player = GetPlayerFromServerId(serverId)
    if player == -1 then return nil end
    local ped = GetPlayerPed(player)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    return GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.55)
end

local function playDiceAnim(ped)
    local dict = 'anim@mp_player_intcelebrationmale@wank'
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < timeout do Wait(10) end
    if HasAnimDictLoaded(dict) then
        TaskPlayAnim(ped, dict, 'wank', 8.0, -8.0, 1200, 49, 0, false, false, false)
    end
end

RegisterNetEvent('fivempro_casino:client:showDiceRoll', function(serverId, rolls, sides, total)
    activeRolls[serverId] = {
        started = GetGameTimer(),
        rolls = rolls,
        sides = sides,
        total = total,
        done = false,
    }

    if serverId == GetPlayerServerId(PlayerId()) then
        playDiceAnim(PlayerPedId())
    end
end)

CreateThread(function()
    while true do
        local sleep = 500
        local now = GetGameTimer()
        local cfg = Config.Dice or {}

        for serverId, roll in pairs(activeRolls) do
            local coords = headCoordsForPlayer(serverId)
            if coords then
                sleep = 0
                local elapsed = now - roll.started
                local animMs = cfg.animMs or 1800
                local displayMs = cfg.displayMs or 4500

                if elapsed < animMs then
                    local fake = math.random(1, roll.sides or 6)
                    Casino.drawText3D(coords, ('🎲 %s'):format(fake), 0.48)
                elseif elapsed < displayMs then
                    local parts = {}
                    for _, v in ipairs(roll.rolls or {}) do parts[#parts + 1] = tostring(v) end
                    local text
                    if #(roll.rolls or {}) > 1 then
                        text = ('🎲 %s = %s'):format(table.concat(parts, '+'), roll.total or 0)
                    else
                        text = ('🎲 %s'):format(parts[1] or '?')
                    end
                    Casino.drawText3D(coords, text, 0.48)
                else
                    activeRolls[serverId] = nil
                end
            else
                if now - roll.started > ((cfg.displayMs or 4500) + 500) then
                    activeRolls[serverId] = nil
                end
            end
        end

        Wait(sleep)
    end
end)

local function parseDiceArgs(args)
    local cfg = Config.Dice or {}
    local a = tonumber(args[1])
    local b = tonumber(args[2])
    local count = 1
    local sides = cfg.defaultSides or 6

    if a and not b then
        if a <= (cfg.maxDice or 3) then
            count = math.floor(a)
        else
            sides = math.floor(a)
        end
    elseif a and b then
        count = math.floor(a)
        sides = math.floor(b)
    end

    count = math.max(1, math.min(count, cfg.maxDice or 3))
    sides = math.max(2, math.min(sides, cfg.maxSides or 20))
    return count, sides
end

RegisterCommand(Config.Dice and Config.Dice.command or 'dice', function(_, args)
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        QBCore.Functions.Notify('Negalima transporte.', 'error')
        return
    end
    local count, sides = parseDiceArgs(args or {})
    TriggerServerEvent('fivempro_casino:server:rollDice', count, sides)
end, false)

TriggerEvent('chat:addSuggestion', '/' .. (Config.Dice and Config.Dice.command or 'dice'), 'Mesti kauliuką', {
    { name = 'kiekis', help = 'Kauliukų sk. (1-3)' },
    { name = 'šonai', help = 'Kauliuko šonų sk. (2-20)' },
})
