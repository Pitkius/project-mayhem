local QBCore = exports['qb-core']:GetCoreObject()
local sellPed = nil
local miningBusy = false
local sellUiOpen = false
local pendingWallIdx = nil

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

local function playSellAnim(ms)
    local ped = PlayerPedId()
    loadAnimDict('mp_common')
    TaskPlayAnim(ped, 'mp_common', 'givetake1_a', 8.0, -8.0, ms or 2500, 49, 0, false, false, false)
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

local function openProcessMenu()
    local rows = {
        { header = 'Rūdų perdirbimas', txt = 'Žalia → švari (pagal sąrašą)', isMenuHeader = true },
        {
            header = 'Perdirbti visas žalias rūdas',
            txt = 'Vienetuose pagal inventorių',
            params = {
                isAction = true,
                event = function()
                    TriggerServerEvent('mrp_mining:server:processBatch')
                end,
            },
        },
        {
            header = 'Gaminti plieną',
            txt = '2x geležies rūda + 1x anglis → 1 plienas',
            params = {
                isAction = true,
                event = function()
                    TriggerServerEvent('mrp_mining:server:makeSteel')
                end,
            },
        },
    }
    TriggerEvent('qb-menu:client:openMenu', rows, false, true)
end

RegisterNetEvent('mrp_mining:client:startMining', function(data)
    if miningBusy then return end
    local wallIdx = data and tonumber(data.wallIndex)
    if not wallIdx then return end
    if not playerHasMiningPickaxe() then
        return QBCore.Functions.Notify('Reikia kasyklos kirtiklio.', 'error')
    end

    pendingWallIdx = wallIdx
    miningBusy = true
    setMiningUi(true)
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
    local mb = Config.Blips.mining
    local center = Config.MiningSites[1] and Config.MiningSites[1].coords
    if center and mb then
        local b = AddBlipForCoord(center.x, center.y, center.z)
        SetBlipSprite(b, mb.sprite or 618)
        SetBlipColour(b, mb.colour or 47)
        SetBlipScale(b, mb.scale or 0.85)
        SetBlipAsShortRange(b, true)
        exports['mrp_fonts']:SetBlipName(b, mb.label or 'Karjeras')
    end

    local pb = Config.Blips.process
    local pc = Config.ProcessCoords
    if pc and pb then
        local b = AddBlipForCoord(pc.x, pc.y, pc.z)
        SetBlipSprite(b, pb.sprite or 566)
        SetBlipColour(b, pb.colour or 47)
        SetBlipScale(b, pb.scale or 0.82)
        SetBlipAsShortRange(b, true)
        exports['mrp_fonts']:SetBlipName(b, pb.label or 'Perdirbimas')
    end

    local sb = Config.Blips.sell
    local sc = Config.SellPed.coords
    if sc and sb then
        local b = AddBlipForCoord(sc.x, sc.y, sc.z)
        SetBlipSprite(b, sb.sprite or 500)
        SetBlipColour(b, sb.colour or 2)
        SetBlipScale(b, sb.scale or 0.82)
        SetBlipAsShortRange(b, true)
        exports['mrp_fonts']:SetBlipName(b, sb.label or 'Supirkimas')
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

    local pc = Config.ProcessCoords
    exports['qb-target']:AddBoxZone('mrp_mining_process', vector3(pc.x, pc.y, pc.z), 2.4, 2.4, {
        name = 'mrp_mining_process',
        heading = pc.w or 0,
        debugPoly = false,
        minZ = pc.z - 1.2,
        maxZ = pc.z + 2.4,
    }, {
        options = {
            {
                type = 'client',
                event = 'mrp_mining:client:openProcessMenu',
                icon = 'fas fa-industry',
                label = 'Perdirbti rūdas',
            },
        },
        distance = 2.5,
    })
end)

RegisterNetEvent('mrp_mining:client:openProcessMenu', function()
    openProcessMenu()
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
                label = 'Rūdų supirkėjas',
            },
        },
        distance = 2.5,
    })
end)

RegisterNetEvent('mrp_mining:client:openSellMenu', function()
    openSellMenu()
end)
