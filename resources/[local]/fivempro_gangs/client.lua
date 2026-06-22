local QBCore = exports['qb-core']:GetCoreObject()
local vendorPed = nil
local tabletOpen = false
local adminOpen = false
local tabletProp = nil

local function getCurrentTurfId()
    local p = GetEntityCoords(PlayerPedId())
    return Config.FindTurfAt(p.x, p.y)
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

local function closeAdminUi()
    adminOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'adminClose' })
end

CreateThread(function()
    while true do
        if (tabletOpen or adminOpen) and IsControlJustPressed(0, 322) then
            if adminOpen then
                closeAdminUi()
            else
                closeTabletUi()
            end
        end
        Wait((tabletOpen or adminOpen) and 0 or 500)
    end
end)

local function openAdminMenu()
    if tabletOpen then
        closeTabletUi()
    end
    QBCore.Functions.TriggerCallback('fivempro_gangs:server:getAdminSnapshot', function(res)
        if not res or not res.ok then
            return QBCore.Functions.Notify('Nėra teisių.', 'error')
        end
        adminOpen = true
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(false)
        SendNUIMessage({ action = 'adminOpen', payload = res })
    end)
end

local function refreshAdminSnapshot(cb)
    QBCore.Functions.TriggerCallback('fivempro_gangs:server:getAdminSnapshot', function(res)
        if cb then cb(res) end
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
                gangColors = res.gangColors or {},
                topGangs = res.topGangs or {},
                activeWars = res.activeWars or {},
                recentActivities = res.recentActivities or {},
                missions = res.missions or {},
                claimThreshold = res.claimThreshold or 100,
                warnings = res.warnings or {},
                maxWarnings = res.maxWarnings or 5,
            },
        })
    end)
end)

RegisterNetEvent('fivempro_gangs:client:gangWarning', function(payload)
    if tabletOpen then
        QBCore.Functions.TriggerCallback('fivempro_gangs:server:getTabletState', function(res)
            if not res or not res.ok then return end
            SendNUIMessage({
                action = 'gangWarning',
                payload = res,
                notice = payload or {},
            })
        end)
    end
end)

RegisterNetEvent('fivempro_gangs:client:refreshTablet', function()
    QBCore.Functions.TriggerCallback('fivempro_gangs:server:getTabletState', function(res)
        if not res or not res.ok then return end
        if not tabletOpen then return end
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
                gangColors = res.gangColors or {},
                topGangs = res.topGangs or {},
                activeWars = res.activeWars or {},
                recentActivities = res.recentActivities or {},
                missions = res.missions or {},
                claimThreshold = res.claimThreshold or 100,
                warnings = res.warnings or {},
                maxWarnings = res.maxWarnings or 5,
            }
        })
    end)
end)

local function playerHasGangDrugItem()
    for _, d in ipairs(Config.DrugSellItems or {}) do
        if QBCore.Functions.HasItem(d.item, 1) then
            return true
        end
    end
    return false
end

local function canGangSellToPed(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end
    if entity == PlayerPedId() or IsPedAPlayer(entity) or IsEntityDead(entity) then return false end
    if vendorPed and entity == vendorPed then return false end
    if IsPedInAnyVehicle(PlayerPedId(), false) then return false end
    if not getCurrentTurfId() then return false end
    return playerHasGangDrugItem()
end

local function tryGangSellToNpc(entity)
    local turfId = getCurrentTurfId()
    if not turfId then
        return QBCore.Functions.Notify('Nesi turf teritorijoje.', 'error')
    end
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        return QBCore.Functions.Notify('Netinkamas NPC.', 'error')
    end
    if GetResourceState('fivempro_drugs') == 'started' and exports['fivempro_drugs']:IsDrugSellAnimBusy() then
        return
    end
    local maxDist = (Config.DrugSell.maxDistanceToPed or 3.0) + 0.5
    if #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(entity)) > maxDist then
        return QBCore.Functions.Notify('NPC per toli.', 'error')
    end

    local function doSell()
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
        end, turfId, NetworkGetNetworkIdFromEntity(entity))
    end

    if GetResourceState('fivempro_drugs') == 'started' then
        exports['fivempro_drugs']:PlayDrugSellAnim(entity, function(ok)
            if not ok then return end
            if not DoesEntityExist(entity) then
                return QBCore.Functions.Notify('NPC nebepasiekiamas.', 'error')
            end
            doSell()
        end)
        return
    end

    doSell()
end

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do
        Wait(250)
    end
    Wait(500)
    exports['qb-target']:AddGlobalPed({
        options = {
            {
                icon = 'fas fa-hand-holding-dollar',
                label = 'Parduoti gaujos turf',
                action = function(entity)
                    tryGangSellToNpc(entity)
                end,
                canInteract = canGangSellToPed,
            },
        },
        distance = (Config.DrugSell.maxDistanceToPed or 3.0) + 0.5,
    })
end)

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

RegisterNUICallback('gangs:adminClose', function(_, cb)
    closeAdminUi()
    cb({ ok = true })
end)

RegisterNUICallback('gangs:adminRefresh', function(_, cb)
    refreshAdminSnapshot(function(res)
        cb(res or { ok = false })
    end)
end)

RegisterNUICallback('gangs:adminIssueWarning', function(data, cb)
    if not data or not data.gangId then
        cb({ ok = false })
        return
    end
    TriggerServerEvent('fivempro_gangs:server:adminIssueWarning', data.gangId, tostring(data.reason or ''))
    SetTimeout(200, function()
        refreshAdminSnapshot(cb)
    end)
end)

RegisterNUICallback('gangs:adminClearWarnings', function(data, cb)
    if not data or not data.gangId then
        cb({ ok = false })
        return
    end
    TriggerServerEvent('fivempro_gangs:server:adminClearWarnings', data.gangId)
    SetTimeout(200, function()
        refreshAdminSnapshot(cb)
    end)
end)

RegisterNUICallback('gangs:adminSaveGang', function(data, cb)
    if not data or not data.gangId then
        cb({ ok = false })
        return
    end
    TriggerServerEvent('fivempro_gangs:server:adminSetGangStats', data.gangId, tonumber(data.reputation), tonumber(data.heat))
    SetTimeout(150, function()
        refreshAdminSnapshot(cb)
    end)
end)

RegisterNUICallback('gangs:adminDeleteGang', function(data, cb)
    if not data or not data.gangId then
        cb({ ok = false })
        return
    end
    TriggerServerEvent('fivempro_gangs:server:adminDeleteGang', data.gangId)
    SetTimeout(150, function()
        refreshAdminSnapshot(cb)
    end)
end)

RegisterNUICallback('gangs:adminSaveTurf', function(data, cb)
    if not data or not data.turfId then
        cb({ ok = false })
        return
    end
    TriggerServerEvent('fivempro_gangs:server:adminSetTurfOwner', data.turfId, tonumber(data.ownerGangId) or 0)
    TriggerServerEvent('fivempro_gangs:server:adminSetTurfProgress', data.turfId, tonumber(data.progress) or 0)
    SetTimeout(150, function()
        refreshAdminSnapshot(cb)
    end)
end)

RegisterNUICallback('gangs:adminResetTurf', function(data, cb)
    if not data or not data.turfId then
        cb({ ok = false })
        return
    end
    TriggerServerEvent('fivempro_gangs:server:adminResetTurf', data.turfId)
    SetTimeout(150, function()
        refreshAdminSnapshot(cb)
    end)
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
    local turf = Config.GetTurfCell and Config.GetTurfCell(turfId) or (Config.Turfs and Config.Turfs[turfId])
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
    local missionType = tostring(data and data.missionType or '')
    if missionType == '' then
        QBCore.Functions.Notify('Pasirink misijos tipą.', 'error')
        cb({ ok = false })
        return
    end
    local turfId = tostring(data and data.turfId or '')
    TriggerEvent('fivempro_gangs:client:startMission', turfId, missionType)
    closeTabletUi()
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
        exports['fivempro_fonts']:SetBlipName(b, v.blip.label or 'Gang Tablet NPC')
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
