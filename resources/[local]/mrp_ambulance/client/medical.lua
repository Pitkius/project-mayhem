local QBCore = exports['qb-core']:GetCoreObject()

local busy = false

local function notify(msg, typ)
    QBCore.Functions.Notify(msg, typ or 'primary')
end

local function isEmsOnDuty()
    local P = QBCore.Functions.GetPlayerData()
    return P and P.job and P.job.name == Config.JobName and P.job.onduty
end

local function hasGrade(minGrade)
    local P = QBCore.Functions.GetPlayerData()
    if not P or not P.job then return false end
    return (tonumber(P.job.grade.level) or 0) >= (minGrade or 0)
end

local function getTargetServerId(entity)
    if not entity or entity == 0 then return nil end
    local idx = NetworkGetPlayerIndexFromPed(entity)
    if idx == -1 then return nil end
    return GetPlayerServerId(idx)
end

local function isEntityDown(ped)
    if not ped or ped == 0 then return false end
    if IsEntityDead(ped) or IsPedDeadOrDying(ped, true) then return true end
    local idx = NetworkGetPlayerIndexFromPed(ped)
    if idx == -1 then return false end
    local st = Player(idx).state
    if st and (st.isDead == true or st.dead == true) then return true end
    return false
end

local function isEntityInjured(ped)
    if not ped or ped == 0 or isEntityDown(ped) then return false end
    return GetEntityHealth(ped) < GetEntityMaxHealth(ped)
end

local function runProgress(name, label, durationMs, anim)
    durationMs = tonumber(durationMs) or 4000
    local done, cancelled = false, false
    local animDict, animClip, animFlags = nil, nil, 49
    if type(anim) == 'table' then
        animDict = anim.dict
        animClip = anim.clip
        animFlags = anim.flag or 49
    end
    QBCore.Functions.Progressbar(name, label or 'Vykdoma…', durationMs, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableCombat = true,
    }, {
        animDict = animDict,
        anim = animClip,
        flags = animFlags,
    }, {}, {}, function()
        done = true
    end, function()
        cancelled = true
        ClearPedTasks(PlayerPedId())
    end)
    local deadline = GetGameTimer() + durationMs + 1000
    while GetGameTimer() < deadline do
        if cancelled then return false end
        if done then return true end
        Wait(50)
    end
    return done
end

local function getClosestPlayerPed(maxDist)
    maxDist = maxDist or 2.5
    local myPed = PlayerPedId()
    local myCoords = GetEntityCoords(myPed)
    local closestPed, closestDist, closestSid = nil, maxDist + 0.01, nil
    for _, pid in ipairs(GetActivePlayers()) do
        local ped = GetPlayerPed(pid)
        if ped ~= myPed and ped ~= 0 then
            local d = #(myCoords - GetEntityCoords(ped))
            if d < closestDist then
                closestDist = d
                closestPed = ped
                closestSid = GetPlayerServerId(pid)
            end
        end
    end
    return closestPed, closestSid, closestDist
end

--- Server → target client: atgaivinimas vietoje
RegisterNetEvent('mrp_ambulance:client:applyRevive', function(health)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z + 0.35, heading, true, false)
    ped = PlayerPedId()
    SetPlayerInvincible(PlayerId(), false)
    ClearPedBloodDamage(ped)
    ClearPedTasksImmediately(ped)
    SetEntityHealth(ped, tonumber(health) or 200)
    SetPedArmour(ped, 0)
    TriggerEvent('mrp_phone:local:AfterHospitalWake')
end)

RegisterNetEvent('mrp_ambulance:client:applyHeal', function(health, armourAdd)
    local ped = PlayerPedId()
    if IsEntityDead(ped) or IsPedDeadOrDying(ped, true) then return end
    local maxH = GetEntityMaxHealth(ped)
    local target = tonumber(health)
    if target then
        SetEntityHealth(ped, math.min(maxH, target))
    end
    local addArmour = tonumber(armourAdd) or 0
    if addArmour > 0 then
        SetPedArmour(ped, math.min(100, GetPedArmour(ped) + addArmour))
    end
    ClearPedBloodDamage(ped)
end)

RegisterNetEvent('mrp_ambulance:client:applyHealAmount', function(amount, armourAdd)
    local ped = PlayerPedId()
    if IsEntityDead(ped) or IsPedDeadOrDying(ped, true) then return end
    local maxH = GetEntityMaxHealth(ped)
    local cur = GetEntityHealth(ped)
    SetEntityHealth(ped, math.min(maxH, cur + (tonumber(amount) or 0)))
    local addArmour = tonumber(armourAdd) or 0
    if addArmour > 0 then
        SetPedArmour(ped, math.min(100, GetPedArmour(ped) + addArmour))
    end
    ClearPedBloodDamage(ped)
end)

local function runReviveOnEntity(entity)
    if busy or not isEmsOnDuty() then return end
    if not hasGrade(Config.Permissions.revive or 0) then
        return notify('Neturite teisės atgaivinti.', 'error')
    end
    local targetId = getTargetServerId(entity)
    if not targetId then return end
    if not isEntityDown(entity) then
        return notify('Asmuo nėra negyvas / kritinėje būsenoje.', 'error')
    end
    busy = true
    local cfg = Config.Medical and Config.Medical.revive or {}
    local ok = runProgress('mrp_ems_revive', cfg.label or 'Atgaivinama…', cfg.progressMs or 8500, cfg.anim)
    busy = false
    if not ok then return notify('Atgaivinimas atšauktas.', 'error') end
    TriggerServerEvent('mrp_ambulance:server:revivePlayer', targetId)
end

local function runHealOnEntity(entity)
    if busy or not isEmsOnDuty() then return end
    if not hasGrade(Config.Permissions.heal or 0) then
        return notify('Neturite teisės gydyti.', 'error')
    end
    local targetId = getTargetServerId(entity)
    if not targetId then return end
    if isEntityDown(entity) then
        return notify('Pirmiausia atgaivinkite asmenį.', 'error')
    end
    local cfg = Config.Medical and Config.Medical.heal or {}
    if cfg.requireInjured ~= false and not isEntityInjured(entity) then
        return notify('Asmuo nėra sužeistas.', 'error')
    end
    busy = true
    local ok = runProgress('mrp_ems_heal', cfg.label or 'Gydoma…', cfg.progressMs or 5500, cfg.anim)
    busy = false
    if not ok then return notify('Gydymas atšauktas.', 'error') end
    TriggerServerEvent('mrp_ambulance:server:healPlayer', targetId)
end

--- Outdoor bay: atgaivinti artimiausią negyvą
RegisterNetEvent('mrp_ambulance:client:outdoorBay', function(data)
    if not isEmsOnDuty() then
        return notify('Tik EMS tarnyboje.', 'error')
    end
    local ped, sid = getClosestPlayerPed((Config.Medical and Config.Medical.maxDistance) or 2.8)
    if not ped or not sid then
        return notify('Šalia nėra žaidėjo. Naudok qb-target ant asmens (ALT).', 'primary', 5500)
    end
    if isEntityDown(ped) then
        runReviveOnEntity(ped)
    elseif isEntityInjured(ped) then
        runHealOnEntity(ped)
    else
        local i = 1
        if type(data) == 'table' and data.bayIndex ~= nil then
            i = tonumber(data.bayIndex) or 1
        end
        notify(('Priėmimo zona #%s – asmuo sveikas. Sužeistą / negyvą taikykite per ALT.'):format(i), 'primary', 5500)
    end
end)

local function useMedicalItem(itemName)
    if busy then return end
    local items = Config.Medical and Config.Medical.items or {}
    local cfg = items[itemName]
    if not cfg then return end

    local targetId = nil
    local targetPed = nil
    if cfg.canUseOnOthers then
        targetPed, targetId = getClosestPlayerPed(2.5)
        if targetPed and targetId then
            if cfg.emsOnlyOnOthers and not isEmsOnDuty() then
                targetPed, targetId = nil, nil
            end
        end
    end

    --- firstaid ant negyvo – tik EMS
    if cfg.canRevive and targetPed and isEntityDown(targetPed) then
        if not isEmsOnDuty() then
            return notify('Atgaivinti su rinkiniu gali tik EMS tarnyboje.', 'error')
        end
    elseif targetPed and isEntityDown(targetPed) and not cfg.canRevive then
        targetPed, targetId = nil, nil
    end

    busy = true
    local ok = runProgress('mrp_med_' .. itemName, cfg.label or 'Naudojama…', cfg.progressMs or 3000, cfg.anim)
    busy = false
    if not ok then return notify('Atšaukta.', 'error') end
    TriggerServerEvent('mrp_ambulance:server:useMedicalItem', itemName, targetId)
end

RegisterNetEvent('mrp_ambulance:client:useMedicalItem', function(itemName)
    useMedicalItem(tostring(itemName or ''))
end)

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do
        Wait(300)
    end
    local dist = (Config.Medical and Config.Medical.maxDistance) or 2.8
    exports['qb-target']:AddGlobalPlayer({
        options = {
            {
                icon = 'fas fa-heart-pulse',
                label = 'Atgaivinti',
                canInteract = function(entity)
                    if not isEmsOnDuty() or not hasGrade(Config.Permissions.revive or 0) then return false end
                    return isEntityDown(entity)
                end,
                action = function(entity)
                    runReviveOnEntity(entity)
                end,
            },
            {
                icon = 'fas fa-kit-medical',
                label = 'Gydyti',
                canInteract = function(entity)
                    if not isEmsOnDuty() or not hasGrade(Config.Permissions.heal or 0) then return false end
                    if isEntityDown(entity) then return false end
                    local cfg = Config.Medical and Config.Medical.heal or {}
                    if cfg.requireInjured == false then return true end
                    return isEntityInjured(entity)
                end,
                action = function(entity)
                    runHealOnEntity(entity)
                end,
            },
        },
        distance = dist,
    })
end)
