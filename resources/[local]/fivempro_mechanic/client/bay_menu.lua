local QBCore = exports['qb-core']:GetCoreObject()

local function isMechanicOnDuty()
    local P = QBCore.Functions.GetPlayerData()
    return P and P.job and P.job.name == Config.JobName and P.job.onduty
end

--- Transportas remonto zonoje (artimiausias centre).
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

local MOD_GROUPS = {
    { id = 0, label = 'Spoileriai' },
    { id = 1, label = 'Priekinis buferis' },
    { id = 2, label = 'Galinis buferis' },
    { id = 3, label = 'Šonai (sijonai)' },
    { id = 4, label = 'Išmetimas' },
    { id = 7, label = 'Gaubtas' },
    { id = 10, label = 'Stogas' },
    { id = 11, label = 'Variklis' },
    { id = 12, label = 'Stabdžiai' },
    { id = 13, label = 'Pavarų dėžė' },
    { id = 15, label = 'Pakaba' },
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

local function ensureModKit(veh)
    if veh == 0 then return end
    SetVehicleModKit(veh, 0)
end

local function cycleMod(veh, modType)
    ensureModKit(veh)
    local n = GetNumVehicleMods(veh, modType)
    if n <= 0 then
        return QBCore.Functions.Notify('Šiai mašinai nėra variantų.', 'error')
    end
    local cur = GetVehicleMod(veh, modType)
    local nxt
    if cur == -1 then
        nxt = 0
    elseif cur < n - 1 then
        nxt = cur + 1
    else
        nxt = -1
    end
    SetVehicleMod(veh, modType, nxt, false)
    QBCore.Functions.Notify(('Detalė #%s: variantas %s.'):format(modType, tostring(nxt)), 'success')
end

local function openModCategoryMenu(veh, title, bayIndex)
    local menu = { { header = title, isMenuHeader = true } }
    for _, g in ipairs(MOD_GROUPS) do
        menu[#menu + 1] = {
            header = g.label,
            txt = 'Kitas variantas (po kelių paspaudimų – gamyklinis)',
            params = {
                isAction = true,
                event = function()
                    cycleMod(veh, g.id)
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

local function openColorMenu(veh, bayIndex)
    local menu = { { header = 'Spalvos (preset)', isMenuHeader = true } }
    for _, c in ipairs(COLOR_PRESETS) do
        menu[#menu + 1] = {
            header = c.label,
            params = {
                isAction = true,
                event = function()
                    SetVehicleColours(veh, c.pri, c.sec)
                    local pearlescent, wh = GetVehicleExtraColours(veh)
                    SetVehicleExtraColours(veh, pearlescent, wh)
                    QBCore.Functions.Notify('Spalvos pritaikytos (išsaugok pagrindiniame meniu).', 'primary')
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
        { header = ('Dirbtuvės #%s — %s'):format(bayIndex, plate), isMenuHeader = true },
        {
            header = 'Greitas pilnas remontas',
            txt = 'Korpusas, variklis, deformacija',
            params = {
                isAction = true,
                event = function()
                    doQuickRepair(veh)
                end,
            },
        },
        {
            header = 'Spalvos (presetai)',
            txt = 'Pagrindinė / antrinė',
            params = {
                isAction = true,
                event = function()
                    openColorMenu(veh, bayIndex)
                end,
            },
        },
        {
            header = 'Kėbulo ir mechanikos detalės',
            txt = 'Modifikacijos pagal kategoriją',
            params = {
                isAction = true,
                event = function()
                    openModCategoryMenu(veh, ('Detalės — %s'):format(plate), bayIndex)
                end,
            },
        },
        {
            header = 'Išsaugoti į DB (savininko mašina)',
            txt = 'Įrašo mods į player_vehicles',
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
