local QBCore = exports['qb-core']:GetCoreObject()

local zones = {}
local vaultOpen = {} --- [locId] = true
local drilled = {} --- [boxKey] = true

local function depositCfg()
    return Config.Robberies.Deposit or {}
end

local function boxKey(locId, index)
    return ('%s:%d'):format(tostring(locId), tonumber(index) or 0)
end

local function removeZones()
    for name in pairs(zones) do
        pcall(function() exports['qb-target']:RemoveZone(name) end)
    end
    zones = {}
end

--- Pastato žaidėją priešais dėžutę (kaip Fleeca cutscene pozicija)
local function faceBox(box)
    local ped = PlayerPedId()
    local c = box.coords
    local h = box.heading or 0.0
    local rad = math.rad(h)
    --- Stovėti šiek tiek priešais dėžutę, žiūrėti į ją
    local stand = vector3(
        c.x + (-math.sin(rad)) * -0.55,
        c.y + (math.cos(rad)) * -0.55,
        c.z
    )
    SetEntityCoordsNoOffset(ped, stand.x, stand.y, stand.z, false, false, false)
    SetEntityHeading(ped, h)
    FreezeEntityPosition(ped, true)
end

local function drillBox(locId, index)
    QBCore.Functions.TriggerCallback('mrp_hacking:server:depositCanDrill', function(res)
        if not res or not res.ok then
            return QBCore.Functions.Notify((res and res.msg) or 'Negalima.', 'error')
        end

        local list = (Config.Robberies.DepositBoxes or {})[tostring(locId)]
        local box = list and list[tonumber(index)]
        if not box then return end

        SetCurrentPedWeapon(PlayerPedId(), `WEAPON_UNARMED`, true)
        faceBox(box)

        local anim = (Config.RobberyAnims or {}).drill
        --- Tikras GTA Online DRILLING scaleform + Fleeca drill anim (be pinigų propo)
        local ok = exports['mrp_hacking']:RunPhysicalMinigame('native_drill', {
            label = 'Deposit dėžutė — GTA Online gręžimas',
            anim = anim,
            data = {},
        })

        FreezeEntityPosition(PlayerPedId(), false)

        if not ok then
            return QBCore.Functions.Notify('Gręžimas atšauktas.', 'error')
        end

        TriggerServerEvent('mrp_hacking:server:depositDrilled', locId, index)
    end, locId, index)
end

local function registerDepositZones()
    removeZones()
    if GetResourceState('qb-target') ~= 'started' then return end
    for locId, list in pairs(Config.Robberies.DepositBoxes or {}) do
        for i, box in ipairs(list) do
            local zoneName = ('hack_deposit_%s_%d'):format(locId, i)
            zones[zoneName] = true
            local key = boxKey(locId, i)
            exports['qb-target']:AddCircleZone(zoneName, box.coords, 0.55, {
                name = zoneName,
                debugPoly = false,
                useZ = true,
            }, {
                options = {
                    {
                        icon = 'fas fa-box',
                        label = 'Gręžti deposit dėžutę (GTA Online)',
                        canInteract = function()
                            if not vaultOpen[tostring(locId)] then return false end
                            if drilled[key] then return false end
                            return QBCore.Functions.HasItem(Config.SmallDrillItem or 'small_drill', 1)
                        end,
                        action = function()
                            drillBox(locId, i)
                        end,
                    },
                },
                distance = 1.6,
            })
        end
    end
end

local function applyState(locId, open, drilledMap)
    locId = tostring(locId or '')
    vaultOpen[locId] = open == true
    if drilledMap then
        for k, v in pairs(drilledMap) do
            if v then drilled[k] = true end
        end
    end
end

RegisterNetEvent('mrp_hacking:client:depositVaultState', function(locId, open, drilledMap)
    applyState(locId, open, drilledMap)
    if open then
        QBCore.Functions.Notify('Žali markeriai = deposit dėžutės. Gręžimas kaip GTA Online (be pinigų ant stalo).', 'primary', 8000)
    end
end)

RegisterNetEvent('mrp_hacking:client:depositBoxDrilled', function(locId, index, key)
    drilled[key] = true
end)

--- Markeriai ant gręžiamų dėžučių
CreateThread(function()
    while true do
        local sleep = 750
        local ped = PlayerPedId()
        local p = GetEntityCoords(ped)
        local cfg = depositCfg()
        local mk = cfg.marker or {}

        for locId, list in pairs(Config.Robberies.DepositBoxes or {}) do
            if vaultOpen[tostring(locId)] then
                for i, box in ipairs(list) do
                    local key = boxKey(locId, i)
                    local c = box.coords
                    if #(p - c) < 35.0 then
                        sleep = 0
                        if not drilled[key] then
                            local col = mk.color or { r = 50, g = 220, b = 90, a = 200 }
                            DrawMarker(
                                mk.type or 20,
                                c.x, c.y, c.z + (mk.zOffset or 0.55),
                                0.0, 0.0, 0.0, 0.0, 180.0, 0.0,
                                mk.scale or 0.28, mk.scale or 0.28, mk.scale or 0.28,
                                col.r or 50, col.g or 220, col.b or 90, col.a or 200,
                                mk.bob ~= false, true, 2, false, nil, nil, false
                            )
                        end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

--- Sync kai priartėji prie banko
CreateThread(function()
    local lastNear = {}
    while true do
        local p = GetEntityCoords(PlayerPedId())
        for locId, list in pairs(Config.Robberies.DepositBoxes or {}) do
            local first = list[1]
            if first then
                local near = #(p - first.coords) < 60.0
                local id = tostring(locId)
                if near and not lastNear[id] then
                    lastNear[id] = true
                    QBCore.Functions.TriggerCallback('mrp_hacking:server:depositGetState', function(res)
                        if res then
                            applyState(id, res.open, res.drilled)
                        end
                    end, id)
                elseif not near then
                    lastNear[id] = nil
                end
            end
        end
        Wait(2000)
    end
end)

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do Wait(400) end
    Wait(1200)
    registerDepositZones()
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    removeZones()
end)
