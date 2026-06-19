local QBCore = exports['qb-core']:GetCoreObject()
local coordsHudEnabled = false
local slungProps = {}

local LongWeaponModels = {
    weapon_pistol = 'w_pi_pistol',
    weapon_pistol_mk2 = 'w_pi_pistolmk2',
    weapon_combatpistol = 'w_pi_combatpistol',
    weapon_appistol = 'w_pi_appistol',
    weapon_pistol50 = 'w_pi_pistol50',
    weapon_heavypistol = 'w_pi_heavypistol',
    weapon_snspistol = 'w_pi_sns_pistol',
    weapon_vintagepistol = 'w_pi_vintage_pistol',
    weapon_assaultrifle = 'w_ar_assaultrifle',
    weapon_assaultrifle_mk2 = 'w_ar_assaultrifle',
    weapon_carbinerifle = 'w_ar_carbinerifle',
    weapon_carbinerifle_mk2 = 'w_ar_carbinerifle',
    weapon_advancedrifle = 'w_ar_advancedrifle',
    weapon_specialcarbine = 'w_ar_specialcarbine',
    weapon_specialcarbine_mk2 = 'w_ar_specialcarbine',
    weapon_bullpuprifle = 'w_ar_bullpuprifle',
    weapon_bullpuprifle_mk2 = 'w_ar_bullpuprifle',
    weapon_compactrifle = 'w_ar_assaultrifle_smg',
    weapon_militaryrifle = 'w_ar_bullpuprifle',
    weapon_heavyrifle = 'w_ar_specialcarbine',
    weapon_mg = 'w_mg_mg',
    weapon_combatmg = 'w_mg_combatmg',
    weapon_combatmg_mk2 = 'w_mg_combatmg',
    weapon_gusenberg = 'w_sb_gusenberg',
    weapon_pumpshotgun = 'w_sg_pumpshotgun',
    weapon_pumpshotgun_mk2 = 'w_sg_pumpshotgun',
    weapon_sawnoffshotgun = 'w_sg_sawnoff',
    weapon_assaultshotgun = 'w_sg_assaultshotgun',
    weapon_bullpupshotgun = 'w_sg_bullpupshotgun',
    weapon_heavyshotgun = 'w_sg_heavyshotgun',
    weapon_combatshotgun = 'w_sg_pumpshotgun',
    weapon_sniperrifle = 'w_sr_sniperrifle',
    weapon_heavysniper = 'w_sr_heavysniper',
    weapon_heavysniper_mk2 = 'w_sr_heavysniper',
    weapon_marksmanrifle = 'w_sr_marksmanrifle',
    weapon_marksmanrifle_mk2 = 'w_sr_marksmanrifle',

    -- SMG (stambūs ne rankoj – rodomi tik be kuprinės, kaip karabinai)
    weapon_microsmg = 'w_sb_microsmg',
    weapon_smg = 'w_sb_smg',
    weapon_smg_mk2 = 'w_sb_smgmk2',
    weapon_assaultsmg = 'w_sb_assaultsmg',
    weapon_combatpdw = 'w_sb_pdw',
    weapon_machinepistol = 'w_sb_compactsmg',
    weapon_minismg = 'w_sb_minismg',
    weapon_fgc9 = 'w_pi_combatpistol',
    weapon_raycarbine = 'w_ar_srifle',
    weapon_tecpistol = 'w_pi_pistolsmg_m31',
}

local function isLongBackWeapon(weaponName)
    return weaponName and LongWeaponModels[tostring(weaponName)] ~= nil
end

exports('IsLongBackWeapon', isLongBackWeapon)

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

local function clearSlungProps()
    for _, data in pairs(slungProps) do
        local ent = type(data) == 'table' and data.entity or data
        local weaponHash = type(data) == 'table' and data.weaponHash or nil
        if ent and DoesEntityExist(ent) then
            DeleteEntity(ent)
        end
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
    local bone = GetPedBoneIndex(ped, 24816)
    if slotIndex == 1 then
        AttachEntityToEntity(ent, ped, bone, -0.17, -0.15, 0.02, 0.0, 150.0, 0.0, true, true, false, true, 2, true)
    elseif slotIndex == 2 then
        AttachEntityToEntity(ent, ped, bone, 0.17, -0.15, 0.02, 0.0, 150.0, 0.0, true, true, false, true, 2, true)
    else
        local hipBone = GetPedBoneIndex(ped, 11816)
        AttachEntityToEntity(ent, ped, hipBone, 0.10, 0.02, 0.0, 75.0, 20.0, 170.0, true, true, false, true, 2, true)
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
    local obj = CreateObject(model, 0.0, 0.0, 0.0, true, true, false)
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

    local weaponHash = joaat(weaponName)
    local fallbackModel = LongWeaponModels[weaponName]
    local weaponInfo = weaponItem.info or {}

    if not loadWeaponAsset(weaponHash) then
        if fallbackModel then
            attachFallbackPropToBack(slotIndex, fallbackModel)
        end
        return
    end

    local coords = GetEntityCoords(ped)
    local obj = CreateWeaponObject(weaponHash, 0, coords.x, coords.y, coords.z, true, 1.0, 0.0)
    if not obj or obj == 0 then
        if fallbackModel then
            attachFallbackPropToBack(slotIndex, fallbackModel)
        end
        return
    end

    applyAttachmentsToWeaponObject(obj, weaponInfo)
    attachEntityToBackSlot(ped, slotIndex, obj)
    slungProps[slotIndex] = { entity = obj, weaponHash = weaponHash }
end

local function refreshSlungWeapons()
    clearSlungProps()
    local ped = PlayerPedId()
    -- Kuprinė „paslepia“ ilgus ginklus – jie lieka inventoriuje ir naudojami, tik nebededami ant nugaros.
    if hasBackpackOnPed(ped) then
        return
    end

    local pData = QBCore.Functions.GetPlayerData()
    local items = pData and pData.items or {}
    if not items then return end

    local currentWeaponHash = GetSelectedPedWeapon(ped)
    local currentWeaponData = QBCore.Shared.Weapons[currentWeaponHash]
    local equippedName = currentWeaponData and currentWeaponData.name or nil

    local carryItems = {}
    for _, item in pairs(items) do
        if item and (item.type == 'weapon' or (item.name and tostring(item.name):lower():find('^weapon_', 1, false))) and item.name ~= equippedName and isLongBackWeapon(item.name) then
            carryItems[#carryItems + 1] = item
        end
        if #carryItems >= 3 then break end
    end

    for idx, item in ipairs(carryItems) do
        attachWeaponItemToBack(idx, item)
    end
end

RegisterNetEvent('fivempro_basics:client:refreshSlungWeapons', function()
    refreshSlungWeapons()
end)

CreateThread(function()
    Wait(1500)
    print("[fivempro_basics] Client script aktyvus.")
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
            refreshSlungWeapons()
            Wait(1200)
        else
            clearSlungProps()
            Wait(2000)
        end
    end
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    SetPlayerCanUseCover(PlayerId(), false)
    Wait(1000)
    refreshSlungWeapons()
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function()
    Wait(250)
    refreshSlungWeapons()
end)

AddEventHandler('onResourceStop', function(resName)
    if resName ~= GetCurrentResourceName() then return end
    clearSlungProps()
end)

-- Uždrausti GTA slėpimąsi už užtvarų (Q / cover) — RP serveryje nenaudojama.
CreateThread(function()
    local playerId = PlayerId()
    SetPlayerCanUseCover(playerId, false)
    while true do
        SetPlayerCanUseCover(playerId, false)
        for cg = 0, 2 do
            DisableControlAction(cg, 44, true) -- INPUT_COVER (Q)
        end
        local ped = PlayerPedId()
        if ped ~= 0 and DoesEntityExist(ped) then
            SetPedCanPeekInCover(ped, false)
            local drawBusy = GetResourceState('qb-weapons') == 'started' and _G.QBWeaponDrawBusy == true
            if not drawBusy and (IsPedInCover(ped, false) or IsPedGoingIntoCover(ped)) then
                ClearPedTasks(ped)
            end
        end
        Wait(0)
    end
end)

-- Disable GTA default weapon wheel (TAB) so inventory/hotbar flow is consistent.
CreateThread(function()
    while true do
        DisableControlAction(0, 37, true) -- INPUT_SELECT_WEAPON (TAB)
        -- Pause/menu klavišai visose grupėse (kai kurie scriptai naudoja grupę 1/2).
        for cg = 0, 2 do
            EnableControlAction(cg, 199, true) -- P
            EnableControlAction(cg, 200, true) -- ESC
            EnableControlAction(cg, 202, true) -- FRONTEND_CANCEL (dalis UI)
        end
        Wait(0)
    end
end)

-- TAB shows qb-inventory hotbar (slots 1-5) while held.
CreateThread(function()
    local tabHotbarShown = false
    while true do
        if IsControlJustPressed(0, 37) then
            ExecuteCommand('hotbar')
            tabHotbarShown = true
        elseif tabHotbarShown and IsControlJustReleased(0, 37) then
            ExecuteCommand('hotbar')
            tabHotbarShown = false
        end
        Wait(0)
    end
end)

local function fivemproForceCloseAllUi()
    TriggerEvent('fivempro_dealership:client:forceCloseUi')
    TriggerEvent('fivempro_garages:client:forceCloseUi')
    TriggerEvent('fivempro_kma:client:forceCloseUi')
    TriggerEvent('fivempro_ltpd:client:forceCloseMdt')
    TriggerEvent('fivempro_emotes:client:forceClose')
    TriggerEvent('fivempro_hud:client:forceClose')
    TriggerEvent('qb-menu:client:closeMenu')
    if GetResourceState('qb-menu') == 'started' then
        pcall(function()
            exports['qb-menu']:closeMenu()
        end)
    end
    TriggerEvent('qb-inventory:client:closeInv')
    pcall(function()
        if GetResourceState('ox_lib') == 'started' and exports.ox_lib and exports.ox_lib.hideContext then
            exports.ox_lib:hideContext()
        end
    end)
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    if GetResourceState('qb-target') == 'started' then
        exports['qb-target']:DisableTarget(false)
    end
end

RegisterNetEvent('fivempro_basics:client:globalEscClose', fivemproForceCloseAllUi)

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

-- Global fail-safe: ESC/P — valdikliai (kai pasiekiami) + atsarginis kelias.
CreateThread(function()
    while true do
        local pressed = false
        for cg = 0, 2 do
            if IsControlJustPressed(cg, 199) or IsDisabledControlJustPressed(cg, 199)
                or IsControlJustPressed(cg, 200) or IsDisabledControlJustPressed(cg, 200)
                or IsControlJustPressed(cg, 202) or IsDisabledControlJustPressed(cg, 202) then
                pressed = true
                break
            end
        end
        if pressed and type(IsNuiFocused) == 'function' and IsNuiFocused() then
            fivemproForceCloseAllUi()
        end
        Wait(0)
    end
end)

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

    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName('Atsigavai (test revive).')
    EndTextCommandThefeedPostTicker(false, false)
    print('[fivempro_basics] Test revive ivykdytas.')
end

local function healLocalPlayer()
    local ped = PlayerPedId()
    SetEntityHealth(ped, 200)
    ClearPedBloodDamage(ped)
end

RegisterCommand('fprevive', function()
    reviveLocalPlayer()
end, false)

RegisterKeyMapping('fprevive', 'Fivempro test revive', 'keyboard', 'F6')

RegisterNetEvent('fivempro_basics:client:adminRevive', function()
    reviveLocalPlayer()
end)

RegisterNetEvent('fivempro_basics:client:adminHeal', function()
    healLocalPlayer()
end)

RegisterNetEvent('fivempro_basics:client:openRegister', function()
    if GetResourceState('fivempro_charcreator') ~= 'started' then
        QBCore.Functions.Notify('fivempro_charcreator nėra paleistas.', 'error')
        return
    end
    TriggerEvent('fivempro_charcreator:client:openWizard', true)
end)

RegisterNetEvent('fivempro_basics:client:toggleCoords', function()
    coordsHudEnabled = not coordsHudEnabled
    if coordsHudEnabled then
        QBCore.Functions.Notify('/coords ijungta', 'success')
    else
        QBCore.Functions.Notify('/coords isjungta', 'error')
    end
end)

local HEAD_BONE = 31086
local HEAD_TEXT_Z = 0.45

local function getHeadCoords(ped)
    return GetPedBoneCoords(ped, HEAD_BONE, 0.0, 0.0, HEAD_TEXT_Z)
end

local function drawHead3D(coords, text, opts)
    local o = opts or {}
    local onScreen, worldX, worldY = World3dToScreen2d(coords.x, coords.y, coords.z)
    if not onScreen then return end
    local camCoords = GetGameplayCamCoord()
    local scale = (o.scaleDiv or 220) / (GetGameplayCamFov() * #(camCoords - coords))
    local r, g, b, a = o.r or 255, o.g or 255, o.b or 255, o.a or 255
    SetTextScale(1.0, (o.textScale or 0.5) * scale)
    if GetResourceState('fivempro_fonts') == 'started' then
        exports['fivempro_fonts']:ApplyTextFont()
    else
        SetTextFont(4)
    end
    SetTextColour(r, g, b, a)
    SetTextEdge(2, 0, 0, 0, o.edgeAlpha or 180)
    SetTextProportional(1)
    SetTextOutline()
    SetTextCentre(1)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(worldX, worldY)
end

local function drawShout3D(coords, text)
    drawHead3D(coords, text, { r = 255, g = 210, b = 70, textScale = 0.58 })
end

RegisterNetEvent('fivempro_basics:client:showTad', function(senderId, msg)
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

RegisterNetEvent('fivempro_basics:client:showShout', function(senderId, name, msg)
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

local function getStaffHeadCoords(ped)
    return GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.52)
end

local function drawStaffTag3D(coords, text, color)
    local onScreen, worldX, worldY = World3dToScreen2d(coords.x, coords.y, coords.z)
    if not onScreen then return end
    local camCoords = GetGameplayCamCoord()
    local scale = 200 / (GetGameplayCamFov() * #(camCoords - coords))
    local r, g, b = 255, 255, 255
    if type(color) == 'table' then
        r = tonumber(color[1]) or r
        g = tonumber(color[2]) or g
        b = tonumber(color[3]) or b
    end
    SetTextScale(1.0, 0.50 * scale)
    SetTextFont(4)
    SetTextColour(r, g, b, 255)
    SetTextEdge(2, 0, 0, 0, 200)
    SetTextProportional(1)
    SetTextOutline()
    SetTextCentre(1)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(worldX, worldY)
end

RegisterNetEvent('fivempro_basics:client:syncStaffTags', function(tags)
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
                    local head = getStaffHeadCoords(ped)
                    if #(myCoords - head) <= 50.0 then
                        sleep = 0
                        drawStaffTag3D(head, tag.label, tag.color)
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
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if DoesEntityExist(veh) and #(GetEntityCoords(veh) - pcoords) <= scanRadius then
                if isNaturalNpcVehicle(veh) then
                    lockNpcVehicle(veh)
                end
            end
        end
        Wait(600)
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
