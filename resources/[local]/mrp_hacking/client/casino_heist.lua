--- Diamond Casino Heist (GTA Online DLC stilius) — fazės, markeriai, vežimėliai, garsai
local QBCore = exports['qb-core']:GetCoreObject()

local trolleyEnts = {}
local CASINO_SOUNDSET = 'dlc_h4_casino_heist_door_sounds'

local function casinoCfg()
    return Config.Robberies and Config.Robberies.CasinoHeist
end

local function phaseKey(phase, lootIndex)
    if phase == 'loot' and lootIndex then
        return ('loot_%d'):format(lootIndex)
    end
    return phase
end

local function loadModel(model)
    if type(model) == 'string' then model = joaat(model) end
    RequestModel(model)
    local t = 0
    while not HasModelLoaded(model) and t < 150 do
        Wait(10)
        t = t + 1
    end
    return HasModelLoaded(model)
end

function IsCasinoHeist(tierId)
    return tierId == 'casino'
end

function GetCasinoPhaseDef(phase, lootIndex)
    local cfg = casinoCfg()
    if not cfg or not cfg.phases then return nil end
    local key = phaseKey(phase, lootIndex)
    return cfg.phases[key]
end

local function playCasinoSound(name, coords)
    if not coords then return end
    PlaySoundFromCoord(-1, name, coords.x, coords.y, coords.z, CASINO_SOUNDSET, false, 0, false)
end

function CleanupCasinoHeist()
    for _, ent in ipairs(trolleyEnts) do
        if ent and DoesEntityExist(ent) then
            DeleteEntity(ent)
        end
    end
    trolleyEnts = {}
end

local function spawnTrolleyAt(coords, heading)
    local model = joaat('hei_prop_hei_cash_trolly_01')
    if not loadModel(model) then return nil end
    local ent = CreateObject(model, coords.x, coords.y, coords.z - 0.98, true, true, false)
    if ent and ent ~= 0 then
        SetEntityHeading(ent, heading or 0.0)
        FreezeEntityPosition(ent, true)
        SetEntityAsMissionEntity(ent, true, true)
        trolleyEnts[#trolleyEnts + 1] = ent
    end
    SetModelAsNoLongerNeeded(model)
    return ent
end

--- Laukti kol žaidėjas prieina prie fazės (geltonas markeris kaip GTAO objective)
function WaitAtCasinoPhase(phase, lootIndex)
    local def = GetCasinoPhaseDef(phase, lootIndex)
    if not def or not def.coords then return true end

    local coords = def.coords
    local radius = def.radius or 1.8
    local label = def.label or 'Eik į pažymėtą vietą'
    local ped = PlayerPedId()
    local deadline = GetGameTimer() + ((casinoCfg() and casinoCfg().phaseWaitMs) or 180000)

    QBCore.Functions.Notify(label, 'primary', 6000)

    while exports['mrp_hacking']:IsRobberySessionActive() do
        ped = PlayerPedId()
        local p = GetEntityCoords(ped)
        local dist = #(p - coords)

        DrawMarker(1, coords.x, coords.y, coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
            radius * 2.0, radius * 2.0, 0.6, 255, 200, 50, 120, false, false, 2, false, nil, nil, false)

        if dist <= radius then
            return true
        end
        if GetGameTimer() > deadline then
            QBCore.Functions.Notify('Per ilgai užtrukai — heistas nutrauktas.', 'error')
            return false
        end
        Wait(0)
    end
    return false
end

function OnCasinoPhaseComplete(completedPhase, lootIndex, coords)
    coords = coords or GetEntityCoords(PlayerPedId())
    local cfg = casinoCfg()
    local msgs = cfg and cfg.transitionNotify or {}

    if completedPhase == 'hack' then
        playCasinoSound('Vault_Door_Unlock', coords)
        QBCore.Functions.Notify(msgs.afterHack or 'Tinklas išjungtas — termitas prie sandėlio vartų.', 'success', 7000)
    elseif completedPhase == 'thermite' then
        playCasinoSound('Vault_Door_Unlock', coords)
        QBCore.Functions.Notify(msgs.afterThermite or 'V0rtai atidaryti — gręžk seifo užraktą.', 'success', 7000)
    elseif completedPhase == 'drill' then
        playCasinoSound('Drill_Pin_Break', coords)
        QBCore.Functions.Notify(msgs.afterDrill or 'Seifas atidarytas — grabink pinigų vežimėlius.', 'success', 7000)
    elseif completedPhase == 'loot' and lootIndex then
        local total = (cfg and cfg.lootSteps) or 3
        if lootIndex < total then
            QBCore.Functions.Notify(('Vežimėlis %d/%d ištuštintas — kitas.'):format(lootIndex, total), 'success', 5000)
        end
    end
end

function RunCasinoPhysical(phase)
    local mg = (Config.RobberyMinigames or {})[phase]
    local anim = (Config.RobberyAnims or {})[phase]
    if not mg then return false end

    local data = {}
    for k, v in pairs(mg.data or {}) do data[k] = v end

    if phase == 'thermite' then
        data.holdMs = 3400
        mg = { mode = mg.mode, label = 'Termitas — laikyk SPACE (Casino Heist)', data = data }
    elseif phase == 'drill' then
        data.depthTarget = 100
        mg = { mode = 'drill', label = 'Seifo gręžimas — W/S galia, A/D kryptis', data = data }
    end

    return exports['mrp_hacking']:RunPhysicalMinigame(mg.mode, {
        label = mg.label,
        anim = anim,
        data = data,
    })
end

function RunCasinoTrolleyLoot(coords, step)
    local def = GetCasinoPhaseDef('loot', step)
    local c = (def and def.coords) or coords
    local heading = def and def.heading or 0.0

    spawnTrolleyAt(c, heading)

    local mg = (Config.RobberyMinigames or {}).loot
    local anim = (Config.RobberyAnims or {}).loot
    local total = (casinoCfg() and casinoCfg().lootSteps) or 3

    return exports['mrp_hacking']:RunPhysicalMinigame(mg.mode, {
        label = ('Pinigų vežimėlis %d/%d — spam SPACE'):format(step, total),
        anim = anim,
        data = { target = 28, timeMs = 11000 },
    })
end

function CasinoHeistIntro()
    local cfg = casinoCfg()
    QBCore.Functions.Notify(cfg and cfg.startNotify or 'Diamond Casino Heist — įsilaužimas į apsaugos tinklą.', 'primary', 8000)
end

exports('IsCasinoHeist', IsCasinoHeist)
exports('GetCasinoPhaseDef', GetCasinoPhaseDef)
exports('WaitAtCasinoPhase', WaitAtCasinoPhase)
exports('OnCasinoPhaseComplete', OnCasinoPhaseComplete)
exports('RunCasinoPhysical', RunCasinoPhysical)
exports('RunCasinoTrolleyLoot', RunCasinoTrolleyLoot)
exports('CleanupCasinoHeist', CleanupCasinoHeist)
exports('CasinoHeistIntro', CasinoHeistIntro)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    CleanupCasinoHeist()
end)
