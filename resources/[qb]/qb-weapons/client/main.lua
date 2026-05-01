-- Variables
local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = QBCore.Functions.GetPlayerData()
local CurrentWeaponData, CanShoot, MultiplierAmount, currentWeapon = {}, true, 0, nil
local lastAutoReloadAt = 0
local lastSyncedWeapon = nil
local lastSyncedAmmo = nil

local AmmoItemByType = {
    AMMO_PISTOL = 'pistol_ammo',
    AMMO_SMG = 'smg_ammo',
    AMMO_RIFLE = 'rifle_ammo',
    AMMO_SHOTGUN = 'shotgun_ammo',
    AMMO_MG = 'smg_ammo',
    AMMO_SNIPER = 'snp_ammo'
}

-- Handlers

local function resolveCurrentWeaponDataByName(weaponName)
    if not PlayerData or not PlayerData.items then return nil end
    for _, item in pairs(PlayerData.items) do
        if item and item.type == 'weapon' and item.name == weaponName then
            return item
        end
    end
    return nil
end

local function getTotalAmmoItems(itemName)
    if not itemName or not PlayerData or not PlayerData.items then return 0 end
    local total = 0
    for _, item in pairs(PlayerData.items) do
        if item and item.name == itemName then
            total = total + (tonumber(item.amount) or 0)
        end
    end
    return total
end

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    QBCore.Functions.TriggerCallback('qb-weapons:server:GetConfig', function(RepairPoints)
        for k, data in pairs(RepairPoints) do
            Config.WeaponRepairPoints[k].IsRepairing = data.IsRepairing
            Config.WeaponRepairPoints[k].RepairingData = data.RepairingData
        end
    end)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    for k in pairs(Config.WeaponRepairPoints) do
        Config.WeaponRepairPoints[k].IsRepairing = false
        Config.WeaponRepairPoints[k].RepairingData = {}
    end
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    PlayerData = val
end)

-- Functions

local function DrawText3Ds(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    BeginTextCommandDisplayText('STRING')
    SetTextCentre(true)
    AddTextComponentSubstringPlayerName(text)
    SetDrawOrigin(x, y, z, 0)
    EndTextCommandDisplayText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0 + 0.0125, 0.017 + factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

-- Events

RegisterNetEvent('qb-weapons:client:SyncRepairShops', function(NewData, key)
    Config.WeaponRepairPoints[key].IsRepairing = NewData.IsRepairing
    Config.WeaponRepairPoints[key].RepairingData = NewData.RepairingData
end)

RegisterNetEvent('qb-weapons:client:EquipTint', function(weapon, tint)
    local player = PlayerPedId()
    SetPedWeaponTintIndex(player, weapon, tint)
end)

RegisterNetEvent('qb-weapons:client:SetCurrentWeapon', function(data, bool)
    if data ~= false then
        CurrentWeaponData = data
    else
        CurrentWeaponData = {}
    end
    CanShoot = bool
end)

RegisterNetEvent('qb-weapons:client:SetWeaponQuality', function(amount)
    if CurrentWeaponData and next(CurrentWeaponData) then
        TriggerServerEvent('qb-weapons:server:SetWeaponQuality', CurrentWeaponData, amount)
    end
end)

RegisterNetEvent('qb-weapons:client:AddAmmo', function(ammoType, amount, itemData)
    local ped = PlayerPedId()
    local weapon = GetSelectedPedWeapon(ped)
    local selectedWeaponData = QBCore.Shared.Weapons[weapon]
    if not selectedWeaponData then
        QBCore.Functions.Notify(Lang:t('error.no_weapon'), 'error')
        return
    end

    if selectedWeaponData.name == 'weapon_unarmed' then
        QBCore.Functions.Notify(Lang:t('error.no_weapon_in_hand'), 'error')
        return
    end

    local normalizedAmmoType = tostring(ammoType):upper()
    if selectedWeaponData.ammotype ~= normalizedAmmoType then
        QBCore.Functions.Notify(Lang:t('error.wrong_ammo'), 'error')
        return
    end

    if (not CurrentWeaponData or not CurrentWeaponData.slot or CurrentWeaponData.name ~= selectedWeaponData.name) then
        CurrentWeaponData = resolveCurrentWeaponDataByName(selectedWeaponData.name) or CurrentWeaponData
    end

    local hasClip, currentClipAmmo = GetAmmoInClip(ped, weapon)
    local hasMaxClip, maxClipAmmo = GetMaxAmmoInClip(ped, weapon, true)
    local clipMissing = 0

    if hasClip and hasMaxClip then
        clipMissing = math.max(0, (tonumber(maxClipAmmo) or 0) - (tonumber(currentClipAmmo) or 0))
    end

    -- Fallback for weapons where clip natives are unreliable: allow loading up to remaining total ammo cap.
    if clipMissing <= 0 then
        local currentTotalAmmo = GetAmmoInPedWeapon(ped, weapon)
        local hasMaxTotal, maxTotalAmmo = GetMaxAmmo(ped, weapon)
        if hasMaxTotal then
            clipMissing = math.max(0, (tonumber(maxTotalAmmo) or 0) - (tonumber(currentTotalAmmo) or 0))
        end
    end

    if clipMissing <= 0 then
        QBCore.Functions.Notify('Magazine is already full.', 'error')
        return
    end

    local ammoItemName = AmmoItemByType[normalizedAmmoType] or (itemData and itemData.name)
    local ammoUnits = getTotalAmmoItems(ammoItemName)
    -- Ammo items are treated as bullet units (1 item = 1 bullet).
    local availableBullets = ammoUnits
    if availableBullets <= 0 then
        QBCore.Functions.Notify('No ammo in inventory.', 'error')
        return
    end

    local bulletsToLoad = math.min(clipMissing, availableBullets)
    if bulletsToLoad <= 0 then
        return
    end
    local function finishReload()
        weapon = GetSelectedPedWeapon(ped)
        local current = QBCore.Shared.Weapons[weapon]

        if not current or current.ammotype ~= normalizedAmmoType then
            return QBCore.Functions.Notify(Lang:t('error.wrong_ammo'), 'error')
        end

        local hadClipBefore, clipBefore = GetAmmoInClip(ped, weapon)
        local hadMaxClipBefore, maxClipBefore = GetMaxAmmoInClip(ped, weapon, true)
        local ammoBefore = GetAmmoInPedWeapon(ped, weapon)
        AddAmmoToPed(ped, weapon, bulletsToLoad)
        local hasClipAfter, clipAfter = GetAmmoInClip(ped, weapon)
        local ammoAfter = GetAmmoInPedWeapon(ped, weapon)
        local clipLoaded = 0
        if hadClipBefore and hasClipAfter then
            clipLoaded = math.max(0, (tonumber(clipAfter) or 0) - (tonumber(clipBefore) or 0))
        end
        local totalLoaded = math.max(0, (tonumber(ammoAfter) or 0) - (tonumber(ammoBefore) or 0))

        local expectedMaxLoad = bulletsToLoad
        if hadClipBefore and hadMaxClipBefore then
            expectedMaxLoad = math.min(bulletsToLoad, math.max(0, (tonumber(maxClipBefore) or 0) - (tonumber(clipBefore) or 0)))
        end

        local reallyLoaded = clipLoaded > 0 and clipLoaded or totalLoaded
        reallyLoaded = math.min(reallyLoaded, expectedMaxLoad)
        if reallyLoaded <= 0 then
            return
        end

        local refreshedAmmo = hasClipAfter and (tonumber(clipAfter) or reallyLoaded) or reallyLoaded
        local unitsToRemove = reallyLoaded
        local payload = CurrentWeaponData
        if not payload or not payload.name then
            payload = resolveCurrentWeaponDataByName(current.name)
        end
        if payload and payload.name then
            TriggerServerEvent('qb-weapons:server:UpdateWeaponAmmo', payload, refreshedAmmo)
        end
        TriggerServerEvent('qb-weapons:server:removeWeaponAmmoItem', ammoItemName, unitsToRemove)
        if ammoItemName and QBCore.Shared.Items[ammoItemName] then
            TriggerEvent('qb-inventory:client:ItemBox', QBCore.Shared.Items[ammoItemName], 'use', reallyLoaded)
        end
    end

    -- Instant reload path to avoid stopping movement while reloading/changing magazine.
    finishReload()
end)

RegisterNetEvent('qb-weapons:client:UseWeapon', function(weaponData, shootbool)
    local ped = PlayerPedId()
    local weaponName = tostring(weaponData.name)
    local weaponHash = joaat(weaponData.name)
    local weaponInfo = weaponData.info or {}
    if currentWeapon == weaponName then
        TriggerEvent('qb-weapons:client:DrawWeapon', nil)
        SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
        RemoveAllPedWeapons(ped, true)
        TriggerEvent('qb-weapons:client:SetCurrentWeapon', nil, shootbool)
        currentWeapon = nil
    elseif weaponName == 'weapon_stickybomb' or weaponName == 'weapon_pipebomb' or weaponName == 'weapon_smokegrenade' or weaponName == 'weapon_flare' or weaponName == 'weapon_proxmine' or weaponName == 'weapon_ball' or weaponName == 'weapon_molotov' or weaponName == 'weapon_grenade' or weaponName == 'weapon_bzgas' then
        TriggerEvent('qb-weapons:client:DrawWeapon', weaponName)
        GiveWeaponToPed(ped, weaponHash, 1, false, false)
        SetPedAmmo(ped, weaponHash, 1)
        SetCurrentPedWeapon(ped, weaponHash, true)
        TriggerEvent('qb-weapons:client:SetCurrentWeapon', weaponData, shootbool)
        currentWeapon = weaponName
    elseif weaponName == 'weapon_snowball' then
        TriggerEvent('qb-weapons:client:DrawWeapon', weaponName)
        GiveWeaponToPed(ped, weaponHash, 10, false, false)
        SetPedAmmo(ped, weaponHash, 10)
        SetCurrentPedWeapon(ped, weaponHash, true)
        TriggerServerEvent('qb-inventory:server:snowball', 'remove')
        TriggerEvent('qb-weapons:client:SetCurrentWeapon', weaponData, shootbool)
        currentWeapon = weaponName
    else
        TriggerEvent('qb-weapons:client:DrawWeapon', weaponName)
        TriggerEvent('qb-weapons:client:SetCurrentWeapon', weaponData, shootbool)
        local ammo = tonumber(weaponInfo.ammo) or 0

        if weaponName == 'weapon_petrolcan' or weaponName == 'weapon_fireextinguisher' then
            ammo = 4000
        end

        GiveWeaponToPed(ped, weaponHash, ammo, false, false)
        SetPedAmmo(ped, weaponHash, ammo)
        SetCurrentPedWeapon(ped, weaponHash, true)

        if weaponInfo.attachments then
            for _, attachment in pairs(weaponInfo.attachments) do
                GiveWeaponComponentToPed(ped, weaponHash, joaat(attachment.component))
            end
        end

        if weaponInfo.tint then
            SetPedWeaponTintIndex(ped, weaponHash, weaponInfo.tint)
        end

        currentWeapon = weaponName
    end
end)

RegisterNetEvent('qb-weapons:client:CheckWeapon', function(weaponName)
    if currentWeapon ~= weaponName:lower() then return end
    local ped = PlayerPedId()
    TriggerEvent('qb-weapons:ResetHolster')
    SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
    RemoveAllPedWeapons(ped, true)
    currentWeapon = nil
end)

-- Threads

CreateThread(function()
    SetWeaponsNoAutoswap(true)
end)

CreateThread(function()
    while true do
        if IsControlJustPressed(0, 45) then -- R key
            local now = GetGameTimer()
            if now - lastAutoReloadAt > 500 then
                lastAutoReloadAt = now

                local ped = PlayerPedId()
                local weapon = GetSelectedPedWeapon(ped)
                local selectedWeaponData = QBCore.Shared.Weapons[weapon]
                if selectedWeaponData and selectedWeaponData.name ~= 'weapon_unarmed' then
                    local ammoType = selectedWeaponData.ammotype
                    local ammoItemName = AmmoItemByType[ammoType or '']
                    if ammoItemName and PlayerData and PlayerData.items then
                        local hasClip, currentClip = GetAmmoInClip(ped, weapon)
                        local hasMaxClip, maxClip = GetMaxAmmoInClip(ped, weapon, true)
                        local canReload = false
                        if hasClip and hasMaxClip then
                            canReload = (tonumber(currentClip) or 0) < (tonumber(maxClip) or 0)
                        else
                            local currentTotalAmmo = GetAmmoInPedWeapon(ped, weapon)
                            local hasMaxTotal, maxTotalAmmo = GetMaxAmmo(ped, weapon)
                            if hasMaxTotal then
                                canReload = (tonumber(currentTotalAmmo) or 0) < (tonumber(maxTotalAmmo) or 0)
                            end
                        end

                        if canReload then
                            for _, item in pairs(PlayerData.items) do
                                if item and item.name == ammoItemName and (tonumber(item.amount) or 0) > 0 then
                                    TriggerServerEvent('qb-inventory:server:useItem', { slot = item.slot })
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
        Wait(0)
    end
end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if IsPedArmed(ped, 7) == 1 then
            local weapon = GetSelectedPedWeapon(ped)
            local selectedWeaponData = QBCore.Shared.Weapons[weapon]
            if selectedWeaponData then
                CurrentWeaponData = resolveCurrentWeaponDataByName(selectedWeaponData.name) or CurrentWeaponData
                local hasClip, clipAmmo = GetAmmoInClip(ped, weapon)
                local ammo = hasClip and (tonumber(clipAmmo) or 0) or GetAmmoInPedWeapon(ped, weapon)
                if CurrentWeaponData and CurrentWeaponData.name then
                    if lastSyncedWeapon ~= selectedWeaponData.name or lastSyncedAmmo ~= ammo then
                        TriggerServerEvent('qb-weapons:server:UpdateWeaponAmmo', CurrentWeaponData, tonumber(ammo))
                        lastSyncedWeapon = selectedWeaponData.name
                        lastSyncedAmmo = ammo
                    end
                end
                if MultiplierAmount > 0 and CurrentWeaponData and CurrentWeaponData.name then
                    TriggerServerEvent('qb-weapons:server:UpdateWeaponQuality', CurrentWeaponData, MultiplierAmount)
                    MultiplierAmount = 0
                end
            end
        else
            lastSyncedWeapon = nil
            lastSyncedAmmo = nil
        end
        Wait(200)
    end
end)

CreateThread(function()
    while true do
        if LocalPlayer.state.isLoggedIn then
            local ped = PlayerPedId()
            if CurrentWeaponData and next(CurrentWeaponData) then
                if IsPedShooting(ped) or IsControlJustPressed(0, 24) then
                    local weapon = GetSelectedPedWeapon(ped)
                    if CanShoot then
                        if weapon and weapon ~= 0 and QBCore.Shared.Weapons[weapon] then
                            QBCore.Functions.TriggerCallback('prison:server:checkThrowable', function(result)
                                if result or GetAmmoInPedWeapon(ped, weapon) <= 0 then return end
                                MultiplierAmount += 1
                            end, weapon)
                            Wait(200)
                        end
                    else
                        if weapon ~= `WEAPON_UNARMED` then
                            TriggerEvent('qb-weapons:client:CheckWeapon', QBCore.Shared.Weapons[weapon]['name'])
                            QBCore.Functions.Notify(Lang:t('error.weapon_broken'), 'error')
                            MultiplierAmount = 0
                        end
                    end
                end
            end
        end
        Wait(0)
    end
end)

CreateThread(function()
    while true do
        if LocalPlayer.state.isLoggedIn then
            local inRange = false
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            for k, data in pairs(Config.WeaponRepairPoints) do
                local distance = #(pos - data.coords)
                if distance < 10 then
                    inRange = true
                    if distance < 1 then
                        if data.IsRepairing then
                            if data.RepairingData.CitizenId ~= PlayerData.citizenid then
                                DrawText3Ds(data.coords.x, data.coords.y, data.coords.z, Lang:t('info.repairshop_not_usable'))
                            else
                                if not data.RepairingData.Ready then
                                    DrawText3Ds(data.coords.x, data.coords.y, data.coords.z, Lang:t('info.weapon_will_repair'))
                                else
                                    DrawText3Ds(data.coords.x, data.coords.y, data.coords.z, Lang:t('info.take_weapon_back'))
                                end
                            end
                        else
                            if CurrentWeaponData and next(CurrentWeaponData) then
                                if not data.RepairingData.Ready then
                                    local WeaponData = QBCore.Shared.Weapons[GetHashKey(CurrentWeaponData.name)]
                                    local WeaponClass = (QBCore.Shared.SplitStr(WeaponData.ammotype, '_')[2]):lower()
                                    DrawText3Ds(data.coords.x, data.coords.y, data.coords.z, Lang:t('info.repair_weapon_price', { value = Config.WeaponRepairCosts[WeaponClass] }))
                                    if IsControlJustPressed(0, 38) then
                                        QBCore.Functions.TriggerCallback('qb-weapons:server:RepairWeapon', function(HasMoney)
                                            if HasMoney then
                                                CurrentWeaponData = {}
                                            end
                                        end, k, CurrentWeaponData)
                                    end
                                else
                                    if data.RepairingData.CitizenId ~= PlayerData.citizenid then
                                        DrawText3Ds(data.coords.x, data.coords.y, data.coords.z, Lang:t('info.repairshop_not_usable'))
                                    else
                                        DrawText3Ds(data.coords.x, data.coords.y, data.coords.z, Lang:t('info.take_weapon_back'))
                                        if IsControlJustPressed(0, 38) then
                                            TriggerServerEvent('qb-weapons:server:TakeBackWeapon', k, data)
                                        end
                                    end
                                end
                            else
                                if data.RepairingData.CitizenId == nil then
                                    DrawText3Ds(data.coords.x, data.coords.y, data.coords.z, Lang:t('error.no_weapon_in_hand'))
                                elseif data.RepairingData.CitizenId == PlayerData.citizenid then
                                    DrawText3Ds(data.coords.x, data.coords.y, data.coords.z, Lang:t('info.take_weapon_back'))
                                    if IsControlJustPressed(0, 38) then
                                        TriggerServerEvent('qb-weapons:server:TakeBackWeapon', k, data)
                                    end
                                end
                            end
                        end
                    end
                end
            end
            if not inRange then
                Wait(1000)
            end
        end
        Wait(0)
    end
end)
