local QBCore = exports['qb-core']:GetCoreObject()
local vendorPed = nil
local tabletOpen = false
local tabletProp = nil

local function getCurrentTurfId()
    local ped = PlayerPedId()
    local p = GetEntityCoords(ped)
    for turfId, turf in pairs(Config.Turfs or {}) do
        local c = turf.center
        local d = #(p - vector3(c.x, c.y, c.z))
        if d <= (turf.radius or 150.0) then
            return turfId, turf
        end
    end
    return nil, nil
end

local function stopTabletAnim()
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    if tabletProp and DoesEntityExist(tabletProp) then
        DeleteEntity(tabletProp)
    end
    tabletProp = nil
end

local function playTabletAnim()
    local ped = PlayerPedId()
    local dict = 'amb@world_human_seat_wall_tablet@female@base'
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(0) end
    TaskPlayAnim(ped, dict, 'base', 8.0, -8.0, -1, 49, 0, false, false, false)
    local model = joaat('prop_cs_tablet')
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(0) end
    tabletProp = CreateObject(model, 1.0, 1.0, 1.0, true, true, false)
    AttachEntityToEntity(tabletProp, ped, GetPedBoneIndex(ped, 60309), 0.03, 0.002, 0.0, 10.0, 160.0, 0.0, true, true, false, true, 1, true)
end

local function closeTabletUi()
    tabletOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    stopTabletAnim()
end

CreateThread(function()
    while true do
        if tabletOpen and IsControlJustPressed(0, 322) then
            closeTabletUi()
        end
        Wait(tabletOpen and 0 or 500)
    end
end)

local function openAdminMenu()
    QBCore.Functions.TriggerCallback('fivempro_gangs:server:getAdminSnapshot', function(res)
        if not res or not res.ok then
            return QBCore.Functions.Notify('Nėra teisių.', 'error')
        end
        local menu = {
            { header = 'Gang Admin Panel', txt = 'Valdyk gaujas ir teritorijas', isMenuHeader = true },
        }
        for _, g in ipairs(res.gangs or {}) do
            menu[#menu + 1] = {
                header = ('#%s %s (%s)'):format(g.id, g.name, g.gang_type),
                txt = ('Rep: %s | Heat: %s | Color: %s'):format(g.reputation or 0, g.heat or 0, g.color_hex or '#FFFFFF'),
                params = {
                    isAction = true,
                    event = function()
                        local input = exports['qb-input']:ShowInput({
                            header = ('Admin: %s'):format(g.name),
                            submitText = 'Saugoti',
                            inputs = {
                                { text = 'Reputation', name = 'reputation', type = 'number', default = tostring(g.reputation or 0) },
                                { text = 'Heat', name = 'heat', type = 'number', default = tostring(g.heat or 0) },
                                { text = 'DELETE (yes/no)', name = 'delete', type = 'text' },
                            },
                        })
                        if not input then return end
                        if tostring(input.delete or ''):lower() == 'yes' then
                            TriggerServerEvent('fivempro_gangs:server:adminDeleteGang', g.id)
                            return
                        end
                        TriggerServerEvent('fivempro_gangs:server:adminSetGangStats', g.id, tonumber(input.reputation) or 0, tonumber(input.heat) or 0)
                    end,
                },
            }
        end
        for _, t in ipairs(res.turfs or {}) do
            menu[#menu + 1] = {
                header = ('Turf: %s'):format(t.turf_label or t.turf_id),
                txt = ('Owner: %s | Progress: %s%%'):format(t.owner_name or 'Laisva', t.progress or 0),
                params = {
                    isAction = true,
                    event = function()
                        local tid = t.turf_id
                        local sub = {
                            { header = ('Turf admin: %s'):format(tid), isMenuHeader = true },
                            {
                                header = 'Reset turf',
                                params = { isAction = true, event = function()
                                    TriggerServerEvent('fivempro_gangs:server:adminResetTurf', tid)
                                end },
                            },
                            {
                                header = 'Set progress (0-100)',
                                params = { isAction = true, event = function()
                                    local inp = exports['qb-input']:ShowInput({
                                        header = 'Progress',
                                        submitText = 'OK',
                                        inputs = { { text = 'Progress', name = 'p', type = 'number', default = '0' } },
                                    })
                                    if inp then TriggerServerEvent('fivempro_gangs:server:adminSetTurfProgress', tid, tonumber(inp.p) or 0) end
                                end },
                            },
                            {
                                header = 'Set owner gang ID (0=free)',
                                params = { isAction = true, event = function()
                                    local inp = exports['qb-input']:ShowInput({
                                        header = 'Gang ID',
                                        submitText = 'OK',
                                        inputs = { { text = 'gang_id', name = 'g', type = 'number', default = '0' } },
                                    })
                                    if inp then TriggerServerEvent('fivempro_gangs:server:adminSetTurfOwner', tid, tonumber(inp.g) or 0) end
                                end },
                            },
                        }
                        TriggerEvent('qb-menu:client:openMenu', sub, false, true)
                    end,
                },
            }
        end
        TriggerEvent('qb-menu:client:openMenu', menu, false, true)
    end)
end

RegisterNetEvent('fivempro_gangs:client:openTablet', function()
    if tabletOpen then
        closeTabletUi()
    end
    QBCore.Functions.TriggerCallback('fivempro_gangs:server:getTabletState', function(res)
        if not res or not res.ok then
            QBCore.Functions.Notify((res and res.msg) or 'Nepavyko atidaryti planšetės.', 'error')
            return
        end
        tabletOpen = true
        playTabletAnim()
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(false)
        SendNUIMessage({
            action = 'open',
            payload = {
                hasGang = res.hasGang,
                gang = res.gang or nil,
                members = res.members or {},
                gangTypes = res.gangTypes or {},
                palette = res.palette or {},
                colorUsage = res.colorUsage or {},
                turfs = res.turfs or {},
                tabletMap = res.tabletMap or Config.TabletMap or {},
                missions = res.missions or {},
                claimThreshold = res.claimThreshold or 100,
            },
        })
    end)
end)

RegisterNetEvent('fivempro_gangs:client:refreshTablet', function()
    if not tabletOpen then return end
    QBCore.Functions.TriggerCallback('fivempro_gangs:server:getTabletState', function(res)
        if not res or not res.ok then return end
        SendNUIMessage({
            action = 'open',
            payload = {
                keepTab = true,
                hasGang = res.hasGang,
                gang = res.gang or nil,
                members = res.members or {},
                gangTypes = res.gangTypes or {},
                palette = res.palette or {},
                colorUsage = res.colorUsage or {},
                turfs = res.turfs or {},
                tabletMap = res.tabletMap or Config.TabletMap or {},
                missions = res.missions or {},
                claimThreshold = res.claimThreshold or 100,
            }
        })
    end)
end)

RegisterCommand('gangsell', function()
    local turfId = getCurrentTurfId()
    if not turfId then
        return QBCore.Functions.Notify('Nesi turf teritorijoje.', 'error')
    end
    local ped = PlayerPedId()
    local p = GetEntityCoords(ped)
    local handle, foundPed = FindFirstPed()
    local ok = true
    local target = 0
    repeat
        if foundPed and foundPed ~= ped and not IsPedAPlayer(foundPed) and not IsEntityDead(foundPed) then
            local tp = GetEntityCoords(foundPed)
            if #(p - tp) <= (Config.DrugSell.maxDistanceToPed or 3.0) then
                target = foundPed
                break
            end
        end
        ok, foundPed = FindNextPed(handle)
    until not ok
    EndFindPed(handle)

    if target == 0 then
        return QBCore.Functions.Notify('Netoliese nėra NPC pirkėjų.', 'error')
    end

    QBCore.Functions.TriggerCallback('fivempro_gangs:server:tryDrugSale', function(res)
        if not res or not res.ok then
            if res and res.refused then
                QBCore.Functions.Notify('NPC atsisakė. Bandyk kitą.', 'error')
            else
                QBCore.Functions.Notify((res and res.reason) or 'Pardavimas nepavyko.', 'error')
            end
            return
        end
        QBCore.Functions.Notify(('Parduota (%s) už $%s'):format(res.item or 'item', res.price or 0), 'success')
        if res.alertPolice then
            local cp = GetEntityCoords(PlayerPedId())
            TriggerServerEvent('fivempro_dispatch:server:createServiceCall', 'police', 'drug', 'Pranešta apie įtartiną sandorį', { x = cp.x, y = cp.y, z = cp.z })
        end
    end, turfId, NetworkGetNetworkIdFromEntity(target))
end, false)

RegisterCommand('gangadmin', function()
    openAdminMenu()
end, false)

RegisterCommand('gangtablet', function()
    TriggerEvent('fivempro_gangs:client:openTablet')
end, false)

RegisterNUICallback('gangs:close', function(_, cb)
    closeTabletUi()
    cb({ ok = true })
end)

RegisterNUICallback('gangs:createGang', function(data, cb)
    if not data or not data.name or not data.gangType then
        cb({ ok = false })
        return
    end
    TriggerServerEvent('fivempro_gangs:server:createGang', {
        name = data.name,
        gangType = data.gangType,
        colorHex = data.colorHex,
        secondaryColorHex = data.secondaryColorHex,
    })
    cb({ ok = true })
end)

RegisterNUICallback('gangs:refresh', function(_, cb)
    QBCore.Functions.TriggerCallback('fivempro_gangs:server:getTabletState', function(res)
        cb(res or { ok = false })
    end)
end)

RegisterNUICallback('gangs:setWaypoint', function(data, cb)
    local turfId = tostring(data and data.turfId or '')
    local turf = turfId ~= '' and Config.Turfs[turfId] or nil
    if turf and turf.center then
        SetNewWaypoint(turf.center.x + 0.0, turf.center.y + 0.0)
        cb({ ok = true })
        return
    end
    cb({ ok = false })
end)

RegisterNUICallback('gangs:inviteMember', function(data, cb)
    local targetId = tonumber(data and data.targetId)
    if not targetId or targetId < 1 then
        cb({ ok = false })
        return
    end
    TriggerServerEvent('fivempro_gangs:server:inviteMember', targetId)
    cb({ ok = true })
end)

RegisterNUICallback('gangs:setMemberRank', function(data, cb)
    local citizenid = tostring(data and data.citizenid or '')
    local rank = tonumber(data and data.rank)
    if citizenid == '' or not rank then
        cb({ ok = false })
        return
    end
    TriggerServerEvent('fivempro_gangs:server:setMemberRank', citizenid, rank)
    cb({ ok = true })
end)

RegisterNUICallback('gangs:startMission', function(data, cb)
    local turfId = tostring(data and data.turfId or '')
    local missionType = tostring(data and data.missionType or '')
    if turfId == '' or missionType == '' then
        cb({ ok = false })
        return
    end
    TriggerEvent('fivempro_gangs:client:startMission', turfId, missionType)
    SetNuiFocus(false, false)
    stopTabletAnim()
    SendNUIMessage({ action = 'dock' })
    cb({ ok = true })
end)

RegisterNUICallback('gangs:setDocked', function(data, cb)
    local docked = data and data.docked == true
    if docked then
        SetNuiFocus(false, false)
        stopTabletAnim()
        SendNUIMessage({ action = 'dock' })
    elseif tabletOpen then
        playTabletAnim()
        SetNuiFocus(true, true)
        SendNUIMessage({ action = 'undock' })
    end
    cb({ ok = true })
end)

RegisterNUICallback('gangs:kickMember', function(data, cb)
    local citizenid = tostring(data and data.citizenid or '')
    if citizenid == '' then
        cb({ ok = false })
        return
    end
    TriggerServerEvent('fivempro_gangs:server:kickMember', citizenid)
    cb({ ok = true })
end)

local function openVendorMenu()
    local price = tonumber(Config.TabletVendor and Config.TabletVendor.tabletPrice) or 5000
    local menu = {
        { header = 'Gaujų ryšininkas', txt = 'Planšetės ir kontaktai', isMenuHeader = true },
        {
            header = ('Pirkti gang planšetę ($%s)'):format(price),
            txt = 'Reikalinga gaujos registravimui ir valdymui',
            params = {
                isAction = true,
                event = function()
                    TriggerServerEvent('fivempro_gangs:server:buyTablet')
                end,
            },
        },
    }
    TriggerEvent('qb-menu:client:openMenu', menu, false, true)
end

CreateThread(function()
    local v = Config.TabletVendor
    if not v or not v.coords then return end

    if v.blip and v.blip.enabled then
        local b = AddBlipForCoord(v.coords.x + 0.0, v.coords.y + 0.0, v.coords.z + 0.0)
        SetBlipSprite(b, v.blip.sprite or 521)
        SetBlipDisplay(b, 4)
        SetBlipScale(b, v.blip.scale or 0.8)
        SetBlipColour(b, v.blip.color or 1)
        SetBlipAsShortRange(b, v.blip.shortRange ~= false)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(v.blip.label or 'Gang Tablet NPC')
        EndTextCommandSetBlipName(b)
    end

    local model = joaat(v.model or 'g_m_y_lost_01')
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end
    vendorPed = CreatePed(4, model, v.coords.x + 0.0, v.coords.y + 0.0, v.coords.z - 1.0, v.coords.w + 0.0, false, true)
    SetEntityInvincible(vendorPed, true)
    SetBlockingOfNonTemporaryEvents(vendorPed, true)
    FreezeEntityPosition(vendorPed, true)

    if GetResourceState('qb-target') == 'started' then
        exports['qb-target']:AddTargetEntity(vendorPed, {
            options = {
                {
                    icon = 'fas fa-tablet-alt',
                    label = v.label or 'Gaujų ryšininkas',
                    action = function()
                        openVendorMenu()
                    end,
                },
            },
            distance = 2.5,
        })
    else
        while true do
            Wait(0)
            local ped = PlayerPedId()
            local p = GetEntityCoords(ped)
            local d = #(p - vector3(v.coords.x, v.coords.y, v.coords.z))
            if d <= 2.0 then
                SetTextComponentFormat('STRING')
                AddTextComponentString('Spausk ~INPUT_CONTEXT~ kalbėti su gaujų ryšininku')
                DisplayHelpTextFromStringLabel(0, 0, 1, -1)
                if IsControlJustReleased(0, 38) then
                    openVendorMenu()
                    Wait(400)
                end
            end
        end
    end
end)

CreateThread(function()
    while true do
        if tabletOpen and (IsControlJustPressed(0, 322) or IsControlJustPressed(0, 200)) then
            closeTabletUi()
        end
        Wait(0)
    end
end)
