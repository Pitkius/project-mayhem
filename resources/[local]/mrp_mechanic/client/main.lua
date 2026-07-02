local QBCore = exports['qb-core']:GetCoreObject()

local jobMapBlips = {}

local function isMechanicJob()
    local P = QBCore.Functions.GetPlayerData()
    return P and P.job and P.job.name == Config.JobName
end

local function isMechanicOnDuty()
    local P = QBCore.Functions.GetPlayerData()
    return P and P.job and P.job.name == Config.JobName and P.job.onduty
end

local function canBossMenu()
    local P = QBCore.Functions.GetPlayerData()
    if not P or not P.job or P.job.name ~= Config.JobName or not P.job.onduty then return false end
    if P.job.isboss then return true end
    return (P.job.grade and P.job.grade.level or 0) >= (Config.Permissions.boss_menu or 4)
end

local function setBlipLabel(blip, label)
    if GetResourceState('mrp_fonts') == 'started' then
        exports['mrp_fonts']:SetBlipName(blip, label)
        return
    end
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(label)
    EndTextCommandSetBlipName(blip)
end

local function createMapBlip(entry)
    local c = entry.coords
    if not c then return nil end
    local blip = AddBlipForCoord(c.x + 0.0, c.y + 0.0, c.z + 0.0)
    SetBlipSprite(blip, entry.sprite or 446)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, entry.scale or 0.72)
    SetBlipColour(blip, entry.colour or 47)
    SetBlipAsShortRange(blip, entry.shortRange ~= false)
    setBlipLabel(blip, entry.label or 'Mechanikai')
    return blip
end

local function clearJobMapBlips()
    for _, blip in ipairs(jobMapBlips) do
        if blip and DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    jobMapBlips = {}
end

local function refreshJobMapBlips()
    clearJobMapBlips()
    if Config.ShowMapBlips ~= true or not isMechanicJob() then return end
    for _, entry in ipairs(Config.MapBlips or {}) do
        local blip = createMapBlip(entry)
        if blip then jobMapBlips[#jobMapBlips + 1] = blip end
    end
end

RegisterNetEvent('mrp_mechanic:client:toggleDuty', function()
    local P = QBCore.Functions.GetPlayerData()
    if not P or not P.job or P.job.name ~= Config.JobName then return end
    TriggerServerEvent('QBCore:ToggleDuty')
end)

RegisterNetEvent('mrp_mechanic:client:openGarageFleet', function()
    if not isMechanicOnDuty() then
        return QBCore.Functions.Notify('Tik mechanikams tarnyboje.', 'error')
    end
    TriggerEvent('mrp_garages:client:openGarage', { garageId = 'mech_ls' })
end)

RegisterNetEvent('mrp_mechanic:client:openDealershipFleet', function()
    if not isMechanicOnDuty() then
        return QBCore.Functions.Notify('Tik mechanikams tarnyboje.', 'error')
    end
    TriggerEvent('mrp_dealership:client:openMechanicDealership', 'mech_ls')
end)

RegisterNetEvent('mrp_mechanic:client:openStash', function()
    if not isMechanicOnDuty() then
        return QBCore.Functions.Notify('Tik mechanikams tarnyboje.', 'error')
    end
    TriggerServerEvent('mrp_mechanic:server:openStash')
end)

RegisterNetEvent('mrp_mechanic:client:openBossStash', function()
    if not canBossMenu() then
        return QBCore.Functions.Notify('Tik vadovybei tarnyboje.', 'error')
    end
    TriggerServerEvent('mrp_mechanic:server:openBossStash')
end)

RegisterCommand('mechmdt', function()
    if not isMechanicOnDuty() then
        return QBCore.Functions.Notify('Tik mechanikams tarnyboje.', 'error')
    end
    if GetResourceState('mrp_service_mdt') == 'started' then
        exports['mrp_service_mdt']:OpenMdt('mechanic')
    else
        ExecuteCommand('servicemdt')
    end
end, false)

RegisterCommand('mechcall', function(_, args)
    if not isMechanicOnDuty() then
        return QBCore.Functions.Notify('Tik mechanikams tarnyboje.', 'error')
    end
    local callType = tostring(args and args[1] or 'civilian_help')
    local text = table.concat(args or {}, ' ', 2)
    TriggerServerEvent('mrp_dispatch:server:createServiceCall', 'mechanic', callType, text ~= '' and text or 'Mechanikų vidinis iškvietimas')
    QBCore.Functions.Notify('Mechanikų iškvietimas sukurtas MDT sistemoje.', 'success')
end, false)

RegisterNetEvent('mrp_mechanic:client:openCraftMenu', function(data)
    if not isMechanicOnDuty() then
        return QBCore.Functions.Notify('Tik mechanikams tarnyboje.', 'error')
    end
    local craftKind = (data and data.craftKind) or 'tuning'
    local menu = {
        { header = craftKind == 'kits' and 'Remonto dalių gamyba' or 'Tuningo detalių gamyba', txt = 'Gamyba naudoja žaliavas iš inventoriaus', isMenuHeader = true },
    }
    for key, recipe in pairs(Config.TuningRecipes or {}) do
        local isKit = key:sub(-4) == '_kit' or key == 'turbo_kit'
        if craftKind == 'kits' and not isKit then goto continue end
        if craftKind == 'tuning' and isKit then goto continue end
        local req = {}
        for item, cnt in pairs(recipe.materials or {}) do
            req[#req + 1] = ('%s x%s'):format(item, cnt)
        end
        menu[#menu + 1] = {
            header = recipe.label or key,
            txt = table.concat(req, ' | '),
            params = {
                isAction = true,
                event = function()
                    local input = exports['qb-input']:ShowInput({
                        header = recipe.label or key,
                        submitText = 'Gaminti',
                        inputs = {
                            { text = 'Kiekis (1-10)', name = 'amount', type = 'number', isRequired = true },
                        },
                    })
                    if not input or not input.amount then return end
                    TriggerServerEvent('mrp_mechanic:server:craftTuningPart', key, tonumber(input.amount) or 1)
                end,
            },
        }
        ::continue::
    end
    if #menu < 2 then
        return QBCore.Functions.Notify('Nėra receptų šiam stalui.', 'error')
    end
    TriggerEvent('qb-menu:client:openMenu', menu, false, true)
end)

local function applyOutfitTable(ped, tbl)
    if not ped or not tbl then return end
    for comp, val in pairs(tbl) do
        local c = tonumber(comp)
        if c ~= nil then
            local draw, tex = 0, 0
            if type(val) == 'table' then
                draw = tonumber(val[1]) or 0
                tex = tonumber(val[2]) or 0
            else
                draw = tonumber(val) or 0
            end
            SetPedComponentVariation(ped, c, draw, tex, 0)
        end
    end
end

RegisterNetEvent('mrp_mechanic:client:openLocker', function()
    if not isMechanicOnDuty() then
        return QBCore.Functions.Notify('Rūbinė – tik mechanikams tarnyboje.', 'error')
    end
    if GetResourceState('qb-menu') ~= 'started' then
        return QBCore.Functions.Notify('Reikia qb-menu.', 'error')
    end
    local P = QBCore.Functions.GetPlayerData()
    local grade = (P.job and P.job.grade and P.job.grade.level) or 0
    local menu = { { header = 'Darbo apranga', isMenuHeader = true } }
    for idx, outfit in ipairs(Config.DutyOutfits or {}) do
        if grade >= (tonumber(outfit.minGrade) or 0) then
            menu[#menu + 1] = {
                header = outfit.label,
                params = {
                    event = 'mrp_mechanic:client:applyOutfit',
                    args = { index = idx },
                },
            }
        end
    end
    if #menu < 2 then
        return QBCore.Functions.Notify('Nėra aprangų.', 'error')
    end
    TriggerEvent('qb-menu:client:openMenu', menu, false, true)
end)

RegisterNetEvent('mrp_mechanic:client:applyOutfit', function(data)
    if not isMechanicOnDuty() then return end
    local idx = tonumber(data and data.index)
    local outfit = idx and Config.DutyOutfits and Config.DutyOutfits[idx]
    if not outfit then return end
    local ped = PlayerPedId()
    local male = GetEntityModel(ped) == `mp_m_freemode_01`
    local tbl = male and outfit.male or outfit.female
    if not tbl then return end
    applyOutfitTable(ped, tbl)
    QBCore.Functions.Notify(outfit.label or 'Apranga uždėta.', 'success')
end)

CreateThread(function()
    local bl = Config.Blip or {}
    local c = bl.coords or (Config.GarageHub and Config.GarageHub.coords)
    if not c then return end
    local mark = AddBlipForCoord(c.x + 0.0, c.y + 0.0, c.z + 0.0)
    SetBlipSprite(mark, bl.sprite or 446)
    SetBlipDisplay(mark, 4)
    SetBlipScale(mark, bl.scale or 0.85)
    SetBlipColour(mark, bl.colour or 47)
    SetBlipAsShortRange(mark, true)
    setBlipLabel(mark, bl.label or 'Mechanikų dirbtuvės')
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    refreshJobMapBlips()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function()
    refreshJobMapBlips()
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    Wait(500)
    refreshJobMapBlips()
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearJobMapBlips()
end)

CreateThread(function()
    while GetResourceState('mrp_npcshops') ~= 'started' do
        Wait(200)
    end
    local addMarker = exports['mrp_npcshops'].AddJobGroundMarker
    local gh = Config.GarageHub
    addMarker({
        coords = gh.coords,
        kind = 'garage',
        job = Config.JobName,
        label = 'Mechanikų garažas / transportas',
        scale = { x = 3.2, y = 3.2, z = 0.28 },
        canUse = isMechanicOnDuty,
        onPress = function()
            if GetResourceState('qb-menu') ~= 'started' then return end
            TriggerEvent('qb-menu:client:openMenu', {
                { header = 'Mechanikų transportas', isMenuHeader = true },
                { header = 'Garažas', params = { event = 'mrp_mechanic:client:openGarageFleet' } },
                { header = 'Tarnybinio transporto pirkimas', params = { event = 'mrp_mechanic:client:openDealershipFleet' } },
            }, false, true)
        end,
    })
    local st = Config.Stash
    addMarker({
        coords = st.coords,
        kind = 'stash',
        job = Config.JobName,
        label = st.label or 'Mechanikų sandėlis',
        canUse = isMechanicOnDuty,
        onPress = function()
            TriggerEvent('mrp_mechanic:client:openStash')
        end,
    })
    local bs = Config.BossStash
    if bs and bs.coords then
        addMarker({
            coords = bs.coords,
            kind = 'stash',
            job = Config.JobName,
            label = bs.label or 'Boso sandėlis',
            canUse = canBossMenu,
            onPress = function()
                TriggerEvent('mrp_mechanic:client:openBossStash')
            end,
        })
    end
end)

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do
        Wait(300)
    end

    local lk = Config.Locker
    exports['qb-target']:AddBoxZone('mrp_mech_locker', lk.coords, 1.65, 1.65, {
        name = 'mrp_mech_locker',
        heading = lk.heading,
        debugPoly = false,
        minZ = lk.coords.z - 1.15,
        maxZ = lk.coords.z + 2.35,
    }, {
        options = {
            {
                type = 'client',
                event = 'mrp_mechanic:client:openLocker',
                icon = 'fas fa-shirt',
                label = 'Rūbinė (darbo apranga)',
                canInteract = function()
                    return isMechanicOnDuty()
                end,
            },
        },
        distance = Config.TargetDistance + 0.35,
    })

    local mg = Config.Management.coords
    exports['qb-target']:AddBoxZone('mrp_mech_mgmt', mg, 1.95, 1.95, {
        name = 'mrp_mech_mgmt',
        heading = Config.Management.heading,
        debugPoly = false,
        minZ = mg.z - 1.25,
        maxZ = mg.z + 2.55,
    }, {
        options = {
            {
                type = 'client',
                event = 'mrp_mechanic:client:bossOpenMenu',
                icon = 'fas fa-user-tie',
                label = 'Vadovybė (įdarb./rangai)',
                canInteract = function()
                    return canBossMenu()
                end,
            },
        },
        distance = 3.4,
    })

    exports['qb-target']:AddBoxZone('mrp_mech_duty', vector3(Config.Base.x, Config.Base.y, Config.Base.z), 1.85, 1.85, {
        name = 'mrp_mech_duty',
        heading = Config.Base.w,
        debugPoly = false,
        minZ = Config.Base.z - 1.15,
        maxZ = Config.Base.z + 2.45,
    }, {
        options = {
            {
                type = 'client',
                event = 'mrp_mechanic:client:toggleDuty',
                icon = 'fas fa-id-badge',
                label = 'Tarnyba (įjungti / išjungti)',
                canInteract = function()
                    return isMechanicJob()
                end,
            },
        },
        distance = Config.TargetDistance + 0.65,
    })

    for i, bay in ipairs(Config.RepairBays or {}) do
        exports['qb-target']:AddBoxZone(('mrp_mech_bay_%s'):format(i), bay.coords, bay.length, bay.width, {
            name = ('mrp_mech_bay_%s'):format(i),
            heading = bay.heading,
            debugPoly = false,
            minZ = bay.coords.z - 1.35,
            maxZ = bay.coords.z + 3.5,
        }, {
            options = {
                {
                    type = 'client',
                    event = 'mrp_mechanic:client:openBayWorkshop',
                    icon = 'fas fa-wrench',
                    label = ('Dirbtuvės #%s (remontas / tuningas)'):format(i),
                    bayIndex = i,
                    canInteract = function()
                        return isMechanicOnDuty()
                    end,
                },
            },
            distance = 14.0,
        })
    end

    for i, st in ipairs(Config.CraftingStations or {}) do
        local craftKind = st.craftKind or 'tuning'
        exports['qb-target']:AddBoxZone(('mrp_mech_craft_%s'):format(i), st.coords, st.length or 1.8, st.width or 1.8, {
            name = ('mrp_mech_craft_%s'):format(i),
            heading = st.heading or 0.0,
            debugPoly = false,
            minZ = st.coords.z - 1.1,
            maxZ = st.coords.z + 2.2,
        }, {
            options = {
                {
                    type = 'client',
                    event = 'mrp_mechanic:client:openCraftMenu',
                    icon = 'fas fa-industry',
                    label = st.label or 'Tuningo dalių staklės',
                    craftKind = craftKind,
                    canInteract = function()
                        return isMechanicOnDuty()
                    end,
                },
            },
            distance = 2.5,
        })
    end
end)
