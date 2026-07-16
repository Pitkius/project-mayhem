local QBCore = exports['qb-core']:GetCoreObject()

local bossLaptops = {}

local LAPTOP_MODELS = {
    `prop_laptop_01a`,
    `prop_laptop_02_closed`,
    `prop_laptop_lester2`,
}

local function isPdJobName(name)
    return name == Config.JobName
end

local function canOpenBoss()
    local P = QBCore.Functions.GetPlayerData()
    if not P or not P.job or not isPdJobName(P.job.name) or not P.job.onduty then
        return false
    end
    if P.job.isboss or P.job.isdeputy then return true end
    return (P.job.grade and P.job.grade.level or 0) >= (Config.Permissions.boss_menu or 7)
end

local function openBossMenu()
    if not canOpenBoss() then
        return QBCore.Functions.Notify('Neturi teisės naudoti vadovybės meniu.', 'error')
    end
    if GetResourceState('mrp_bossmenu') == 'started' then
        return exports['mrp_bossmenu']:OpenBossMenu(Config.JobName or 'police')
    end
    if GetResourceState('qb-menu') ~= 'started' then
        return QBCore.Functions.Notify('Reikia qb-menu.', 'error')
    end
    local menu = {
        { header = 'LTPD vadovybė', isMenuHeader = true },
        {
            header = 'Įdarbinti į PD',
            txt = 'Serverio ID + pradinis rangas',
            params = {
                event = 'mrp_ltpd:client:bossHireInput',
            },
        },
        {
            header = 'Atleisti iš PD',
            txt = 'Serverio ID',
            params = {
                event = 'mrp_ltpd:client:bossFireInput',
            },
        },
        {
            header = 'Keisti pareigūno rangą',
            txt = 'Serverio ID + naujas rangas 0–10',
            params = {
                event = 'mrp_ltpd:client:bossGradeInput',
            },
        },
        {
            header = 'Tarnyba: įjungti / išjungti',
            txt = 'Tavo duty (kaip F5 meniu)',
            params = {
                event = 'mrp_ltpd:client:bossToggleDuty',
            },
        },
    }
    TriggerEvent('qb-menu:client:openMenu', menu, false, true)
end

RegisterNetEvent('mrp_ltpd:client:bossOpenMenu', function()
    openBossMenu()
end)

RegisterNetEvent('mrp_ltpd:client:bossHireInput', function()
    if not canOpenBoss() then return end
    if GetResourceState('qb-input') ~= 'started' then return end
    local r = exports['qb-input']:ShowInput({
        header = 'Įdarbinti',
        submitText = 'Toliau',
        inputs = {
            { type = 'number', isRequired = true, name = 'pid', text = 'Žaidėjo server ID' },
            { type = 'number', isRequired = true, name = 'grade', text = 'Pradinis rangas (0–10)' },
        },
    })
    if not r or not r.pid then return end
    TriggerServerEvent('mrp_ltpd:server:bossHire', tonumber(r.pid), tonumber(r.grade))
end)

RegisterNetEvent('mrp_ltpd:client:bossFireInput', function()
    if not canOpenBoss() then return end
    if GetResourceState('qb-input') ~= 'started' then return end
    local r = exports['qb-input']:ShowInput({
        header = 'Atleisti iš PD',
        submitText = 'Patvirtinti',
        inputs = {
            { type = 'number', isRequired = true, name = 'pid', text = 'Žaidėjo server ID' },
        },
    })
    if not r or not r.pid then return end
    TriggerServerEvent('mrp_ltpd:server:bossFire', tonumber(r.pid))
end)

RegisterNetEvent('mrp_ltpd:client:bossGradeInput', function()
    if not canOpenBoss() then return end
    if GetResourceState('qb-input') ~= 'started' then return end
    local r = exports['qb-input']:ShowInput({
        header = 'Keisti rangą',
        submitText = 'Patvirtinti',
        inputs = {
            { type = 'number', isRequired = true, name = 'pid', text = 'Žaidėjo server ID' },
            { type = 'number', isRequired = true, name = 'grade', text = 'Naujas rangas (0–10)' },
        },
    })
    if not r or not r.pid then return end
    TriggerServerEvent('mrp_ltpd:server:bossSetGrade', tonumber(r.pid), tonumber(r.grade))
end)

RegisterNetEvent('mrp_ltpd:client:bossToggleDuty', function()
    local j = QBCore.Functions.GetPlayerData() and QBCore.Functions.GetPlayerData().job
    if not j or not isPdJobName(j.name) then
        return
    end
    TriggerServerEvent('QBCore:ToggleDuty')
end)

local function findLaptopAt(coords, radius)
    for i = 1, #LAPTOP_MODELS do
        local ent = GetClosestObjectOfType(coords.x, coords.y, coords.z, radius or 1.8, LAPTOP_MODELS[i], false, false, false)
        if ent ~= 0 then return ent end
    end
    return 0
end

local function ensureBossLaptop(bossCfg)
    local c = bossCfg.coords
    if not c then return 0, false end
    local pos = vector3(c.x, c.y, c.z)
    local ent = findLaptopAt(pos, 2.0)
    if ent ~= 0 then return ent, false end
    if bossCfg.spawnProp == false then return 0, false end

    local model = bossCfg.prop or 'prop_laptop_01a'
    local hash = type(model) == 'number' and model or joaat(model)
    RequestModel(hash)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > deadline then return 0, false end
        Wait(10)
    end
    ent = CreateObject(hash, c.x, c.y, c.z, false, false, false)
    if ent == 0 then return 0, false end
    SetEntityHeading(ent, c.w or c.heading or 0.0)
    FreezeEntityPosition(ent, true)
    SetEntityInvincible(ent, true)
    SetEntityAsMissionEntity(ent, true, true)
    SetModelAsNoLongerNeeded(hash)
    return ent, true
end

local function stationBossConfigs(st)
    local list = {}
    if st.boss and st.boss.coords then
        list[#list + 1] = st.boss
    end
    if st.bossAro and st.bossAro.coords then
        list[#list + 1] = st.bossAro
    end
    if type(st.bosses) == 'table' then
        for _, cfg in ipairs(st.bosses) do
            if cfg and cfg.coords then
                list[#list + 1] = cfg
            end
        end
    end
    return list
end

local function setupBossTargets()
    if GetResourceState('qb-target') ~= 'started' then return false end

    for _, st in ipairs(Config.Stations or {}) do
        for _, bossCfg in ipairs(stationBossConfigs(st)) do
            local ent, weSpawned = ensureBossLaptop(bossCfg)
            if ent ~= 0 then
                if weSpawned then bossLaptops[#bossLaptops + 1] = ent end

                exports['qb-target']:AddTargetEntity(ent, {
                    options = {
                        {
                            type = 'client',
                            event = 'mrp_ltpd:client:bossOpenMenu',
                            icon = 'fas fa-user-shield',
                            label = bossCfg.label or 'LTPD vadovybė',
                            job = Config.JobName or 'police',
                            canInteract = function()
                                return canOpenBoss()
                            end,
                        },
                    },
                    distance = 2.2,
                })
            end
        end
    end
    return true
end

CreateThread(function()
    local waited = 0
    while not setupBossTargets() and waited < 60 do
        Wait(1000)
        waited = waited + 1
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, ent in ipairs(bossLaptops) do
        if ent and DoesEntityExist(ent) then
            DeleteEntity(ent)
        end
    end
    bossLaptops = {}
end)
