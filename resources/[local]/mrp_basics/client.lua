local QBCore = exports['qb-core']:GetCoreObject()
local coordsHudEnabled = false
local slungProps = {}
local lastSlungSignature = nil
local slungRefreshPending = false

local function isLongBackWeapon(weaponName)
    return WeaponCarry.isBackCarried(weaponName)
end

exports('IsLongBackWeapon', isLongBackWeapon)

exports('IsBulkyCarryItem', function(itemName)
    return WeaponCarry.isBulkyItem(itemName)
end)

local function getEquippedWeaponName(ped)
    if GetResourceState('qb-weapons') == 'started' then
        local ok, name = pcall(function()
            return exports['qb-weapons']:GetCurrentWeaponName()
        end)
        if ok and name and name ~= '' then
            return WeaponCarry.normalizeName(name)
        end
    end
    local currentWeaponHash = GetSelectedPedWeapon(ped)
    local currentWeaponData = QBCore.Shared.Weapons[currentWeaponHash]
    if currentWeaponData and currentWeaponData.name then
        return WeaponCarry.normalizeName(currentWeaponData.name)
    end
    return nil
end

local function resolveObjectHash(weaponName)
    return joaat(WeaponCarry.normalizeName(weaponName))
end

local function isInventoryWeaponItem(item)
    if not item or not item.name then return false end
    if (tonumber(item.amount) or 0) <= 0 then return false end
    if item.type == 'weapon' then return true end
    local name = tostring(item.name):lower()
    return name:find('^weapon_', 1, false) ~= nil
end

local function weaponDrawOrReloadBusy()
    if _G.QBWeaponDrawBusy == true then return true end
    if GetResourceState('qb-weapons') ~= 'started' then return false end
    local okDraw, drawBusy = pcall(function()
        return exports['qb-weapons']:IsWeaponDrawBusy()
    end)
    if okDraw and drawBusy then return true end
    local okReload, reloadBusy = pcall(function()
        return exports['qb-weapons']:IsReloadBusy()
    end)
    return okReload and reloadBusy == true
end

local function buildSlungSignature(items, equippedName, hasBackpack)
    if hasBackpack then return 'backpack' end
    local parts = {}
    for _, item in pairs(items or {}) do
        if item and isInventoryWeaponItem(item) then
            local name = WeaponCarry.normalizeName(item.name)
            if name ~= equippedName and isLongBackWeapon(name) then
                local att = ''
                if item.info and item.info.attachments then
                    local ac = {}
                    for _, a in pairs(item.info.attachments) do
                        ac[#ac + 1] = tostring(a.component or a)
                    end
                    table.sort(ac)
                    att = table.concat(ac, ',')
                end
                parts[#parts + 1] = ('%s#%s#%s'):format(name, att, tostring(item.info and item.info.tint or ''))
            end
        end
    end
    table.sort(parts)
    return table.concat(parts, '|') .. '@' .. tostring(equippedName or '')
end

local function componentHash(comp)
    if type(comp) == 'number' then return comp end
    if not comp then return nil end
    return joaat(tostring(comp))
end

local function hasBackpackOnPed(ped)
    -- Component 5 is bags/parachutes for freemode peds.
    local drawable = GetPedDrawableVariation(ped, 5)
    return drawable and drawable > 0
end

local function deleteSlungEntity(ent)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    DetachEntity(ent, true, true)
    SetEntityAsMissionEntity(ent, true, true)
    SetEntityCollision(ent, false, false)
    SetEntityVisible(ent, false, false)
    if NetworkGetEntityIsNetworked(ent) then
        local netId = NetworkGetNetworkIdFromEntity(ent)
        if netId and netId ~= 0 then
            SetNetworkIdCanMigrate(netId, true)
            local deadline = GetGameTimer() + 500
            NetworkRequestControlOfEntity(ent)
            while not NetworkHasControlOfEntity(ent) and GetGameTimer() < deadline do
                NetworkRequestControlOfEntity(ent)
                Wait(0)
            end
        end
    end
    DeleteObject(ent)
    if DoesEntityExist(ent) then
        DeleteEntity(ent)
    end
end

local function clearSlungProps()
    for _, data in pairs(slungProps) do
        local ent = type(data) == 'table' and data.entity or data
        local weaponHash = type(data) == 'table' and data.weaponHash or nil
        deleteSlungEntity(ent)
        if weaponHash and HasWeaponAssetLoaded(weaponHash) then
            RemoveWeaponAsset(weaponHash)
        end
    end
    slungProps = {}
end

local function loadWeaponAsset(weaponHash)
    if HasWeaponAssetLoaded(weaponHash) then return true end
    RequestWeaponAsset(weaponHash, 31, 0)
    local deadline = GetGameTimer() + 5000
    while not HasWeaponAssetLoaded(weaponHash) and GetGameTimer() < deadline do
        Wait(0)
    end
    return HasWeaponAssetLoaded(weaponHash)
end

local function attachEntityToBackSlot(ped, slotIndex, ent)
    SetEntityCollision(ent, false, false)
    SetEntityCompletelyDisableCollision(ent, false, false)
    local bone = GetPedBoneIndex(ped, 24816) -- SKEL_Spine3
    if slotIndex == 1 then
        AttachEntityToEntity(ent, ped, bone, -0.14, -0.16, -0.02, 0.0, 165.0, 5.0, true, true, false, true, 2, true)
    else
        AttachEntityToEntity(ent, ped, bone, 0.14, -0.16, -0.02, 0.0, 195.0, -5.0, true, true, false, true, 2, true)
    end
end

local function attachFallbackPropToBack(slotIndex, modelName)
    local ped = PlayerPedId()
    local model = joaat(modelName)
    RequestModel(model)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(model) and GetGameTimer() < timeout do
        Wait(0)
    end
    if not HasModelLoaded(model) then return end
    -- Local-only prop so delete is reliable when inventory drops the weapon
    local obj = CreateObject(model, 0.0, 0.0, 0.0, false, false, false)
    if not obj or obj == 0 then
        SetModelAsNoLongerNeeded(model)
        return
    end
    SetEntityAsMissionEntity(obj, true, true)
    attachEntityToBackSlot(ped, slotIndex, obj)
    slungProps[slotIndex] = { entity = obj }
    SetModelAsNoLongerNeeded(model)
end

local function applyAttachmentsToWeaponObject(obj, weaponInfo)
    if not obj or obj == 0 or not weaponInfo or not weaponInfo.attachments then return end
    for _, attachment in pairs(weaponInfo.attachments) do
        local comp = componentHash(attachment and attachment.component)
        if comp then
            GiveWeaponComponentToWeaponObject(obj, comp)
        end
    end
    local tint = tonumber(weaponInfo.tint)
    if tint and tint >= 0 then
        SetWeaponObjectTintIndex(obj, tint)
    end
end

local function attachWeaponItemToBack(slotIndex, weaponItem)
    local ped = PlayerPedId()
    local weaponName = weaponItem and weaponItem.name
    if not isLongBackWeapon(weaponName) then return end
    if (tonumber(weaponItem.amount) or 0) <= 0 then return end

    local weaponHash = resolveObjectHash(weaponName)
    local fallbackModel = WeaponCarry.fallbackModel(weaponName)
    local weaponInfo = weaponItem.info or {}

    if not loadWeaponAsset(weaponHash) then
        if fallbackModel then
            attachFallbackPropToBack(slotIndex, fallbackModel)
        end
        return
    end

    local coords = GetEntityCoords(ped)
    -- Local weapon object (not networked) — avoids ghost props after inventory remove
    local obj = CreateWeaponObject(weaponHash, 0, coords.x, coords.y, coords.z, false, 1.0, 0.0)
    if not obj or obj == 0 then
        if fallbackModel then
            attachFallbackPropToBack(slotIndex, fallbackModel)
        end
        return
    end

    SetEntityAsMissionEntity(obj, true, true)
    applyAttachmentsToWeaponObject(obj, weaponInfo)
    attachEntityToBackSlot(ped, slotIndex, obj)
    slungProps[slotIndex] = { entity = obj, weaponHash = weaponHash }
end

local function refreshSlungWeapons(force)
    if not force and weaponDrawOrReloadBusy() then
        slungRefreshPending = true
        return
    end
    slungRefreshPending = false

    local ped = PlayerPedId()
    if hasBackpackOnPed(ped) then
        if lastSlungSignature ~= 'backpack' then
            clearSlungProps()
            lastSlungSignature = 'backpack'
        end
        return
    end

    local pData = QBCore.Functions.GetPlayerData()
    local items = pData and pData.items or {}
    if not items then
        clearSlungProps()
        lastSlungSignature = nil
        return
    end

    local equippedName = getEquippedWeaponName(ped)

    local sig = buildSlungSignature(items, equippedName, false)
    if not force and sig == lastSlungSignature then return end
    lastSlungSignature = sig
    clearSlungProps()

    local carryItems = {}
    for _, item in pairs(items) do
        if item and isInventoryWeaponItem(item) then
            local name = WeaponCarry.normalizeName(item.name)
            if name ~= equippedName and isLongBackWeapon(name) then
                carryItems[#carryItems + 1] = item
            end
        end
    end

    table.sort(carryItems, function(a, b)
        return WeaponCarry.carryPriority(a.name) > WeaponCarry.carryPriority(b.name)
    end)

    local maxSlots = WeaponCarry.maxBackSlots()
    for idx = 1, math.min(#carryItems, maxSlots) do
        attachWeaponItemToBack(idx, carryItems[idx])
    end
end

local function requestSlungRefresh(force)
    if force then
        lastSlungSignature = nil
    end
    SetTimeout(force and 50 or 120, function()
        refreshSlungWeapons(force == true)
    end)
end

RegisterNetEvent('mrp_basics:client:refreshSlungWeapons', function()
    requestSlungRefresh(true)
end)

CreateThread(function()
    Wait(1500)
    print("[mrp_basics] Client script aktyvus.")
end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if ped and ped ~= 0 then
            LocalPlayer.state:set('hasBackpack', hasBackpackOnPed(ped), true)
        end
        Wait(2000)
    end
end)

CreateThread(function()
    while true do
        if LocalPlayer.state.isLoggedIn then
            if slungRefreshPending and not weaponDrawOrReloadBusy() then
                refreshSlungWeapons(true)
            else
                refreshSlungWeapons(false)
            end
            Wait(1000)
        else
            clearSlungProps()
            lastSlungSignature = nil
            slungRefreshPending = false
            Wait(2000)
        end
    end
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    SetPlayerCanUseCover(PlayerId(), false)
    Wait(1000)
    refreshSlungWeapons(true)
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function()
    requestSlungRefresh(true)
end)

-- Inventory RemoveItem / AddItem usually updates via field patch, not full SetPlayerData
RegisterNetEvent('QBCore:Player:UpdatePlayerDataField', function(field, _)
    if field ~= 'items' then return end
    requestSlungRefresh(true)
end)

AddEventHandler('onResourceStop', function(resName)
    if resName ~= GetCurrentResourceName() then return end
    clearSlungProps()
end)

local function fivemproForceCloseAllUi()
    TriggerEvent('mrp_dealership:client:forceCloseUi')
    TriggerEvent('mrp_garages:client:forceCloseUi')
    TriggerEvent('mrp_kma:client:forceCloseUi')
    TriggerEvent('mrp_ltpd:client:forceCloseMdt')
    TriggerEvent('mrp_service_mdt:client:forceClose')
    TriggerEvent('mrp_emotes:client:forceClose')
    TriggerEvent('mrp_hud:client:forceClose')
    TriggerEvent('mrp_phone:client:closePhone')
    TriggerEvent('qb-menu:client:closeMenu')
    TriggerEvent('qb-inventory:client:closeInv')
    if GetResourceState('qb-menu') == 'started' then
        pcall(function()
            exports['qb-menu']:closeMenu()
        end)
    end
    if GetResourceState('qb-input') == 'started' then
        pcall(function()
            exports['qb-input']:ForceClose()
        end)
    end
    if GetResourceState('mrp_bossmenu') == 'started' then
        pcall(function()
            exports['mrp_bossmenu']:CloseBossMenu()
        end)
    end
    if GetResourceState('mrp_duty_locker') == 'started' then
        pcall(function()
            exports['mrp_duty_locker']:Close()
        end)
    end
    if GetResourceState('mrp_drugs') == 'started' then
        pcall(function()
            TriggerEvent('mrp_drugs:client:forceCloseUi')
        end)
    end
    if GetResourceState('mrp_reports') == 'started' then
        TriggerEvent('mrp_reports:client:forceClose')
    end
    pcall(function()
        if GetResourceState('ox_lib') == 'started' and exports.ox_lib and exports.ox_lib.hideContext then
            exports.ox_lib:hideContext()
        end
    end)
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    if GetResourceState('qb-target') == 'started' then
        pcall(function()
            if exports['qb-target'].ForceCloseTarget then
                exports['qb-target']:ForceCloseTarget()
            else
                exports['qb-target']:DisableTarget(true)
            end
        end)
    end
end

exports('ForceCloseAllUi', fivemproForceCloseAllUi)

RegisterCommand('unui', function()
    fivemproForceCloseAllUi()
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName('UI uždarytas. Jei vis dar užstrigęs — ESC dar kartą.')
    EndTextCommandThefeedPostTicker(false, false)
end, false)

RegisterNetEvent('mrp_basics:client:globalEscClose', fivemproForceCloseAllUi)

-- Vienas per-frame ciklas: cover, ginklų ratelis, TAB hotbar, ESC uždarymas (mažiau thread overhead).
CreateThread(function()
    local playerId = PlayerId()
    local tabHotbarShown = false
    SetPlayerCanUseCover(playerId, false)
    while true do
        SetPlayerCanUseCover(playerId, false)
        for cg = 0, 2 do
            DisableControlAction(cg, 44, true) -- INPUT_COVER (Q)
            EnableControlAction(cg, 199, true) -- P
            EnableControlAction(cg, 200, true) -- ESC
            EnableControlAction(cg, 202, true) -- FRONTEND_CANCEL
        end
        DisableControlAction(0, 37, true) -- INPUT_SELECT_WEAPON (TAB)

        local ped = PlayerPedId()
        if ped ~= 0 and DoesEntityExist(ped) then
            SetPedCanPeekInCover(ped, false)
            local drawBusy = GetResourceState('qb-weapons') == 'started' and _G.QBWeaponDrawBusy == true
            if not drawBusy and (IsPedInCover(ped, false) or IsPedGoingIntoCover(ped)) then
                ClearPedTasks(ped)
            end
        end

        if IsControlJustPressed(0, 37) then
            ExecuteCommand('hotbar')
            tabHotbarShown = true
        elseif tabHotbarShown and IsControlJustReleased(0, 37) then
            ExecuteCommand('hotbar')
            tabHotbarShown = false
        end

        local pressed = false
        for cg = 0, 2 do
            if IsControlJustPressed(cg, 199) or IsDisabledControlJustPressed(cg, 199)
                or IsControlJustPressed(cg, 200) or IsDisabledControlJustPressed(cg, 200)
                or IsControlJustPressed(cg, 202) or IsDisabledControlJustPressed(cg, 202) then
                pressed = true
                break
            end
        end
        if pressed and type(IsNuiFocused) == 'function' and (IsNuiFocused() or IsNuiFocusKeepingInput()) then
            fivemproForceCloseAllUi()
        end

        Wait(0)
    end
end)

-- GTA `SetPlayerHealthRechargeMultiplier`: jei > 0, žaidėjas palaipsniui atsigauna (dažnai matoma kaip „gydymas“ po ~50 % HUD).
-- Anksčiau išjungdavom tik kai entity HP <= 50 % max — tada dar vis HP > 100 (pvz. 150 = 50 HUD) vis tiek leisdavo regen. Išjungiam visada (RP).
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if ped and ped ~= 0 and DoesEntityExist(ped) then
            SetPlayerHealthRechargeMultiplier(PlayerId(), 0.0)
        end
        Wait(400)
    end
end)

CreateThread(function()
    SetPlayerCanDoDriveBy(PlayerId(), false)
    while true do
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local playerId = PlayerId()
            DisablePlayerFiring(playerId, true)
            DisableControlAction(0, 24, true)  -- attack
            DisableControlAction(0, 25, true)  -- aim
            DisableControlAction(0, 47, true)  -- weapon
            DisableControlAction(0, 58, true)  -- weapon
            DisableControlAction(0, 68, true)
            DisableControlAction(0, 69, true)
            DisableControlAction(0, 70, true)
            DisableControlAction(0, 91, true)
            DisableControlAction(0, 92, true)
            DisableControlAction(0, 114, true)
            DisableControlAction(0, 140, true) -- melee
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 257, true) -- attack 2
            DisableControlAction(0, 263, true)
            DisableControlAction(0, 264, true)
            DisableControlAction(0, 330, true)
            DisableControlAction(0, 331, true)
            Wait(0)
        else
            Wait(400)
        end
    end
end)

-- Nenaudojam globalių ESC/P keymappingų, nes jie gali konfliktuoti su native Pause/Map.
-- Uždarom UI tik per valdiklių aptikimą žemiau (kai NUI tikrai aktyvus).

local function reviveLocalPlayer()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)

    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z + 0.5, heading, true, false)
    SetPlayerInvincible(PlayerId(), false)
    ClearPedBloodDamage(ped)
    ClearPedTasksImmediately(ped)
    SetEntityHealth(ped, 200)
    SetPedArmour(ped, 0)
end

local function healLocalPlayer()
    local ped = PlayerPedId()
    SetEntityHealth(ped, 200)
    ClearPedBloodDamage(ped)
end

RegisterNetEvent('mrp_basics:client:adminRevive', function()
    reviveLocalPlayer()
end)

RegisterNetEvent('mrp_basics:client:adminHeal', function()
    healLocalPlayer()
end)

RegisterNetEvent('mrp_basics:client:openRegister', function()
    if GetResourceState('mrp_charcreator') ~= 'started' then
        QBCore.Functions.Notify('mrp_charcreator nėra paleistas.', 'error')
        return
    end
    TriggerEvent('mrp_charcreator:client:openWizard', true)
end)

RegisterNetEvent('mrp_basics:client:toggleCoords', function()
    coordsHudEnabled = not coordsHudEnabled
    if coordsHudEnabled then
        QBCore.Functions.Notify('/coords ijungta', 'success')
    else
        QBCore.Functions.Notify('/coords isjungta', 'error')
    end
end)

local HEAD_BONE = 31086
--- World-space lift above skull (bone-local Z would push text sideways).
local HEAD_TEXT_Z = 0.42

local function getHeadCoords(ped)
    local bone = GetPedBoneCoords(ped, HEAD_BONE, 0.0, 0.0, 0.0)
    return vector3(bone.x, bone.y, bone.z + HEAD_TEXT_Z)
end

local function drawHead3D(coords, text, opts)
    local o = opts or {}
    local r, g, b, a = o.r or 255, o.g or 255, o.b or 255, o.a or 255
    local scale = o.textScale or 0.62

    if GetResourceState('mrp_fonts') == 'started' then
        exports['mrp_fonts']:DrawText3D(coords.x, coords.y, coords.z, text, {
            r = r,
            g = g,
            b = b,
            a = a,
            scale = scale,
            background = false,
            center = true,
            outline = true,
        })
        return
    end

    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    SetTextScale(scale, scale)
    SetTextFont(4)
    SetTextColour(r, g, b, a)
    SetTextEdge(2, 0, 0, 0, o.edgeAlpha or 220)
    SetTextProportional(1)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

local function drawShout3D(coords, text)
    drawHead3D(coords, text, { r = 255, g = 210, b = 70, textScale = 0.68 })
end

RegisterNetEvent('mrp_basics:client:showTad', function(senderId, msg)
    local sender = GetPlayerFromServerId(senderId)
    if sender == -1 then return end

    CreateThread(function()
        local displayUntil = GetGameTimer() + 5000
        local label = ('* %s *'):format(msg or '')
        while GetGameTimer() < displayUntil do
            local targetPed = GetPlayerPed(sender)
            if targetPed and targetPed ~= 0 and DoesEntityExist(targetPed) then
                drawHead3D(getHeadCoords(targetPed), label, { r = 194, g = 162, b = 255 })
            end
            Wait(0)
        end
    end)
end)

RegisterNetEvent('mrp_basics:client:showShout', function(senderId, name, msg)
    TriggerEvent('chat:addMessage', {
        color = { 255, 194, 14 },
        multiline = true,
        args = { ('%s suktų'):format(name or 'Žaidėjas'), msg or '' },
    })

    local sender = GetPlayerFromServerId(senderId)
    if sender == -1 then return end

    CreateThread(function()
        local displayUntil = GetGameTimer() + 7000
        while GetGameTimer() < displayUntil do
            local targetPed = GetPlayerPed(sender)
            if targetPed and targetPed ~= 0 and DoesEntityExist(targetPed) then
                drawShout3D(getHeadCoords(targetPed), msg)
            end
            Wait(0)
        end
    end)
end)

local staffTags = {}

RegisterNetEvent('mrp_basics:client:syncStaffTags', function(tags)
    staffTags = tags or {}
end)

CreateThread(function()
    while true do
        local sleep = 500
        local myCoords = GetEntityCoords(PlayerPedId())

        for serverId, tag in pairs(staffTags) do
            local sid = tonumber(serverId) or serverId
            local player = GetPlayerFromServerId(sid)
            if player ~= -1 and tag and tag.label then
                local ped = GetPlayerPed(player)
                if ped and ped ~= 0 and DoesEntityExist(ped) then
                    local head = getHeadCoords(ped)
                    if #(myCoords - head) <= 50.0 then
                        sleep = 0
                        local c = tag.color or {}
                        drawHead3D(head, tag.label, {
                            r = tonumber(c[1]) or 255,
                            g = tonumber(c[2]) or 255,
                            b = tonumber(c[3]) or 255,
                            textScale = 0.78,
                        })
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        if coordsHudEnabled then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)
            local text = ('COORDS  X: %.2f  Y: %.2f  Z: %.2f  H: %.2f'):format(coords.x, coords.y, coords.z, heading)

            SetTextFont(4)
            SetTextProportional(1)
            SetTextScale(0.38, 0.38)
            SetTextColour(255, 255, 255, 220)
            SetTextCentre(true)
            SetTextOutline()
            BeginTextCommandDisplayText('STRING')
            AddTextComponentSubstringPlayerName(text)
            EndTextCommandDisplayText(0.5, 0.02)

            Wait(0)
        else
            Wait(250)
        end
    end
end)

--- Natūraliai spawninami NPC automobiliai — visada užrakinti (su vairuotoju ar be).
local NPC_VEHICLE_POP = {
    [1] = true, -- RANDOM_PERMANENT
    [2] = true, -- RANDOM_PARKED
    [3] = true, -- RANDOM_PATROL
    [4] = true, -- RANDOM_SCENARIO
    [5] = true, -- RANDOM_AMBIENT
    [6] = true, -- PERMANENT
}

local unlockedNpcVehicles = {}
local lockedNpcVehicles = {}
local configuredNpcDrivers = {}

local TASK_EXIT_VEHICLE = 167

local function npcVehicleNetId(veh)
    if not veh or veh == 0 or not NetworkGetEntityIsNetworked(veh) then return nil end
    local netId = NetworkGetNetworkIdFromEntity(veh)
    if netId and netId > 0 then return netId end
    return nil
end

local function isNpcVehicleUnlocked(veh)
    local netId = npcVehicleNetId(veh)
    return netId ~= nil and unlockedNpcVehicles[netId] == true
end

function MarkNpcVehicleUnlocked(veh)
    local netId = npcVehicleNetId(veh)
    if netId then
        unlockedNpcVehicles[netId] = true
        lockedNpcVehicles[veh] = nil
    end
end

exports('MarkNpcVehicleUnlocked', MarkNpcVehicleUnlocked)

RegisterNetEvent('mrp_basics:client:markNpcVehicleUnlocked', function(netId)
    netId = tonumber(netId)
    if not netId or netId <= 0 then return end
    unlockedNpcVehicles[netId] = true
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh and veh ~= 0 and DoesEntityExist(veh) then
        lockedNpcVehicles[veh] = nil
        SetVehicleDoorsLocked(veh, 1)
        SetVehicleDoorsLockedForAllPlayers(veh, false)
    end
end)

local function networkOwnerIsPlayer(veh)
    if not NetworkGetEntityIsNetworked(veh) then return false end
    local owner = NetworkGetEntityOwner(veh)
    if not owner or owner <= 0 then return false end
    for _, pid in ipairs(GetActivePlayers()) do
        if GetPlayerServerId(pid) == owner then
            return true
        end
    end
    return false
end

local function isNaturalNpcVehicle(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return false end
    local pop = GetEntityPopulationType(veh)
    if pop == 7 or pop == 8 or pop == 9 or pop == 10 then return false end
    if networkOwnerIsPlayer(veh) then return false end
    if NPC_VEHICLE_POP[pop] then return true end
    if pop == 0 then return true end
    return false
end

local function lockNpcVehicle(veh)
    if isNpcVehicleUnlocked(veh) then return end
    if lockedNpcVehicles[veh] then return end
    if GetVehicleDoorLockStatus(veh) == 2 then
        lockedNpcVehicles[veh] = true
        return
    end
    SetVehicleDoorsLocked(veh, 2)
    SetVehicleNeedsToBeHotwired(veh, false)
    lockedNpcVehicles[veh] = true
end

local function resumeNpcDriving(ped, veh)
    if not ped or ped == 0 or not veh or veh == 0 then return end
    if not IsPedInVehicle(ped, veh, false) then return end
    if GetIsTaskActive(ped, TASK_EXIT_VEHICLE) then
        ClearPedTasks(ped)
    end
    if not GetIsTaskActive(ped, 169) and not GetIsTaskActive(ped, 165) then
        local speedKmh = GetEntitySpeed(veh) * 3.6
        TaskVehicleDriveWander(ped, veh, math.max(12.0, speedKmh), 786603)
    end
end

local function keepNpcDriverInVehicle(ped, veh)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    if IsPedAPlayer(ped) then return end

    if configuredNpcDrivers[ped] then
        if not IsPedInVehicle(ped, veh, false) then return end
        if GetIsTaskActive(ped, TASK_EXIT_VEHICLE) then
            resumeNpcDriving(ped, veh)
        end
        return
    end

    SetPedCanBeDraggedOut(ped, false)
    SetPedStayInVehicleWhenJacked(ped, true)
    SetPedCanBeKnockedOffVehicle(ped, 1)
    SetPedConfigFlag(ped, 32, false)
    SetPedConfigFlag(ped, 184, true)
    SetPedConfigFlag(ped, 251, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 3, false)
    SetPedCombatAttributes(ped, 17, false)
    SetPedKeepTask(ped, true)
    SetDriverAbility(ped, 1.0)
    SetDriverAggressiveness(ped, 0.35)
    configuredNpcDrivers[ped] = true

    if IsPedInVehicle(ped, veh, false) and GetIsTaskActive(ped, TASK_EXIT_VEHICLE) then
        resumeNpcDriving(ped, veh)
    end
end

local ambientDriverMemory = {} ---@type table<number, { veh: number, untilMs: number }>

local function rememberAmbientDriver(ped, veh)
    ambientDriverMemory[ped] = {
        veh = veh,
        untilMs = GetGameTimer() + 45000,
    }
end

local function pruneNpcVehicleCaches()
    local now = GetGameTimer()
    for ped, row in pairs(ambientDriverMemory) do
        if now > row.untilMs or not DoesEntityExist(ped) or not DoesEntityExist(row.veh) then
            ambientDriverMemory[ped] = nil
            configuredNpcDrivers[ped] = nil
        end
    end
    for ped in pairs(configuredNpcDrivers) do
        if not DoesEntityExist(ped) then
            configuredNpcDrivers[ped] = nil
        end
    end
    for veh in pairs(lockedNpcVehicles) do
        if not DoesEntityExist(veh) then
            lockedNpcVehicles[veh] = nil
        end
    end
end

local function tryReturnAmbientDriverToVehicle(ped, veh)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    if IsPedInAnyVehicle(ped, false) then return end
    if GetPedInVehicleSeat(veh, -1) ~= 0 then return end
    if not isNaturalNpcVehicle(veh) then return end

    local pcoords = GetEntityCoords(ped)
    local vcoords = GetEntityCoords(veh)
    if #(pcoords - vcoords) > 18.0 then return end

    ClearPedTasksImmediately(ped)
    SetPedIntoVehicle(ped, veh, -1)
    if GetPedInVehicleSeat(veh, -1) == ped then
        keepNpcDriverInVehicle(ped, veh)
        if GetEntitySpeed(veh) < 1.5 then
            TaskVehicleDriveWander(ped, veh, 18.0, 786603)
        end
    end
end

local function processAmbientVehicleOccupants(veh, pcoords, maxDist)
    if not isNaturalNpcVehicle(veh) then return false end
    if #(GetEntityCoords(veh) - pcoords) > maxDist then return false end

    local touched = false
    for seat = -1, GetVehicleMaxNumberOfPassengers(veh) - 1 do
        local ped = GetPedInVehicleSeat(veh, seat)
        if ped ~= 0 and DoesEntityExist(ped) and not IsPedAPlayer(ped) then
            if seat == -1 then
                keepNpcDriverInVehicle(ped, veh)
                rememberAmbientDriver(ped, veh)
            else
                SetPedCanBeDraggedOut(ped, false)
                SetPedStayInVehicleWhenJacked(ped, true)
                SetBlockingOfNonTemporaryEvents(ped, true)
                SetPedCombatAttributes(ped, 3, false)
            end
            touched = true
        end
    end
    return touched
end

exports('IsNaturalNpcVehicle', isNaturalNpcVehicle)

CreateThread(function()
    local scanRadius = 240.0
    while true do
        local pcoords = GetEntityCoords(PlayerPedId())
        local nearNpcTraffic = false
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if DoesEntityExist(veh) then
                local vcoords = GetEntityCoords(veh)
                local dist = #(vcoords - pcoords)
                if dist <= scanRadius then
                    nearNpcTraffic = true
                    if isNaturalNpcVehicle(veh) then
                        lockNpcVehicle(veh)
                    end
                end
            end
        end
        Wait(nearNpcTraffic and 700 or 1600)
    end
end)

AddEventHandler('entityCreated', function(entity)
    if not entity or entity == 0 then return end
    local et = GetEntityType(entity)
    if et == 2 then
        SetTimeout(0, function()
            if DoesEntityExist(entity) and isNaturalNpcVehicle(entity) then
                lockNpcVehicle(entity)
                processAmbientVehicleOccupants(entity, GetEntityCoords(PlayerPedId()), 320.0)
            end
        end)
        return
    end
    if et == 1 then
        SetTimeout(0, function()
            if not DoesEntityExist(entity) or IsPedAPlayer(entity) then return end
            if not IsPedInAnyVehicle(entity, false) then return end
            local veh = GetVehiclePedIsIn(entity, false)
            if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == entity and isNaturalNpcVehicle(veh) then
                keepNpcDriverInVehicle(entity, veh)
                rememberAmbientDriver(entity, veh)
            end
        end)
    end
end)

--- NPC vairuotojai neislipa prie žaidėjo — lieka savo automobilyje.
CreateThread(function()
    while true do
        local pcoords = GetEntityCoords(PlayerPedId())
        local nearTraffic = false

        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if DoesEntityExist(veh) and processAmbientVehicleOccupants(veh, pcoords, 260.0) then
                nearTraffic = true
            end
        end

        pruneNpcVehicleCaches()
        if nearTraffic then
            for ped, row in pairs(ambientDriverMemory) do
                tryReturnAmbientDriverToVehicle(ped, row.veh)
            end
            Wait(200)
        else
            Wait(900)
        end
    end
end)
