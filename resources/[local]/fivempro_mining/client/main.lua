local QBCore = exports['qb-core']:GetCoreObject()
local sellPed = nil

local function loadModel(hash)
    RequestModel(hash)
    while not HasModelLoaded(hash) do Wait(10) end
end

local function openSellMenu()
    local rows = {
        { header = 'Metalų supirkimas', txt = 'Kainos už 1 vnt. — apačioje „Parduoti viską“.', isMenuHeader = true },
    }
    local sorted = {}
    for item, price in pairs(Config.SellPrices or {}) do
        sorted[#sorted + 1] = { item = item, price = price }
    end
    table.sort(sorted, function(a, b) return tostring(a.item) < tostring(b.item) end)
    for _, row in ipairs(sorted) do
        local it = QBCore.Shared.Items[row.item]
        local label = it and it.label or row.item
        rows[#rows + 1] = {
            header = ('%s — $%s / vnt.'):format(label, row.price),
            txt = row.item,
            isMenuHeader = true,
        }
    end
    rows[#rows + 1] = {
        header = 'Parduoti viską',
        txt = 'Visus šių žaliavų stackus iškart',
        params = {
            isAction = true,
            event = function()
                TriggerServerEvent('fivempro_mining:server:sellAll')
            end,
        },
    }
    TriggerEvent('qb-menu:client:openMenu', rows, false, true)
end

local function openProcessMenu()
    local rows = {
        {
            header = 'Rūdų perdirbimas',
            txt = 'Žalia → švari (pagal sąrašą)',
            isMenuHeader = true,
        },
        {
            header = 'Perdirbti visas žalias rūdas',
            txt = 'Vienetuose pagal inventorių',
            params = {
                isAction = true,
                event = function()
                    TriggerServerEvent('fivempro_mining:server:processBatch')
                end,
            },
        },
        {
            header = 'Gaminti plieną',
            txt = '2x geležies rūda + 1x anglis → 1 plienas',
            params = {
                isAction = true,
                event = function()
                    TriggerServerEvent('fivempro_mining:server:makeSteel')
                end,
            },
        },
    }
    TriggerEvent('qb-menu:client:openMenu', rows, false, true)
end

RegisterNetEvent('fivempro_mining:client:startMining', function(data)
    local siteIdx = data and tonumber(data.siteIndex)
    if not siteIdx then return end
    if not QBCore.Functions.HasItem('mining_pickaxe', 1) then
        return QBCore.Functions.Notify('Reikia kirtiklio.', 'error')
    end

    QBCore.Functions.Progressbar('fivempro_mining', 'Skaldai akmenį…', Config.MineDuration or 8500, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {
        animDict = 'amb@world_human_hammering@male@base',
        anim = 'hammer_loop',
        flags = 49,
    }, {}, {}, function()
        TriggerServerEvent('fivempro_mining:server:mineAttempt', siteIdx)
    end, function()
        QBCore.Functions.Notify('Atšaukta.', 'error')
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
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(mb.label or 'Karjeras')
        EndTextCommandSetBlipName(b)
    end

    local pb = Config.Blips.process
    local pc = Config.ProcessCoords
    if pc and pb then
        local b = AddBlipForCoord(pc.x, pc.y, pc.z)
        SetBlipSprite(b, pb.sprite or 566)
        SetBlipColour(b, pb.colour or 47)
        SetBlipScale(b, pb.scale or 0.82)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(pb.label or 'Perdirbimas')
        EndTextCommandSetBlipName(b)
    end

    local sb = Config.Blips.sell
    local sc = Config.SellPed.coords
    if sc and sb then
        local b = AddBlipForCoord(sc.x, sc.y, sc.z)
        SetBlipSprite(b, sb.sprite or 500)
        SetBlipColour(b, sb.colour or 2)
        SetBlipScale(b, sb.scale or 0.82)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(sb.label or 'Supirkimas')
        EndTextCommandSetBlipName(b)
    end
end)

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do Wait(300) end

    for i, site in ipairs(Config.MiningSites or {}) do
        exports['qb-target']:AddCircleZone(('fivempro_mine_%s'):format(i), site.coords, site.radius or 85.0, {
            name = ('fivempro_mine_%s'):format(i),
            debugPoly = false,
            useZ = true,
        }, {
            options = {
                {
                    type = 'client',
                    event = 'fivempro_mining:client:startMining',
                    icon = 'fas fa-hammer',
                    label = site.label or 'Skaldyti / kasti',
                    siteIndex = i,
                    canInteract = function()
                        return QBCore.Functions.HasItem('mining_pickaxe', 1)
                    end,
                },
            },
            distance = 3.2,
        })
    end

    local pc = Config.ProcessCoords
    exports['qb-target']:AddBoxZone('fivempro_mining_process', vector3(pc.x, pc.y, pc.z), 2.4, 2.4, {
        name = 'fivempro_mining_process',
        heading = pc.w or 0,
        debugPoly = false,
        minZ = pc.z - 1.2,
        maxZ = pc.z + 2.4,
    }, {
        options = {
            {
                type = 'client',
                event = 'fivempro_mining:client:openProcessMenu',
                icon = 'fas fa-industry',
                label = 'Perdirbti rūdas',
            },
        },
        distance = 2.5,
    })
end)

RegisterNetEvent('fivempro_mining:client:openProcessMenu', function()
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
                event = 'fivempro_mining:client:openSellMenu',
                icon = 'fas fa-dollar-sign',
                label = 'Supirkėjas — kainos ir pardavimas',
            },
        },
        distance = 2.5,
    })
end)

RegisterNetEvent('fivempro_mining:client:openSellMenu', function()
    openSellMenu()
end)
