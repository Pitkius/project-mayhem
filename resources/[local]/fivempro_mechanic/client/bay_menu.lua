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

--- qb-menu visada užsidaro paspaudus eilutę — vėl atidarome tą patį meniu, kol mechanikas neišsaugos ar neuždarys.
local function scheduleReopen(fn)
    CreateThread(function()
        Wait(100)
        fn()
    end)
end

--- GTA dažų tipai (Los Santos Customs): 0 klasikinės … 5 chromas
local PAINT_TYPES = {
    { paintType = 0, label = 'Klasikinės (Classic)', txt = 'Standartinis korpusinis dažymas' },
    { paintType = 1, label = 'Metinės (Metallic)', txt = 'Metalizuotas blizgesys' },
    { paintType = 2, label = 'Perlmutrinės (Pearl)', txt = 'Perlų / multicoat efektas' },
    { paintType = 3, label = 'Matinės (Matte)', txt = 'Nebliškantis matinis' },
    { paintType = 4, label = 'Metalas (Metal)', txt = 'Šiurkštus anoduotas metalas' },
    { paintType = 5, label = 'Chromas (Chrome)', txt = 'Veidrodinis chromas' },
}

local function applyUniformPaint(veh, paintType, colorIndex)
    if veh == 0 or not DoesEntityExist(veh) then return end
    ensureModKit(veh)
    ClearVehicleCustomPrimaryColour(veh)
    ClearVehicleCustomSecondaryColour(veh)
    local pearl, wheelCol = GetVehicleExtraColours(veh)
    pearl = pearl or 0
    SetVehicleColours(veh, colorIndex, colorIndex)
    SetVehicleModColor_1(veh, paintType, colorIndex, pearl)
    SetVehicleModColor_2(veh, paintType, colorIndex)
    SetVehicleExtraColours(veh, pearl, wheelCol)
end

local openPaintCategoryMenu

--- 2 žingsnis: galutinė spalva (indeksas tame GTA tipe)
local function openPaintColorMenu(veh, bayIndex, paintType, typeLabel)
    typeLabel = typeLabel or 'Spalva'
    local menu = {
        {
            header = ('%s — pasirink spalvą'):format(typeLabel),
            txt = 'Indeksai kaip GTA LSC. Peržiūra ant mašinos; DB tik paspaudus „Užbaigti darbą — išsaugoti klientui“ pagrindiniame meniu.',
            isMenuHeader = true,
        },
    }
    for ci = 0, 159 do
        local colorIndex = ci
        menu[#menu + 1] = {
            header = ('Indeksas %s / 159'):format(colorIndex),
            txt = ('Tipas %s — pritaikyti pagrindinę ir antrinę'):format(paintType),
            params = {
                isAction = true,
                event = function()
                    local b = bayIndex
                    local pt = paintType
                    local tl = typeLabel
                    applyUniformPaint(veh, pt, colorIndex)
                    QBCore.Functions.Notify(('Peržiūra: %s, indeksas %s'):format(tl, colorIndex), 'primary')
                    scheduleReopen(function()
                        local bay = b and Config.RepairBays and Config.RepairBays[b]
                        local v = bay and getVehicleInBay(bay) or 0
                        if v ~= 0 then openPaintColorMenu(v, b, pt, tl) end
                    end)
                end,
            },
        }
    end
    menu[#menu + 1] = {
        header = 'Atgal į dažų kategorijas',
        params = {
            isAction = true,
            event = function()
                local b = bayIndex
                scheduleReopen(function()
                    local bay = b and Config.RepairBays and Config.RepairBays[b]
                    local v = bay and getVehicleInBay(bay) or 0
                    if v ~= 0 then openPaintCategoryMenu(v, b) end
                end)
            end,
        },
    }
    TriggerEvent('qb-menu:client:openMenu', menu, false, true)
end

--- 1 žingsnis: GTA dažų kategorija (Classic, Metallic, …)
openPaintCategoryMenu = function(veh, bayIndex)
    local menu = {
        {
            header = 'Dažymas — kategorija',
            txt = 'Pasirink Los Santos Customs tipą, tada konkretų spalvos indeksą (0–159). Pagrindinė = antrinė.',
            isMenuHeader = true,
        },
    }
    for _, pt in ipairs(PAINT_TYPES) do
        local pType = pt.paintType
        local lab = pt.label
        local desc = pt.txt
        menu[#menu + 1] = {
            header = lab,
            txt = desc,
            params = {
                isAction = true,
                event = function()
                    local bay = bayIndex and Config.RepairBays and Config.RepairBays[bayIndex]
                    local v = bay and getVehicleInBay(bay) or 0
                    if v == 0 then
                        return QBCore.Functions.Notify('Remonto zonoje nėra transporto.', 'error')
                    end
                    openPaintColorMenu(v, bayIndex, pType, lab)
                end,
            },
        }
    end
    menu[#menu + 1] = {
        header = 'Atgal į dirbtuves',
        params = {
            isAction = true,
            event = function()
                scheduleReopen(function()
                    TriggerEvent('fivempro_mechanic:client:openBayWorkshop', { bayIndex = bayIndex })
                end)
            end,
        },
    }
    TriggerEvent('qb-menu:client:openMenu', menu, false, true)
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

local function openParentModShop(bayIndex, returnTo)
    if returnTo == 'performance' then
        TriggerEvent('fivempro_mechanic:client:openPerformanceWorkshop', { bayIndex = bayIndex })
    else
        TriggerEvent('fivempro_mechanic:client:openBodyWorkshop', { bayIndex = bayIndex })
    end
end

--- Visi GTA variantai sąraše — paspaudus iškart matai ant mašinos (kaip LSC pasirinkimas).
local function openModVariantMenu(veh, modType, categoryLabel, bayIndex, returnTo)
    returnTo = returnTo or 'body'
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
                    local b, rt = bayIndex, returnTo
                    scheduleReopen(function()
                        openParentModShop(b, rt)
                    end)
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
                local b = bayIndex
                local m = modType
                local lab = categoryLabel
                local rt = returnTo
                SetVehicleMod(veh, modType, -1, false)
                QBCore.Functions.Notify('Gamyklinis variantas.', 'primary')
                scheduleReopen(function()
                    local bay = b and Config.RepairBays and Config.RepairBays[b]
                    local v = bay and getVehicleInBay(bay) or 0
                    if v ~= 0 then openModVariantMenu(v, m, lab, b, rt) end
                end)
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
                    local b = bayIndex
                    local m = modType
                    local lab = categoryLabel
                    local rt = returnTo
                    SetVehicleMod(veh, modType, idx, false)
                    QBCore.Functions.Notify(('Įdiegta: %s #%s'):format(categoryLabel, idx + 1), 'success')
                    scheduleReopen(function()
                        local bay = b and Config.RepairBays and Config.RepairBays[b]
                        local v = bay and getVehicleInBay(bay) or 0
                        if v ~= 0 then openModVariantMenu(v, m, lab, b, rt) end
                    end)
                end,
            },
        }
    end

    menu[#menu + 1] = {
        header = 'Atgal',
        params = {
            isAction = true,
            event = function()
                local b, rt = bayIndex, returnTo
                scheduleReopen(function()
                    openParentModShop(b, rt)
                end)
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
                    local b = bayIndex
                    ensureModKit(veh)
                    local on = IsToggleModOn(veh, 18)
                    ToggleVehicleMod(veh, 18, not on)
                    QBCore.Functions.Notify(on and 'Turbo nuimtas.' or 'Turbo įdiegtas.', 'success')
                    scheduleReopen(function()
                        local bay = b and Config.RepairBays and Config.RepairBays[b]
                        local v = bay and getVehicleInBay(bay) or 0
                        if v ~= 0 then openTurboMenu(v, b) end
                    end)
                end,
            },
        },
        {
            header = 'Atgal',
            params = {
                isAction = true,
                event = function()
                    scheduleReopen(function()
                        TriggerEvent('fivempro_mechanic:client:openPerformanceWorkshop', { bayIndex = bayIndex })
                    end)
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
                    openModVariantMenu(veh, mid, g.label, bayIndex, 'performance')
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
                scheduleReopen(function()
                    TriggerEvent('fivempro_mechanic:client:openBayWorkshop', { bayIndex = bayIndex })
                end)
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
                    openModVariantMenu(veh, mid, g.label, bayIndex, 'body')
                end,
            },
        }
    end
    menu[#menu + 1] = {
        header = 'Atgal į dirbtuves',
        params = {
            isAction = true,
            event = function()
                scheduleReopen(function()
                    TriggerEvent('fivempro_mechanic:client:openBayWorkshop', { bayIndex = bayIndex })
                end)
            end,
        },
    }
    TriggerEvent('qb-menu:client:openMenu', menu, false, true)
end)

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
        local bayNow = bayIndex and Config.RepairBays and Config.RepairBays[bayIndex]
        local vNow = bayNow and getVehicleInBay(bayNow) or 0
        if vNow == 0 then
            return QBCore.Functions.Notify('Remonto zonoje nebėra transporto — neišsaugota.', 'error')
        end
        local plateNow = QBCore.Functions.GetPlate(vNow)
        if not plateNow or plateNow ~= plate then
            return QBCore.Functions.Notify('Kita mašina zonoje — patikrink numerius ir bandyk dar kartą.', 'error')
        end
        ensureModKit(vNow)
        local props = QBCore.Functions.GetVehicleProperties(vNow)
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
                    local b = bayIndex
                    doQuickRepair(veh)
                    scheduleReopen(function()
                        TriggerEvent('fivempro_mechanic:client:openBayWorkshop', { bayIndex = b })
                    end)
                end,
            },
        },
        {
            header = 'Dažymas',
            txt = 'GTA kategorijos (Classic, Metallic…), tada spalvos indeksas',
            params = {
                isAction = true,
                event = function()
                    openPaintCategoryMenu(veh, bayIndex)
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
            header = 'Užbaigti darbą — išsaugoti klientui',
            txt = 'Įrašoma į savininko transporto kortelę (duomenų bazėje). Meniu užsidarys.',
            params = {
                isAction = true,
                event = function()
                    saveTune()
                    QBCore.Functions.Notify('Pakeitimai užfiksuoti — klientas gaus atnaujintą mašiną iš garažo.', 'success')
                    TriggerEvent('qb-menu:client:closeMenu')
                end,
            },
        },
        {
            header = 'Uždaryti dirbtuves (be DB įrašo)',
            txt = 'Tik uždaro meniu; vizualūs pakeitimai lieka iki atnaujinimo / respawno.',
            params = {
                isAction = true,
                event = function()
                    TriggerEvent('qb-menu:client:closeMenu')
                    QBCore.Functions.Notify('Dirbtuvių meniu uždaryta. Nepamirškite išsaugoti, jei darbas baigtas.', 'primary')
                end,
            },
        },
    }
    TriggerEvent('qb-menu:client:openMenu', menu, false, true)
end)
