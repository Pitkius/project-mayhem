local QBCore = exports['qb-core']:GetCoreObject()

local function isMechanicOnDuty()
    local P = QBCore.Functions.GetPlayerData()
    return P and P.job and P.job.name == Config.JobName and P.job.onduty
end

local function getVehicleInBay(bay)
    if not bay or not bay.coords then return 0 end
    local c = bay.coords
    local cx, cy, cz = c.x, c.y, c.z
    local maxR = (math.max(tonumber(bay.length) or 6, tonumber(bay.width) or 6) * 0.45) + 1.2
    local best, bestD = 0, maxR + 1.0
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if veh and veh ~= 0 and DoesEntityExist(veh) then
            local p = GetEntityCoords(veh)
            local d = #(vector3(p.x, p.y, p.z) - vector3(cx, cy, cz))
            if d <= maxR and d < bestD then
                best, bestD = veh, d
            end
        end
    end
    return best
end

local function doQuickRepair(veh)
    if veh == 0 or not DoesEntityExist(veh) then return end
    SetVehicleEngineHealth(veh, 1000.0)
    SetVehicleBodyHealth(veh, 1000.0)
    SetVehiclePetrolTankHealth(veh, 1000.0)
    SetVehicleFixed(veh)
    SetVehicleDeformationFixed(veh)
    QBCore.Functions.Notify('Transportas suremontuotas.', 'success')
end

local function ensureModKit(veh)
    if veh == 0 then return end
    SetVehicleModKit(veh, 0)
end

--- Kėbulo kategorijos (LSC stilius)
local BODY_MODS = {
    { id = 0, label = 'Spoileriai' },
    { id = 1, label = 'Priekinis buferis' },
    { id = 2, label = 'Galinis buferis' },
    { id = 3, label = 'Šonai (sijonai)' },
    { id = 4, label = 'Išmetimas' },
    { id = 5, label = 'Rėmas / kėbulas' },
    { id = 6, label = 'Grotelės' },
    { id = 7, label = 'Gaubtas' },
    { id = 8, label = 'Sparnai (priek.)' },
    { id = 9, label = 'Sparnai (gal.)' },
    { id = 10, label = 'Stogas' },
}

--- Variklis / važiuoklė (patobulinimai)
local PERF_MODS = {
    { id = 11, label = 'Variklis' },
    { id = 12, label = 'Stabdžiai' },
    { id = 13, label = 'Pavarų dėžė' },
    { id = 15, label = 'Pakaba' },
    { id = 16, label = 'Šarvai' },
}

local COLOR_PRESETS = {
    { label = 'Juoda', pri = 0, sec = 0 },
    { label = 'Balta', pri = 111, sec = 111 },
    { label = 'Sidabras', pri = 4, sec = 4 },
    { label = 'Raudona', pri = 27, sec = 27 },
    { label = 'Mėlyna', pri = 64, sec = 64 },
    { label = 'Žalia', pri = 55, sec = 55 },
    { label = 'Geltona', pri = 88, sec = 88 },
    { label = 'Oranžinė', pri = 38, sec = 38 },
}

--- Visi GTA variantai sąraše — paspaudus iškart matai ant mašinos (kaip LSC pasirinkimas).
local function openModVariantMenu(veh, modType, categoryLabel, bayIndex)
    ensureModKit(veh)
    local n = GetNumVehicleMods(veh, modType)
    local menu = {
        {
            header = categoryLabel,
            txt = 'Pasirink dalį — iškart rodoma ant transporto. qb-menu neturi hover.',
            isMenuHeader = true,
        },
    }

    if n <= 0 then
        menu[#menu + 1] = {
            header = 'Nėra variantų',
            txt = 'Šiai mašinai ši kategorija netinka.',
            params = {
                isAction = true,
                event = function()
                    TriggerEvent('fivempro_mechanic:client:openBodyWorkshop', { bayIndex = bayIndex })
                end,
            },
        }
        TriggerEvent('qb-menu:client:openMenu', menu, false, true)
        return
    end

    menu[#menu + 1] = {
        header = 'Gamyklinis (nuimti)',
        txt = 'Standartinė dalis',
        params = {
            isAction = true,
            event = function()
                SetVehicleMod(veh, modType, -1, false)
                QBCore.Functions.Notify('Gamyklinis variantas.', 'primary')
            end,
        },
    }

    for i = 0, n - 1 do
        local idx = i
        menu[#menu + 1] = {
            header = ('%s — variantas %s / %s'):format(categoryLabel, idx + 1, n),
            txt = 'Pritaikyti ir peržiūrėti',
            params = {
                isAction = true,
                event = function()
                    SetVehicleMod(veh, modType, idx, false)
                    QBCore.Functions.Notify(('Įdiegta: %s #%s'):format(categoryLabel, idx + 1), 'success')
                end,
            },
        }
    end

    menu[#menu + 1] = {
        header = 'Atgal',
        params = {
            isAction = true,
            event = function()
                TriggerEvent('fivempro_mechanic:client:openBodyWorkshop', { bayIndex = bayIndex })
            end,
        },
    }
    TriggerEvent('qb-menu:client:openMenu', menu, false, true)
end

local function openTurboMenu(veh, bayIndex)
    local menu = {
        { header = 'Turbo', txt = 'Įjungti ar išjungti', isMenuHeader = true },
        {
            header = 'Perjungti turbo',
            txt = 'Įdėtas / nuimtas',
            params = {
                isAction = true,
                event = function()
                    ensureModKit(veh)
                    local on = IsToggleModOn(veh, 18)
                    ToggleVehicleMod(veh, 18, not on)
                    QBCore.Functions.Notify(on and 'Turbo nuimtas.' or 'Turbo įdiegtas.', 'success')
                end,
            },
        },
        {
            header = 'Atgal',
            params = {
                isAction = true,
                event = function()
                    TriggerEvent('fivempro_mechanic:client:openPerformanceWorkshop', { bayIndex = bayIndex })
                end,
            },
        },
    }
    TriggerEvent('qb-menu:client:openMenu', menu, false, true)
end

RegisterNetEvent('fivempro_mechanic:client:openPerformanceWorkshop', function(data)
    local bayIndex = data and tonumber(data.bayIndex)
    local bay = bayIndex and Config.RepairBays and Config.RepairBays[bayIndex]
    if not bay then return end
    local veh = getVehicleInBay(bay)
    if veh == 0 then return QBCore.Functions.Notify('Remonto zonoje nėra transporto.', 'error') end

    local menu = {
        {
            header = 'Patobulinimai',
            txt = 'Variklis, stabdžiai, pavarų dėžė, pakaba, šarvai, turbo',
            isMenuHeader = true,
        },
    }
    for _, g in ipairs(PERF_MODS) do
        local mid = g.id
        menu[#menu + 1] = {
            header = g.label,
            txt = 'Atidaryti visus variantus',
            params = {
                isAction = true,
                event = function()
                    openModVariantMenu(veh, mid, g.label, bayIndex)
                end,
            },
        }
    end
    menu[#menu + 1] = {
        header = 'Turbo (įjungti / išjungti)',
        txt = 'Atskiras įrengimas',
        params = {
            isAction = true,
            event = function()
                openTurboMenu(veh, bayIndex)
            end,
        },
    }
    menu[#menu + 1] = {
        header = 'Atgal į dirbtuves',
        params = {
            isAction = true,
            event = function()
                TriggerEvent('fivempro_mechanic:client:openBayWorkshop', { bayIndex = bayIndex })
            end,
        },
    }
    TriggerEvent('qb-menu:client:openMenu', menu, false, true)
end)

RegisterNetEvent('fivempro_mechanic:client:openBodyWorkshop', function(data)
    local bayIndex = data and tonumber(data.bayIndex)
    local bay = bayIndex and Config.RepairBays and Config.RepairBays[bayIndex]
    if not bay then return end
    local veh = getVehicleInBay(bay)
    if veh == 0 then return QBCore.Functions.Notify('Remonto zonoje nėra transporto.', 'error') end

    local menu = {
        {
            header = 'Kėbulo detalės',
            txt = 'Pasirink kategoriją — tada konkretų spoilerį/buferį ir t. t.',
            isMenuHeader = true,
        },
    }
    for _, g in ipairs(BODY_MODS) do
        local mid = g.id
        menu[#menu + 1] = {
            header = g.label,
            txt = 'Rodyti visus variantus šiai daliai',
            params = {
                isAction = true,
                event = function()
                    openModVariantMenu(veh, mid, g.label, bayIndex)
                end,
            },
        }
    end
    menu[#menu + 1] = {
        header = 'Atgal į dirbtuves',
        params = {
            isAction = true,
            event = function()
                TriggerEvent('fivempro_mechanic:client:openBayWorkshop', { bayIndex = bayIndex })
            end,
        },
    }
    TriggerEvent('qb-menu:client:openMenu', menu, false, true)
end)

local function openColorMenu(veh, bayIndex)
    local menu = { { header = 'Dažymas', txt = 'Pagrindinė / antrinė spalva', isMenuHeader = true } }
    for _, c in ipairs(COLOR_PRESETS) do
        menu[#menu + 1] = {
            header = c.label,
            params = {
                isAction = true,
                event = function()
                    SetVehicleColours(veh, c.pri, c.sec)
                    local pearlescent, wh = GetVehicleExtraColours(veh)
                    SetVehicleExtraColours(veh, pearlescent, wh)
                    QBCore.Functions.Notify('Spalvos pritaikytos.', 'primary')
                end,
            },
        }
    end
    menu[#menu + 1] = {
        header = 'Atgal',
        params = {
            isAction = true,
            event = function()
                TriggerEvent('fivempro_mechanic:client:openBayWorkshop', { bayIndex = bayIndex })
            end,
        },
    }
    TriggerEvent('qb-menu:client:openMenu', menu, false, true)
end

RegisterNetEvent('fivempro_mechanic:client:openBayWorkshop', function(data)
    if not isMechanicOnDuty() then
        return QBCore.Functions.Notify('Tik mechanikams tarnyboje.', 'error')
    end
    if GetResourceState('qb-menu') ~= 'started' then
        return QBCore.Functions.Notify('Reikia qb-menu.', 'error')
    end

    local bayIndex = data and tonumber(data.bayIndex)
    local bay = bayIndex and Config.RepairBays and Config.RepairBays[bayIndex]
    if not bay then return end

    local veh = getVehicleInBay(bay)
    if veh == 0 then
        return QBCore.Functions.Notify('Remonto zonoje nėra transporto.', 'error')
    end

    local plate = QBCore.Functions.GetPlate(veh)
    if not plate or plate == '' then
        return QBCore.Functions.Notify('Nerasta valstybinė numeracija.', 'error')
    end

    local function saveTune()
        ensureModKit(veh)
        local props = QBCore.Functions.GetVehicleProperties(veh)
        if props then
            props.plate = plate
        end
        TriggerServerEvent('fivempro_mechanic:server:saveBayVehicleTune', bayIndex, props)
    end

    local menu = {
        {
            header = ('Los Santos Customs — %s'):format(plate),
            txt = 'Pasirink skyrių',
            isMenuHeader = true,
        },
        {
            header = 'Remontas',
            txt = 'Korpusas, variklis, deformacija',
            params = {
                isAction = true,
                event = function()
                    doQuickRepair(veh)
                end,
            },
        },
        {
            header = 'Dažymas',
            txt = 'Spalvų presetai',
            params = {
                isAction = true,
                event = function()
                    openColorMenu(veh, bayIndex)
                end,
            },
        },
        {
            header = 'Patobulinimai',
            txt = 'Variklis, stabdžiai, pavarų dėžė, pakaba, šarvai, turbo',
            params = {
                isAction = true,
                event = function()
                    TriggerEvent('fivempro_mechanic:client:openPerformanceWorkshop', { bayIndex = bayIndex })
                end,
            },
        },
        {
            header = 'Kėbulo detalės',
            txt = 'Spoileriai, buferiai, gaubtas…',
            params = {
                isAction = true,
                event = function()
                    TriggerEvent('fivempro_mechanic:client:openBodyWorkshop', { bayIndex = bayIndex })
                end,
            },
        },
        {
            header = 'Išsaugoti modifikacijas (DB)',
            txt = 'player_vehicles — savininko mašina',
            params = {
                isAction = true,
                event = function()
                    saveTune()
                end,
            },
        },
    }
    TriggerEvent('qb-menu:client:openMenu', menu, false, true)
end)
