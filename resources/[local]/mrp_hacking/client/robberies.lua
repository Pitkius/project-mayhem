local QBCore = exports['qb-core']:GetCoreObject()

local session = nil
local discoveredLocs = {}

local function locKey(tierId, locId)
    return ('%s:%s'):format(tostring(tierId), tostring(locId))
end

local function discoveryRequired(tierId)
    return Config.RobberyDiscoveryTiers and Config.RobberyDiscoveryTiers[tierId] == true
end

local function isLocDiscovered(tierId, locId)
    if not discoveryRequired(tierId) then return true end
    return discoveredLocs[locKey(tierId, locId)] == true
end

local function setDiscoveredMap(map)
    discoveredLocs = {}
    if type(map) ~= 'table' then return end
    for key, val in pairs(map) do
        if val then discoveredLocs[key] = true end
    end
end

local TIER_META = {
    store = { level = 2, action = 'Pradėti apiplėšimą' },
    bank_fleeca = { level = 3, action = 'Fleeca vault hack' },
    bank_main = { level = 4, action = 'Pacific vault hack' },
    casino = { level = 4, action = 'Casino heist' },
    vault = { level = 5, action = 'Federal vault hack' },
}

local function resetSession()
    if session and session.locId then
        exports['mrp_hacking']:ReleaseHeistDoors(session.locId)
    end
    if session and exports['mrp_hacking']:IsCasinoHeist(session.tierId) then
        exports['mrp_hacking']:CleanupCasinoHeist()
    end
    if session then
        TriggerServerEvent('mrp_hacking:server:robberyRelease', session.tierId, session.locId)
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
    TriggerServerEvent('mrp_hacking:server:robberyFailed', session.tierId, session.locId)
    resetSession()
end

local function runPhysicalPhase(phase)
    local mg = (Config.RobberyMinigames or {})[phase]
    local anim = (Config.RobberyAnims or {})[phase]
    if not mg then return false end
    local ok = exports['mrp_hacking']:RunPhysicalMinigame(mg.mode, {
        label = mg.label,
        anim = anim,
        data = mg.data or {},
    })
    return ok
end

local function bumpCasinoLootIndex()
    if not session or not exports['mrp_hacking']:IsCasinoHeist(session.tierId) then return nil end
    session.casinoLootIndex = (session.casinoLootIndex or 0) + 1
    return session.casinoLootIndex
end

local function playHackSound(name)
    PlaySoundFrontend(-1, name or 'Pin_Good', 'DLC_HEIST_BIOLAB_PREP_HACKING_SOUNDS', true)
end

local function runHackPhase()
    if not session then return end
    playHackSound('Background')
    exports['mrp_hacking']:StartHack(session.tierId, session.coords, function(ok)
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
        TriggerServerEvent('mrp_hacking:server:robberyPhaseDone', session.tierId, session.locId, 'hack')
    end, session.locId)
end

local function playBankDoorOpen(coords)
    QBCore.Functions.Notify('Banko durys atrakintos — gręžk seifo vartus.', 'success')
    PlaySoundFromCoord(-1, 'Vault_Unlock', coords.x, coords.y, coords.z, 'dlc_heist_fleeca_bank_door_sounds', false, 0, false)
    if session and session.locId then
        exports['mrp_hacking']:OpenBankVaultAfterHack(session.locId, coords)
    end
end

local function playVaultGateOpen(coords)
    QBCore.Functions.Notify('Seifo vartai atidaryti — grabink pinigus.', 'success')
    PlaySoundFromCoord(-1, 'Drill_Pin_Break', coords.x, coords.y, coords.z, 'DLC_HEIST_FLEECA_BANK_DRILLING_SOUNDS', false, 0, false)
    if session and session.locId then
        exports['mrp_hacking']:OpenBankVaultAfterDrill(session.locId, coords)
    end
end

local function runPhase(phase)
    if not session then return end
    session.phase = phase

    if phase == 'hack' then
        return runHackPhase()
    end

    local isCasino = exports['mrp_hacking']:IsCasinoHeist(session.tierId)
    local lootIdx = nil

    if isCasino and phase ~= 'hack' then
        lootIdx = (phase == 'loot') and bumpCasinoLootIndex() or nil
        if not exports['mrp_hacking']:WaitAtCasinoPhase(phase, lootIdx) then
            return failRobbery('Nepavyko pasiekti tikslo.')
        end
        local def = exports['mrp_hacking']:GetCasinoPhaseDef(phase, lootIdx)
        if def and def.coords then
            session.coords = def.coords
        end
    end

    if phase == 'card' or phase == 'thermite' or phase == 'drill' or phase == 'loot' then
        local ok
        if isCasino and phase == 'loot' then
            ok = exports['mrp_hacking']:RunCasinoTrolleyLoot(session.coords, lootIdx or 1)
        elseif isCasino then
            ok = exports['mrp_hacking']:RunCasinoPhysical(phase)
        else
            ok = runPhysicalPhase(phase)
        end
        if not session then return end
        if ok then
            TriggerServerEvent('mrp_hacking:server:robberyPhaseDone', session.tierId, session.locId, phase)
        else
            failRobbery('Atšaukta arba nepavyko.')
        end
        return
    end
end

local function tierTargetLabel(tierId, loc)
    local tierCfg = Config.RobberyTiers and Config.RobberyTiers[tierId]
    local meta = TIER_META[tierId]
    local level = (tierCfg and tierCfg.level) or (meta and meta.level) or 1
    local action = (meta and meta.action) or 'Pradėti apiplėšimą'
    return ('LVL %d · %s — %s'):format(level, loc.label or tierId, action)
end

local function startRobbery(tierId, loc)
    if session then
        return QBCore.Functions.Notify('Jau vyksta apiplėšimas.', 'error')
    end
    QBCore.Functions.TriggerCallback('mrp_hacking:server:robberyCanStart', function(res)
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
        TriggerServerEvent('mrp_hacking:server:robberyClaim', tierId, loc.id)
        exports['mrp_hacking']:LockHeistDoors(loc.id)
        QBCore.Functions.Notify(('Pradedamas: %s'):format(loc.label), 'primary')
        if exports['mrp_hacking']:IsCasinoHeist(tierId) then
            exports['mrp_hacking']:CasinoHeistIntro()
        end
        runPhase(session.flow[session.flowIndex])
    end, tierId, loc.id)
end

RegisterNetEvent('mrp_hacking:client:robberyNextPhase', function(tierId, locId, completedPhase)
    if not session or session.tierId ~= tierId or session.locId ~= locId then return end
    exports['mrp_hacking']:UnlockHeistDoorsForPhase(locId, completedPhase)
    local bankTiers = { bank_fleeca = true, bank_main = true, vault = true }
    if completedPhase == 'hack' and bankTiers[tierId] then
        playBankDoorOpen(session.coords)
    elseif completedPhase == 'drill' and bankTiers[tierId] then
        playVaultGateOpen(session.coords)
    elseif exports['mrp_hacking']:IsCasinoHeist(tierId) then
        local lootIdx = (completedPhase == 'loot') and session.casinoLootIndex or nil
        exports['mrp_hacking']:OnCasinoPhaseComplete(completedPhase, lootIdx, session.coords)
    end
    local nxt = nextPhase()
    if not nxt then
        resetSession()
        return
    end
    runPhase(nxt)
end)

RegisterNetEvent('mrp_hacking:client:robberyFinished', function()
    resetSession()
end)

RegisterNetEvent('mrp_hacking:client:robberyAbort', function()
    resetSession()
end)

function IsRobberySessionActive()
    return session ~= nil
end

exports('IsRobberySessionActive', IsRobberySessionActive)

local robberyZones = {}

local function removeRobberyTargets()
    for zoneName in pairs(robberyZones) do
        pcall(function()
            exports['qb-target']:RemoveZone(zoneName)
        end)
    end
    robberyZones = {}
end

local function registerRobberyTargets()
    removeRobberyTargets()
    if GetResourceState('qb-target') ~= 'started' then return end

    local locations = Config.Robberies and Config.Robberies.Locations or {}
    for tierId, list in pairs(locations) do
        for _, loc in ipairs(list) do
            if not isLocDiscovered(tierId, loc.id) then
                goto continue_rob_zone
            end
            local zoneName = ('hack_rob_%s_%s'):format(tierId, loc.id)
            robberyZones[zoneName] = true
            exports['qb-target']:AddCircleZone(zoneName, loc.coords, loc.radius or 1.6, {
                name = zoneName,
                debugPoly = false,
                useZ = true,
            }, {
                options = {
                    {
                        icon = 'fas fa-mask',
                        label = tierTargetLabel(tierId, loc),
                        canInteract = function()
                            return not session
                        end,
                        action = function()
                            startRobbery(tierId, loc)
                        end,
                    },
                },
                distance = 2.5,
            })
            ::continue_rob_zone::
        end
    end
end

RegisterNetEvent('mrp_hacking:client:discoveredLocsUpdated', function(map, tierId, locId, label)
    setDiscoveredMap(map)
    if tierId and locId and label then
        QBCore.Functions.Notify(('Nuskanuota: %s — dabar gali pradėti apiplėšimą.'):format(label), 'success', 7000)
    end
    registerRobberyTargets()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    QBCore.Functions.TriggerCallback('mrp_hacking:server:getDiscoveredRobberyLocs', function(map)
        setDiscoveredMap(map)
        registerRobberyTargets()
    end)
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    if LocalPlayer.state.isLoggedIn then
        QBCore.Functions.TriggerCallback('mrp_hacking:server:getDiscoveredRobberyLocs', function(map)
            setDiscoveredMap(map)
            registerRobberyTargets()
        end)
    end
end)

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do
        Wait(500)
    end
    Wait(1000)
    registerRobberyTargets()
end)

AddEventHandler('onResourceStart', function(res)
    if res == 'qb-target' or res == GetCurrentResourceName() then
        SetTimeout(1500, registerRobberyTargets)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    removeRobberyTargets()
    resetSession()
end)
