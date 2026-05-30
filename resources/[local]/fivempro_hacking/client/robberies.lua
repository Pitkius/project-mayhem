local QBCore = exports['qb-core']:GetCoreObject()

local session = nil

local function resetSession()
    if session and exports['fivempro_hacking']:IsCasinoHeist(session.tierId) then
        exports['fivempro_hacking']:CleanupCasinoHeist()
    end
    if session then
        TriggerServerEvent('fivempro_hacking:server:robberyRelease', session.tierId, session.locId)
    end
    session = nil
end

local function flowFor(tierId)
    return (Config.Robberies.Flow or {})[tierId] or {}
end

local function nextPhase()
    if not session then return nil end
    session.flowIndex = (session.flowIndex or 1) + 1
    return session.flow[session.flowIndex]
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

local function bumpCasinoLootIndex()
    if not session or not exports['fivempro_hacking']:IsCasinoHeist(session.tierId) then return nil end
    session.casinoLootIndex = (session.casinoLootIndex or 0) + 1
    return session.casinoLootIndex
end

local function playHackSound(name)
    PlaySoundFrontend(-1, name or 'Pin_Good', 'DLC_HEIST_BIOLAB_PREP_HACKING_SOUNDS', true)
end

local function playDrillSound(name)
    PlaySoundFrontend(-1, name or 'Drill', 'DLC_HEIST_FLEECA_BANK_DRILLING_SOUNDS', true)
end

local function runHackPhase()
    if not session then return end
    playHackSound('Background')
    exports['fivempro_hacking']:StartHack(session.tierId, session.coords, function(ok)
        if not session then return end
        if ok then
            playHackSound('Hack_Success')
        else
            playHackSound('Hack_Failed')
        end
        if not ok then
            failRobbery('Hack nepavyko.')
            return
        end
        TriggerServerEvent('fivempro_hacking:server:robberyPhaseDone', session.tierId, session.locId, 'hack')
    end, session.locId)
end

local function playBankDoorOpen(coords)
    QBCore.Functions.Notify('Banko durys atrakintos — gręžk seifo vartus.', 'success')
    PlaySoundFromCoord(-1, 'Vault_Unlock', coords.x, coords.y, coords.z, 'dlc_heist_fleeca_bank_door_sounds', false, 0, false)
    if session and session.locId then
        exports['fivempro_hacking']:OpenBankVaultAfterHack(session.locId, coords)
    end
end

local function playVaultGateOpen(coords)
    QBCore.Functions.Notify('Seifo vartai atidaryti — grabink pinigus.', 'success')
    PlaySoundFromCoord(-1, 'Drill_Pin_Break', coords.x, coords.y, coords.z, 'DLC_HEIST_FLEECA_BANK_DRILLING_SOUNDS', false, 0, false)
    if session and session.locId then
        exports['fivempro_hacking']:OpenBankVaultAfterDrill(session.locId, coords)
    end
end

local function runPhase(phase)
    if not session then return end
    session.phase = phase

    if phase == 'hack' then
        return runHackPhase()
    end

    local isCasino = exports['fivempro_hacking']:IsCasinoHeist(session.tierId)
    local lootIdx = nil

    if isCasino and phase ~= 'hack' then
        lootIdx = (phase == 'loot') and bumpCasinoLootIndex() or nil
        if not exports['fivempro_hacking']:WaitAtCasinoPhase(phase, lootIdx) then
            return failRobbery('Nepavyko pasiekti tikslo.')
        end
        local def = exports['fivempro_hacking']:GetCasinoPhaseDef(phase, lootIdx)
        if def and def.coords then
            session.coords = def.coords
        end
    end

    if phase == 'card' or phase == 'thermite' or phase == 'drill' or phase == 'loot' then
        local ok
        if isCasino and phase == 'loot' then
            ok = exports['fivempro_hacking']:RunCasinoTrolleyLoot(session.coords, lootIdx or 1)
        elseif isCasino then
            ok = exports['fivempro_hacking']:RunCasinoPhysical(phase)
        else
            ok = runPhysicalPhase(phase)
        end
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
            flowIndex = 1,
            phase = nil,
            casinoLootIndex = 0,
        }
        TriggerServerEvent('fivempro_hacking:server:robberyClaim', tierId, loc.id)
        QBCore.Functions.Notify(('Pradedamas: %s'):format(loc.label), 'primary')
        if exports['fivempro_hacking']:IsCasinoHeist(tierId) then
            exports['fivempro_hacking']:CasinoHeistIntro()
        end
        runPhase(session.flow[session.flowIndex])
    end, tierId, loc.id)
end

RegisterNetEvent('fivempro_hacking:client:robberyNextPhase', function(tierId, locId, completedPhase)
    if not session or session.tierId ~= tierId or session.locId ~= locId then return end
    local bankTiers = { bank_fleeca = true, bank_main = true, vault = true }
    if completedPhase == 'hack' and bankTiers[tierId] then
        playBankDoorOpen(session.coords)
    elseif completedPhase == 'drill' and bankTiers[tierId] then
        playVaultGateOpen(session.coords)
    elseif exports['fivempro_hacking']:IsCasinoHeist(tierId) then
        local lootIdx = (completedPhase == 'loot') and session.casinoLootIndex or nil
        exports['fivempro_hacking']:OnCasinoPhaseComplete(completedPhase, lootIdx, session.coords)
    end
    local nxt = nextPhase()
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
    casino = 'Diamond Casino Heist',
    vault = 'Federal vault',
}

function IsRobberySessionActive()
    return session ~= nil
end

exports('IsRobberySessionActive', IsRobberySessionActive)

local robberyInteract = {}

CreateThread(function()
    while true do
        Wait(3000)
        local locations = Config.Robberies and Config.Robberies.Locations or {}
        for tierId in pairs(locations) do
            QBCore.Functions.TriggerCallback('fivempro_hacking:server:robberyCanInteract', function(ok)
                robberyInteract[tierId] = ok == true
            end, tierId)
        end
    end
end)

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
                            return not session and robberyInteract[tierId] == true
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
