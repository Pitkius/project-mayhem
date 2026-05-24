local QBCore = exports['qb-core']:GetCoreObject()

local session = nil

local function resetSession()
    if session then
        TriggerServerEvent('fivempro_hacking:server:robberyRelease', session.tierId, session.locId)
    end
    session = nil
end

local function flowFor(tierId)
    return (Config.Robberies.Flow or {})[tierId] or {}
end

local function phaseIndex(phase)
    if not session then return nil end
    for i, p in ipairs(session.flow) do
        if p == phase then return i end
    end
    return nil
end

local function nextPhase(afterPhase)
    if not session then return nil end
    local idx = phaseIndex(afterPhase)
    if not idx then return nil end
    return session.flow[idx + 1]
end

local function failRobbery(msg)
    QBCore.Functions.Notify(msg or 'Veiksmas nepavyko.', 'error')
    TriggerServerEvent('fivempro_hacking:server:robberyFailed', session.tierId, session.locId)
    resetSession()
end

local function runPhysicalPhase(phase)
    local mg = (Config.RobberyMinigames or {})[phase]
    local anim = (Config.RobberyAnims or {})[phase]
    if not mg then return false end
    local ok = exports['fivempro_hacking']:RunPhysicalMinigame(mg.mode, {
        label = mg.label,
        anim = anim,
        data = mg.data or {},
    })
    return ok
end

local function runHackPhase()
    if not session then return end
    exports['fivempro_hacking']:StartHack(session.tierId, session.coords, function(ok)
        if not session then return end
        if not ok then
            failRobbery('Hack nepavyko.')
            return
        end
        TriggerServerEvent('fivempro_hacking:server:robberyPhaseDone', session.tierId, session.locId, 'hack')
    end)
end

local function runPhase(phase)
    if not session then return end
    session.phase = phase

    if phase == 'hack' then
        return runHackPhase()
    end

    if phase == 'card' or phase == 'thermite' or phase == 'drill' or phase == 'loot' then
        local ok = runPhysicalPhase(phase)
        if not session then return end
        if ok then
            TriggerServerEvent('fivempro_hacking:server:robberyPhaseDone', session.tierId, session.locId, phase)
        else
            failRobbery('Atšaukta arba nepavyko.')
        end
        return
    end
end

local function startRobbery(tierId, loc)
    if session then
        return QBCore.Functions.Notify('Jau vyksta apiplėšimas.', 'error')
    end
    QBCore.Functions.TriggerCallback('fivempro_hacking:server:robberyCanStart', function(res)
        if not res or not res.ok then
            return QBCore.Functions.Notify((res and res.msg) or 'Negalima.', 'error')
        end
        session = {
            tierId = tierId,
            locId = loc.id,
            label = loc.label,
            coords = loc.coords,
            flow = res.flow or flowFor(tierId),
            phase = nil,
        }
        TriggerServerEvent('fivempro_hacking:server:robberyClaim', tierId, loc.id)
        QBCore.Functions.Notify(('Pradedamas: %s'):format(loc.label), 'primary')
        runPhase(session.flow[1])
    end, tierId, loc.id)
end

RegisterNetEvent('fivempro_hacking:client:robberyNextPhase', function(tierId, locId, completedPhase)
    if not session or session.tierId ~= tierId or session.locId ~= locId then return end
    local nxt = nextPhase(completedPhase)
    if not nxt then
        resetSession()
        return
    end
    runPhase(nxt)
end)

RegisterNetEvent('fivempro_hacking:client:robberyFinished', function()
    resetSession()
end)

RegisterNetEvent('fivempro_hacking:client:robberyAbort', function()
    resetSession()
end)

local tierLabels = {
    store = 'Apiplėšti kasą',
    bank_fleeca = 'Fleeca vault hack',
    bank_main = 'Pacific vault',
    casino = 'Kazino hack',
    vault = 'Federal vault',
}

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do Wait(500) end
    local locations = Config.Robberies and Config.Robberies.Locations or {}
    for tierId, list in pairs(locations) do
        for _, loc in ipairs(list) do
            local zoneName = ('hack_rob_%s_%s'):format(tierId, loc.id)
            exports['qb-target']:AddCircleZone(zoneName, loc.coords, loc.radius or 1.6, {
                name = zoneName,
                debugPoly = false,
                useZ = true,
            }, {
                options = {
                    {
                        icon = 'fas fa-mask',
                        label = tierLabels[tierId] or ('Apiplėšimas: ' .. tierId),
                        canInteract = function()
                            return not session
                        end,
                        action = function()
                            startRobbery(tierId, loc)
                        end,
                    },
                },
                distance = 2.0,
            })
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    resetSession()
end)
