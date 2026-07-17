local QBCore = exports['qb-core']:GetCoreObject()

local PrinterProps = {}
local placing = false
local printing = false

local function notify(msg, typ)
    QBCore.Functions.Notify(msg, typ or 'primary')
end

local function cfg()
    return Config.Printer3d or {}
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 5000 do
        Wait(10)
        t = t + 10
    end
    return HasModelLoaded(hash)
end

local function deletePrinterProp(id)
    local ent = PrinterProps[id]
    if ent and DoesEntityExist(ent) then
        exports['qb-target']:RemoveTargetEntity(ent)
        DeleteEntity(ent)
    end
    PrinterProps[id] = nil
end

local function openPrintMenu(printerId)
    if printing then return end
    QBCore.Functions.TriggerCallback('mrp_drugs:server:getPrinterMenu', function(payload)
        local rows = payload
        local meta = nil
        if type(payload) == 'table' and payload.products then
            rows = payload.products
            meta = payload
        end
        if not rows or #rows == 0 then
            return notify('Spausdintuvas nepasiekiamas.', 'error')
        end
        local header = '3D spausdintuvas'
        if meta and meta.weaponPrints ~= nil then
            local nextNeed = (meta.weaponTier or 0) >= 2 and nil
                or ((meta.weaponTier or 0) >= 1 and meta.unlockL2At or meta.unlockL1At)
            if nextNeed then
                header = ('3D spausdintuvas · XP %d/%d'):format(meta.weaponPrints or 0, nextNeed)
            else
                header = ('3D spausdintuvas · XP %d (max)'):format(meta.weaponPrints or 0)
            end
        end
        local menu = {
            { header = header, isMenuHeader = true },
        }
        if meta and (meta.weaponTier or 0) < 1 then
            menu[#menu + 1] = {
                header = ('L1 ginklai po %d spausdinimų'):format(meta.unlockL1At or 10),
                txt = 'Kol kas gamink tik detales čia. Gamykla atrakins vėliau.',
                isMenuHeader = true,
            }
        elseif meta and (meta.weaponTier or 0) < 2 then
            menu[#menu + 1] = {
                header = ('Išplėstas rinkinys po %d spausdinimų'):format(meta.unlockL2At or 15),
                txt = 'Tec-9 · mažas shotgun · .50 · shotgun kulkos',
                isMenuHeader = true,
            }
        end
        for _, row in ipairs(rows) do
            local txt = table.concat(row.ingredients, ' · ')
            txt = txt .. (' · ~%ds'):format(row.timeSec)
            if not row.canCraft then
                txt = txt .. ' · trūksta medžiagų'
            end
            menu[#menu + 1] = {
                header = ('%s → %dx %s'):format(row.label, row.outputCount, row.outputLabel),
                txt = txt,
                disabled = not row.canCraft,
                params = {
                    isAction = true,
                    event = function()
                        TriggerEvent('qb-menu:client:closeMenu')
                        TriggerServerEvent('mrp_drugs:server:startPrinterCraft', printerId, row.id)
                    end,
                },
            }
        end
        menu[#menu + 1] = {
            header = 'Uždaryti',
            params = { isAction = true, event = function() TriggerEvent('qb-menu:client:closeMenu') end },
        }
        if GetResourceState('qb-menu') == 'started' then
            TriggerEvent('qb-menu:client:openMenu', menu, false, true)
        else
            notify('qb-menu neįkeltas.', 'error')
        end
    end, printerId)
end

local function refreshPrinterTargets()
    for id, obj in pairs(PrinterProps) do
        if obj and DoesEntityExist(obj) then
            exports['qb-target']:RemoveTargetEntity(obj)
            exports['qb-target']:AddTargetEntity(obj, {
                options = {
                    {
                        icon = 'fas fa-print',
                        label = 'Spausdinti dalis',
                        action = function()
                            openPrintMenu(id)
                        end,
                    },
                    {
                        icon = 'fas fa-box',
                        label = 'Surinkti spausdintuvą',
                        action = function()
                            TriggerServerEvent('mrp_drugs:server:pickupPrinter', id)
                        end,
                    },
                },
                distance = cfg().interactDist or 2.4,
            })
        end
    end
end

local function spawnPrinter(printer)
    if not printer or not printer.id then return end
    deletePrinterProp(printer.id)
    local model = cfg().propModel or 'prop_printer_01'
    if not loadModel(model) then return end

    local obj = CreateObject(joaat(model), printer.x, printer.y, printer.z, false, false, false)
    SetEntityHeading(obj, printer.heading or 0.0)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)

    PrinterProps[printer.id] = obj
    SetModelAsNoLongerNeeded(joaat(model))
end

RegisterNetEvent('mrp_drugs:client:syncPrinters', function(list)
    for id in pairs(PrinterProps) do
        deletePrinterProp(id)
    end
    for _, printer in ipairs(list or {}) do
        spawnPrinter(printer)
    end
    Wait(200)
    refreshPrinterTargets()
end)

RegisterNetEvent('mrp_drugs:client:startPlacePrinter', function()
    if placing or printing then return end
    local model = cfg().propModel or 'prop_printer_01'
    if not loadModel(model) then
        return notify('Modelis nerastas.', 'error')
    end

    placing = true
    local ped = PlayerPedId()
    local preview = CreateObject(joaat(model), 0.0, 0.0, 0.0, false, false, false)
    SetEntityAlpha(preview, 180, false)
    SetEntityCollision(preview, false, false)
    FreezeEntityPosition(preview, true)

    notify('[E] Padėti · [SCROLL] Sukti · [BACKSPACE] Atšaukti', 'primary')

    CreateThread(function()
        local heading = GetEntityHeading(ped)
        while placing do
            Wait(0)
            local c = GetEntityCoords(ped)
            local fwd = GetEntityForwardVector(ped)
            local pos = c + fwd * 1.35
            SetEntityCoords(preview, pos.x, pos.y, pos.z, false, false, false, false)
            PlaceObjectOnGroundProperly(preview)
            if IsControlPressed(0, 241) then heading = heading + 1.2 end
            if IsControlPressed(0, 242) then heading = heading - 1.2 end
            SetEntityHeading(preview, heading)

            if IsControlJustPressed(0, 177) then
                placing = false
            elseif IsControlJustPressed(0, 38) then
                local fc = GetEntityCoords(preview)
                local fh = GetEntityHeading(preview)
                placing = false
                TriggerServerEvent('mrp_drugs:server:placePrinter', fc.x, fc.y, fc.z, fh)
            end
        end
        if DoesEntityExist(preview) then DeleteEntity(preview) end
        SetModelAsNoLongerNeeded(joaat(model))
    end)
end)

RegisterNetEvent('mrp_drugs:client:printerCraftStarted', function(printerId, productId, timeMs)
    if printing then return end
    printing = true
    local duration = tonumber(timeMs) or 30000
    local label = 'Spausdinama…'

    DrugProgress.run('mrp_3d_print', label, duration, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableCombat = true,
    }, {
        animDict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
        anim = 'machinic_loop_mechandplayer',
        flags = 49,
    }, function()
        printing = false
        TriggerServerEvent('mrp_drugs:server:finishPrinterCraft', printerId, productId)
    end, function()
        printing = false
        TriggerServerEvent('mrp_drugs:server:cancelPrinterCraft')
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(PrinterProps) do
        deletePrinterProp(id)
    end
end)
