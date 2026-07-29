local QBCore = exports['qb-core']:GetCoreObject()
local sellPed = nil
local miningBusy = false
local sellUiOpen = false
local pendingWallIdx = nil
local pendingSandIdx = nil
local pendingTrashNet = nil

local function playerHasMiningPickaxe()
    return QBCore.Functions.HasItem('mining_pickaxe', 1)
end

local function loadModel(hash)
    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(10) end
end

local function loadAnimDict(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(10) end
end

local function playMiningAnim(ms)
    local ped = PlayerPedId()
    loadAnimDict('melee@large_wpn@streamed_core')
    TaskPlayAnim(ped, 'melee@large_wpn@streamed_core', 'ground_attack_on_spot', 8.0, -8.0, ms or 3000, 1, 0, false, false, false)
end

local function playDigAnim(ms)
    local ped = PlayerPedId()
    loadAnimDict('amb@world_human_gardener_plant@male@base')
    TaskPlayAnim(ped, 'amb@world_human_gardener_plant@male@base', 'base', 8.0, -8.0, ms or 2800, 1, 0, false, false, false)
end

local function playSellAnim(ms)
    local ped = PlayerPedId()
    loadAnimDict('mp_common')
    TaskPlayAnim(ped, 'mp_common', 'givetake1_a', 8.0, -8.0, ms or 2500, 49, 0, false, false, false)
end

local function playSearchAnim(ms)
    local ped = PlayerPedId()
    loadAnimDict('amb@prop_human_bum_bin@base')
    TaskPlayAnim(ped, 'amb@prop_human_bum_bin@base', 'base', 8.0, -8.0, ms or 3500, 1, 0, false, false, false)
end

local function setMiningUi(open)
    SetNuiFocus(open, open)
    if open then
        local mg = Config.Minigame or {}
        SendNUIMessage({
            action = 'startMining',
            hits = mg.hits or 5,
            time = mg.time or 12,
            speed = mg.speed or 0.88,
        })
    else
        SendNUIMessage({ action = 'close' })
    end
end

local function setSellUi(open, items)
    sellUiOpen = open
    SetNuiFocus(open, open)
    if open then
        SendNUIMessage({ action = 'openSell', items = items or {} })
    else
        SendNUIMessage({ action = 'close' })
    end
end

local function refreshSellUi()
    QBCore.Functions.TriggerCallback('mrp_mining:server:getSellInventory', function(res)
        if res and res.ok and sellUiOpen then
            SendNUIMessage({ action = 'sellRefresh', items = res.items or {} })
        end
    end)
end

local function openSellMenu()
    QBCore.Functions.TriggerCallback('mrp_mining:server:getSellInventory', function(res)
        if not res or not res.ok then
            return QBCore.Functions.Notify(res and res.message or 'Klaida.', 'error')
        end
        setSellUi(true, res.items or {})
    end)
end

local function openCleanMenu()
    local rows = {
        { header = 'Žaliavų nuvalymas', txt = 'Karjeras / smėlis / šiukšlės', isMenuHeader = true },
        {
            header = 'Nuvalyti visas žaliavas',
            txt = 'Žalia → nuvalyta (rūdos, akmuo, anglis, skalda, smėlis)',
            params = {
                isAction = true,
                event = function()
                    TriggerServerEvent('mrp_mining:server:cleanBatch')
                end,
            },
        },
        {
            header = 'Perdirbti šiukšles į medžiagas',
            txt = 'Buteliai / skardinė / guma → plastikas, stiklas, aliuminis, guma',
            params = {
                isAction = true,
                event = function()
                    TriggerServerEvent('mrp_mining:server:cleanTrashMaterials')
                end,
            },
        },
        {
            header = 'Nuvalyti butelius pakavimui',
            txt = 'Nešvarūs buteliai → švarūs (alkoholiui / skysčiams)',
            params = {
                isAction = true,
                event = function()
                    TriggerServerEvent('mrp_mining:server:cleanTrashBottles')
                end,
            },
        },
    }
    TriggerEvent('qb-menu:client:openMenu', rows, false, true)
end

local function openSmeltMenu()
    local rows = {
        { header = 'Metalų / stiklo išlydymas', txt = 'Reikia nuvalytų koncentratų ir anglies', isMenuHeader = true },
    }
    for _, recipe in ipairs(Config.SmeltRecipes or {}) do
        local r = recipe
        rows[#rows + 1] = {
            header = r.label or r.id,
            txt = r.txt or '',
            params = {
                isAction = true,
                event = function()
                    TriggerServerEvent('mrp_mining:server:smelt', r.id)
                end,
            },
        }
    end
    TriggerEvent('qb-menu:client:openMenu', rows, false, true)
end

local function addBlip(coords, cfg, fallbackLabel)
    if not coords or not cfg then return end
    local b = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(b, cfg.sprite or 1)
    SetBlipColour(b, cfg.colour or 0)
    SetBlipScale(b, cfg.scale or 0.8)
    SetBlipAsShortRange(b, true)
    exports['mrp_fonts']:SetBlipName(b, cfg.label or fallbackLabel or 'Vieta')
end

RegisterNetEvent('mrp_mining:client:startMining', function(data)
    if miningBusy then return end
    local wallIdx = data and tonumber(data.wallIndex)
    if not wallIdx then return end
    if not playerHasMiningPickaxe() then
        return QBCore.Functions.Notify('Reikia kasyklos kirtiklio.', 'error')
    end

    pendingWallIdx = wallIdx
    pendingSandIdx = nil
    miningBusy = true
    setMiningUi(true)
end)

RegisterNetEvent('mrp_mining:client:startSandDig', function(data)
    if miningBusy then return end
    local sandIdx = data and tonumber(data.sandIndex)
    if not sandIdx then return end

    miningBusy = true
    pendingSandIdx = sandIdx
    playDigAnim(Config.SandAnimDuration or 2800)
    QBCore.Functions.Progressbar('mrp_mining_sand', 'Kasi smėlį…', Config.SandAnimDuration or 2800, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function()
        TriggerServerEvent('mrp_mining:server:sandAttempt', sandIdx)
        miningBusy = false
        pendingSandIdx = nil
        ClearPedTasks(PlayerPedId())
    end, function()
        miningBusy = false
        pendingSandIdx = nil
        ClearPedTasks(PlayerPedId())
    end)
end)

RegisterNetEvent('mrp_mining:client:searchTrash', function(data)
    if miningBusy then return end
    local entity = data and data.entity
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return QBCore.Functions.Notify('Konteineris nerastas.', 'error')
    end

    miningBusy = true
    local netId = NetworkGetNetworkIdFromEntity(entity)
    pendingTrashNet = netId
    playSearchAnim(Config.TrashSearchDuration or 3500)
    QBCore.Functions.Progressbar('mrp_mining_trash', 'Ieškai šiukšlėse…', Config.TrashSearchDuration or 3500, false, true, {
        disableMovement = true,
        disableCombat = true,
    }, {}, {}, {}, function()
        TriggerServerEvent('mrp_mining:server:trashSearch', netId)
        miningBusy = false
        pendingTrashNet = nil
        ClearPedTasks(PlayerPedId())
    end, function()
        miningBusy = false
        pendingTrashNet = nil
        ClearPedTasks(PlayerPedId())
    end)
end)

RegisterNUICallback('miningResult', function(data, cb)
    cb({ ok = true })
    local wallIdx = pendingWallIdx
    pendingWallIdx = nil
    SetNuiFocus(false, false)

    if not data or not data.success or not wallIdx then
        miningBusy = false
        ClearPedTasks(PlayerPedId())
        return QBCore.Functions.Notify('Kasimas nepavyko.', 'error')
    end

    playMiningAnim(Config.MineAnimDuration or 3200)
    QBCore.Functions.Progressbar('mrp_mining', 'Kasi uolą…', Config.MineAnimDuration or 3200, false, false, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function()
        TriggerServerEvent('mrp_mining:server:mineAttempt', wallIdx)
        miningBusy = false
        ClearPedTasks(PlayerPedId())
    end, function()
        miningBusy = false
        ClearPedTasks(PlayerPedId())
    end)
end)

RegisterNUICallback('closeUi', function(_, cb)
    cb({ ok = true })
    miningBusy = false
    sellUiOpen = false
    pendingWallIdx = nil
    pendingSandIdx = nil
    pendingTrashNet = nil
    SetNuiFocus(false, false)
end)

RegisterNUICallback('sellItem', function(data, cb)
    cb({ ok = true })
    local item = data and data.item
    if not item then return end
    playSellAnim(Config.SellAnimDuration or 2800)
    QBCore.Functions.Progressbar('mrp_mining_sell', 'Parduodi…', Config.SellAnimDuration or 2800, false, false, {
        disableMovement = true,
        disableCombat = true,
    }, {}, {}, {}, function()
        TriggerServerEvent('mrp_mining:server:sellItem', item)
        SetTimeout(400, refreshSellUi)
        ClearPedTasks(PlayerPedId())
    end, function()
        ClearPedTasks(PlayerPedId())
    end)
end)

RegisterNUICallback('sellAll', function(_, cb)
    cb({ ok = true })
    playSellAnim(Config.SellAnimDuration or 2800)
    QBCore.Functions.Progressbar('mrp_mining_sell_all', 'Parduodi viską…', Config.SellAnimDuration or 2800, false, false, {
        disableMovement = true,
        disableCombat = true,
    }, {}, {}, {}, function()
        TriggerServerEvent('mrp_mining:server:sellAll')
        SetTimeout(500, function()
            refreshSellUi()
            setSellUi(false)
        end)
        ClearPedTasks(PlayerPedId())
    end, function()
        ClearPedTasks(PlayerPedId())
    end)
end)

CreateThread(function()
    local center = Config.MiningSites[1] and Config.MiningSites[1].coords
    addBlip(center, Config.Blips.mining, 'Karjeras — kasimas')

    local clean = Config.CleanCoords or Config.ProcessCoords
    addBlip(clean, Config.Blips.clean or Config.Blips.process, 'Žaliavų nuvalymas')

    local smelt = Config.SmeltCoords
    addBlip(smelt, Config.Blips.smelt, 'Metalų išlydymas')

    addBlip(Config.SellPed and Config.SellPed.coords, Config.Blips.sell, 'Metalų supirkimas')

    for _, site in ipairs(Config.SandDigSites or {}) do
        addBlip(site.center, Config.Blips.sand, site.label or 'Smėlio kasimas')
    end
end)

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do Wait(300) end

    for i, wall in ipairs(Config.MiningWalls or {}) do
        exports['qb-target']:AddBoxZone(('mrp_mine_wall_%s'):format(i), wall.center, wall.length or 40.0, wall.width or 6.0, {
            name = ('mrp_mine_wall_%s'):format(i),
            heading = wall.heading or 0.0,
            debugPoly = false,
            minZ = wall.minZ or (wall.center.z - 3.0),
            maxZ = wall.maxZ or (wall.center.z + 4.0),
        }, {
            options = {
                {
                    type = 'client',
                    event = 'mrp_mining:client:startMining',
                    icon = 'fas fa-hammer',
                    label = wall.label or 'Kasti uolą',
                    wallIndex = i,
                    canInteract = function()
                        return playerHasMiningPickaxe() and not miningBusy
                    end,
                },
            },
            distance = 2.8,
        })
    end

    for i, site in ipairs(Config.SandDigSites or {}) do
        exports['qb-target']:AddBoxZone(('mrp_sand_dig_%s'):format(i), site.center, site.length or 30.0, site.width or 20.0, {
            name = ('mrp_sand_dig_%s'):format(i),
            heading = site.heading or 0.0,
            debugPoly = false,
            minZ = site.minZ or (site.center.z - 2.0),
            maxZ = site.maxZ or (site.center.z + 3.0),
        }, {
            options = {
                {
                    type = 'client',
                    event = 'mrp_mining:client:startSandDig',
                    icon = 'fas fa-mountain',
                    label = site.label or 'Kasti smėlį',
                    sandIndex = i,
                    canInteract = function()
                        return not miningBusy
                    end,
                },
            },
            distance = 2.5,
        })
    end

    local clean = Config.CleanCoords or Config.ProcessCoords
    if clean then
        exports['qb-target']:AddBoxZone('mrp_mining_clean', vector3(clean.x, clean.y, clean.z), 2.4, 2.4, {
            name = 'mrp_mining_clean',
            heading = clean.w or 0,
            debugPoly = false,
            minZ = clean.z - 1.2,
            maxZ = clean.z + 2.4,
        }, {
            options = {
                {
                    type = 'client',
                    event = 'mrp_mining:client:openCleanMenu',
                    icon = 'fas fa-soap',
                    label = 'Nuvalyti žaliavas',
                },
            },
            distance = 2.5,
        })
    end

    local smelt = Config.SmeltCoords
    if smelt then
        exports['qb-target']:AddBoxZone('mrp_mining_smelt', vector3(smelt.x, smelt.y, smelt.z), 2.6, 2.6, {
            name = 'mrp_mining_smelt',
            heading = smelt.w or 0,
            debugPoly = false,
            minZ = smelt.z - 1.2,
            maxZ = smelt.z + 2.6,
        }, {
            options = {
                {
                    type = 'client',
                    event = 'mrp_mining:client:openSmeltMenu',
                    icon = 'fas fa-fire',
                    label = 'Lydyti metalus / stiklą',
                },
            },
            distance = 2.5,
        })
    end

    if Config.TrashModels and #Config.TrashModels > 0 then
        exports['qb-target']:AddTargetModel(Config.TrashModels, {
            options = {
                {
                    icon = 'fas fa-trash',
                    label = 'Ieškoti šiukšlėse',
                    canInteract = function()
                        return not miningBusy
                    end,
                    action = function(entity)
                        TriggerEvent('mrp_mining:client:searchTrash', { entity = entity })
                    end,
                },
            },
            distance = 2.0,
        })
    end
end)

RegisterNetEvent('mrp_mining:client:openCleanMenu', function()
    openCleanMenu()
end)

RegisterNetEvent('mrp_mining:client:openSmeltMenu', function()
    openSmeltMenu()
end)

--- Atgalinis suderinamumas
RegisterNetEvent('mrp_mining:client:openProcessMenu', function()
    openCleanMenu()
end)

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do Wait(300) end
    local cfg = Config.SellPed
    local c = cfg.coords
    loadModel(cfg.model)
    sellPed = CreatePed(4, cfg.model, c.x, c.y, c.z - 1.0, c.w, false, true)
    SetEntityAsMissionEntity(sellPed, true, true)
    SetBlockingOfNonTemporaryEvents(sellPed, true)
    FreezeEntityPosition(sellPed, true)
    SetEntityInvincible(sellPed, true)
    if cfg.scenario then
        TaskStartScenarioInPlace(sellPed, cfg.scenario, 0, true)
    end

    exports['qb-target']:AddTargetEntity(sellPed, {
        options = {
            {
                type = 'client',
                event = 'mrp_mining:client:openSellMenu',
                icon = 'fas fa-dollar-sign',
                label = 'Žaliavų / metalų supirkėjas',
            },
        },
        distance = 2.5,
    })
end)

RegisterNetEvent('mrp_mining:client:openSellMenu', function()
    openSellMenu()
end)
