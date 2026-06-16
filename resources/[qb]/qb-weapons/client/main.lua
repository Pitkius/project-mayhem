-- Variables
local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = QBCore.Functions.GetPlayerData()
local CurrentWeaponData, CanShoot, MultiplierAmount, currentWeapon = {}, true, 0, nil
local lastAutoReloadAt = 0
local lastSyncedWeapon = nil
local lastSyncedAmmo = nil
local lastAmmoSyncAt = 0
local reloadGuardUntil = 0
local isReloading = false

local AmmoItemByType = {
    AMMO_PISTOL = { 'pistol_ammo', 'pistolammo' },
    AMMO_SMG = { 'smg_ammo', 'smgammo' },
    AMMO_RIFLE = { 'rifle_ammo', 'rifleammo' },
    AMMO_SHOTGUN = { 'shotgun_ammo' },
    AMMO_MUSKET = { 'hunting_ammo' },
    AMMO_MG = { 'mg_ammo' },
    AMMO_SNIPER = { 'snp_ammo' },
}

--- QB dažnai atnaujina inventorių — skaitom iš core (pickAmmoItemForType naudoja prieš pilną PlayerData snapshot).
local function getTotalAmmoItems(itemName)
    if not itemName then return 0 end
    local pd = QBCore.Functions.GetPlayerData()
    local items = pd and pd.items or nil
    if not items then return 0 end
    local total = 0
    for _, item in pairs(items) do
        if item and item.name == itemName then
            total = total + (tonumber(item.amount) or 0)
        end
    end
    return total
end

local function pickAmmoItemForType(ammoType)
    local list = AmmoItemByType[tostring(ammoType or ''):upper()]
    if type(list) ~= 'table' then return nil end
    for _, itemName in ipairs(list) do
        if getTotalAmmoItems(itemName) > 0 then
            return itemName
        end
    end
    return list[1]
end

--- Kai GetMaxAmmoInClip grąžina 0 – apkabos dydis pagal ginklą ar tipą.
local DefaultClipByWeapon = {
    [`weapon_minismg`] = 12,
    [`weapon_machinepistol`] = 12,
    [`weapon_microsmg`] = 16,
    [`weapon_smg`] = 30,
    [`weapon_smg_mk2`] = 30,
    [`weapon_assaultsmg`] = 30,
    [`weapon_combatpdw`] = 30,
    [`weapon_pistol`] = 12,
    [`weapon_combatpistol`] = 12,
    [`weapon_appistol`] = 18,
}

local DefaultClipByAmmoType = {
    AMMO_PISTOL = 12,
    AMMO_SMG = 30,
    AMMO_RIFLE = 30,
    AMMO_SHOTGUN = 8,
    AMMO_MUSKET = 1,
    AMMO_MG = 50,
    AMMO_SNIPER = 10,
    AMMO_EMPLAUNCHER = 10,
}

local function componentHash(comp)
    if type(comp) == 'number' then return comp end
    if comp then return joaat(tostring(comp)) end
end

local function weaponHasAttachment(ped, weaponHash, weaponData, attachmentTable)
    local weaponName = weaponData and weaponData.name
    if not weaponName or type(attachmentTable) ~= 'table' then return false end
    local comp = attachmentTable[weaponName]
    if not comp then return false end
    local compHash = componentHash(comp)
    if ped and weaponHash and compHash and HasPedGotWeaponComponent(ped, weaponHash, compHash) then
        return true
    end
    local info = weaponData.info or weaponData
    if type(info) == 'table' and type(info.attachments) == 'table' then
        for _, attachment in pairs(info.attachments) do
            local attached = attachment and (attachment.component or attachment)
            if attached == comp or attached == compHash then return true end
            if type(attached) == 'string' and compHash and joaat(attached) == compHash then return true end
        end
    end
    return false
end

local function resolveAttachmentClipCapacity(weaponName, ped, weaponHash, weaponData)
    if not weaponName then return 0 end
    local cap = 0
    if weaponHasAttachment(ped, weaponHash, weaponData, WeaponAttachments.drum_attachment) then
        cap = math.max(cap, tonumber(Config.DrumClipCapacity and Config.DrumClipCapacity[weaponName]) or 0)
    end
    if weaponHasAttachment(ped, weaponHash, weaponData, WeaponAttachments.clip_attachment) then
        cap = math.max(cap, tonumber(Config.ExtendedClipCapacity and Config.ExtendedClipCapacity[weaponName]) or 0)
    end
    return cap
end

local function resolveMaxClip(ped, weaponHash, weaponData)
    local maxClip = 0
    for _, p2 in ipairs({ true, false }) do
        local hasMaxClip, maxClipAmmo = GetMaxAmmoInClip(ped, weaponHash, p2)
        if hasMaxClip and maxClipAmmo then
            maxClip = math.max(maxClip, tonumber(maxClipAmmo) or 0)
        end
    end

    local weaponName = weaponData and weaponData.name
    local attachmentCap = resolveAttachmentClipCapacity(weaponName, ped, weaponHash, weaponData)
    if attachmentCap > 0 then
        maxClip = math.max(maxClip, attachmentCap)
    end

    if maxClip > 0 then return maxClip end

    if weaponName and DefaultClipByWeapon[joaat(weaponName)] then
        return DefaultClipByWeapon[joaat(weaponName)]
    end
    local ammoType = tostring(weaponData and weaponData.ammotype or ''):upper()
    return DefaultClipByAmmoType[ammoType] or 30
end

local function getClipAmmoState(ped, weaponHash, weaponData)
    local maxClip = resolveMaxClip(ped, weaponHash, weaponData)
    local hasClip, currentClipAmmo = GetAmmoInClip(ped, weaponHash)
    local curInClip = hasClip and (tonumber(currentClipAmmo) or 0) or 0
    local totalAmmo = math.max(0, tonumber(GetAmmoInPedWeapon(ped, weaponHash)) or 0)
    local clipMissing = math.max(0, maxClip - curInClip)
    return curInClip, maxClip, clipMissing, totalAmmo
end

--- Kai kurie resursai ar būsenos palieka begalinę apkabą — tada šūviai nenaudoja kulkų.
local function clearPedWeaponInfiniteAmmo(ped, weaponHash)
    if not ped or ped == 0 or not weaponHash or weaponHash == 0 or weaponHash == `WEAPON_UNARMED` then return end
    SetPedInfiniteAmmoClip(ped, false)
    SetPedInfiniteAmmo(ped, false, weaponHash)
end

local function applyWeaponAmmoState(ped, weaponHash, ammo, weaponData)
    ammo = math.max(0, tonumber(ammo) or 0)
    weaponData = weaponData or QBCore.Shared.Weapons[weaponHash]
    SetPedAmmo(ped, weaponHash, ammo)
    local maxClip = resolveMaxClip(ped, weaponHash, weaponData)
    if maxClip > 0 then
        local _, clipNow = GetAmmoInClip(ped, weaponHash)
        local curClip = math.max(0, tonumber(clipNow) or 0)
        if curClip > 0 and curClip <= maxClip and curClip <= ammo then
            SetAmmoInClip(ped, weaponHash, curClip)
        else
            SetAmmoInClip(ped, weaponHash, math.min(ammo, maxClip))
        end
    end
    clearPedWeaponInfiniteAmmo(ped, weaponHash)
end

--- AddAmmoToPed kai kuriems SMG (pvz. Mini SMG) neužpildo apkabos — priverstinai SetAmmoInClip.
local function loadBulletsIntoClip(ped, weaponHash, weaponData, bulletsToLoad)
    bulletsToLoad = math.max(0, tonumber(bulletsToLoad) or 0)
    if bulletsToLoad <= 0 or not ped or ped == 0 or not weaponHash or weaponHash == 0 then return 0 end

    clearPedWeaponInfiniteAmmo(ped, weaponHash)
    local maxClip = resolveMaxClip(ped, weaponHash, weaponData)
    local _, clipBefore = GetAmmoInClip(ped, weaponHash)
    local curClip = math.max(0, tonumber(clipBefore) or 0)
    local toLoad = math.min(bulletsToLoad, math.max(0, maxClip - curClip))
    if toLoad <= 0 then return 0 end

    local newClip = curClip + toLoad
    local totalBefore = math.max(0, tonumber(GetAmmoInPedWeapon(ped, weaponHash)) or 0)
    local reserve = math.max(0, totalBefore - curClip)
    local newTotal = reserve + newClip

    SetPedAmmo(ped, weaponHash, newTotal)
    SetAmmoInClip(ped, weaponHash, newClip)
    clearPedWeaponInfiniteAmmo(ped, weaponHash)

    local _, clipAfter = GetAmmoInClip(ped, weaponHash)
    local loaded = math.max(0, (tonumber(clipAfter) or newClip) - curClip)
    if loaded <= 0 then
        SetPedAmmo(ped, weaponHash, newTotal)
        SetAmmoInClip(ped, weaponHash, newClip)
        loaded = toLoad
    end
    return math.min(loaded, toLoad)
end

local function getReloadWaitMs()
    local t = tonumber(Config.ReloadTime)
    if t and t > 0 then return t end
    return 2800
end

--- GTA rodo perkrovos animaciją tik kai rezerve yra kulkų — laikinai pridedam, po animacijos atstatom būseną.
local function stopReloadAnimation(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    ClearPedTasks(ped)
    ClearPedSecondaryTask(ped)
    SetPedCurrentWeaponVisible(ped, true, false, false, false)
end

local function playWeaponReloadAnimation(ped, weaponHash, bulletsToLoad)
    if not ped or ped == 0 or not weaponHash or weaponHash == 0 or weaponHash == `WEAPON_UNARMED` then
        Wait(400)
        return
    end

    bulletsToLoad = math.max(0, tonumber(bulletsToLoad) or 0)
    local hasClip, clipNow = GetAmmoInClip(ped, weaponHash)
    clipNow = hasClip and (tonumber(clipNow) or 0) or 0
    local totalBefore = math.max(0, tonumber(GetAmmoInPedWeapon(ped, weaponHash)) or 0)
    local reserve = math.max(0, totalBefore - clipNow)

    if reserve < 1 and bulletsToLoad > 0 then
        SetPedAmmo(ped, weaponHash, totalBefore + bulletsToLoad)
    end

    clearPedWeaponInfiniteAmmo(ped, weaponHash)
    SetCurrentPedWeapon(ped, weaponHash, true)

    local sawReload = false
    if not IsPedInAnyVehicle(ped, false) then
        MakePedReload(ped)
        if not IsPedReloading(ped) then
            TaskReloadWeapon(ped, true)
        end

        local deadline = GetGameTimer() + getReloadWaitMs()
        while GetGameTimer() < deadline do
            if not DoesEntityExist(ped) then break end
            if IsPedReloading(ped) then
                sawReload = true
            elseif sawReload then
                break
            end
            Wait(0)
        end
    else
        Wait(math.min(1200, getReloadWaitMs()))
    end

    if not sawReload then
        Wait(math.min(900, getReloadWaitMs()))
    end

    stopReloadAnimation(ped)
    SetPedAmmo(ped, weaponHash, totalBefore)
    SetAmmoInClip(ped, weaponHash, clipNow)
    clearPedWeaponInfiniteAmmo(ped, weaponHash)
end

-- Handlers

--- QB dažnai atnaujina inventorių per `UpdatePlayerDataField` — visada skaitom iš core, ne iš pasenusios `PlayerData` kopijos.
local function getItemsFromCore()
    local pd = QBCore.Functions.GetPlayerData()
    return pd and pd.items or nil
end

local holsterApplyPending = false

local function isThrowableInventoryWeaponName(name)
    if not name then return true end
    local n = tostring(name):lower()
    if n == 'weapon_unarmed' then return true end
    local throwEventBlock = {
        weapon_stickybomb = true,
        weapon_pipebomb = true,
        weapon_smokegrenade = true,
        weapon_flare = true,
        weapon_proxmine = true,
        weapon_ball = true,
        weapon_molotov = true,
        weapon_grenade = true,
        weapon_bzgas = true,
        weapon_snowball = true,
    }
    if throwEventBlock[n] then return true end
    for _, t in ipairs(Config.Throwables or {}) do
        local key = tostring(t):lower()
        if n == ('weapon_' .. key) or n == key then return true end
    end
    return false
end

local function isExternallyBackCarriedWeapon(name)
    if GetResourceState('fivempro_basics') ~= 'started' then return false end
    local ok, res = pcall(function()
        return exports['fivempro_basics']:IsLongBackWeapon(name)
    end)
    return ok and res == true
end

--- Visi inventoriaus ginklai ant pedo (paslėpti), išskyrus dabar pasirinktą — kad matytųsi ant nugaros/kojų.
function applyHolsteredWeaponsFromInventory()
    if not LocalPlayer.state.isLoggedIn then return end
    if currentWeapon and isThrowableInventoryWeaponName(currentWeapon) then return end
    local ped = PlayerPedId()
    RemoveAllPedWeapons(ped, true)

    local items = getItemsFromCore()
    if not items then
        SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
        return
    end

    local shownHash = nil
    if currentWeapon then
        shownHash = joaat(currentWeapon)
    end

    for _, item in pairs(items) do
        if not item or item.type ~= 'weapon' or (tonumber(item.amount) or 0) <= 0 then goto continue end
        local name = tostring(item.name or '')
        if isThrowableInventoryWeaponName(name) then goto continue end

        local h = joaat(name)
        local ammo = tonumber(item.info and item.info.ammo) or 0
        if name == 'weapon_petrolcan' or name == 'weapon_fireextinguisher' then
            ammo = 4000
        end

        local hidden = not shownHash or h ~= shownHash

        if hidden and isExternallyBackCarriedWeapon(name) then
            goto continue
        end

        GiveWeaponToPed(ped, h, ammo, hidden, false)
        applyWeaponAmmoState(ped, h, ammo, item)

        local weaponInfo = item.info or {}
        if weaponInfo.attachments then
            for _, attachment in pairs(weaponInfo.attachments) do
                local comp = attachment.component
                if type(comp) == 'number' then
                    GiveWeaponComponentToPed(ped, h, comp)
                elseif comp then
                    GiveWeaponComponentToPed(ped, h, joaat(tostring(comp)))
                end
            end
        end
        if weaponInfo.tint then
            SetPedWeaponTintIndex(ped, h, weaponInfo.tint)
        end

        ::continue::
    end

    if shownHash and shownHash ~= 0 and shownHash ~= `WEAPON_UNARMED` then
        SetCurrentPedWeapon(ped, shownHash, true)
        clearPedWeaponInfiniteAmmo(ped, shownHash)
    else
        SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
    end
end

local function scheduleHolsteredWeaponVisuals()
    if holsterApplyPending then return end
    holsterApplyPending = true
    SetTimeout(200, function()
        holsterApplyPending = false
        applyHolsteredWeaponsFromInventory()
        if GetResourceState('fivempro_basics') == 'started' then
            TriggerEvent('fivempro_basics:client:refreshSlungWeapons')
        end
    end)
end

local function resolveCurrentWeaponDataByName(weaponName)
    local items = getItemsFromCore()
    if not items then return nil end
    for _, item in pairs(items) do
        if item and item.type == 'weapon' and item.name == weaponName then
            return item
        end
    end
    return nil
end

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    QBCore.Functions.TriggerCallback('qb-weapons:server:GetConfig', function(RepairPoints)
        for k, data in pairs(RepairPoints) do
            Config.WeaponRepairPoints[k].IsRepairing = data.IsRepairing
            Config.WeaponRepairPoints[k].RepairingData = data.RepairingData
        end
    end)
    SetTimeout(2600, function()
        scheduleHolsteredWeaponVisuals()
    end)
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    for k in pairs(Config.WeaponRepairPoints) do
        Config.WeaponRepairPoints[k].IsRepairing = false
        Config.WeaponRepairPoints[k].RepairingData = {}
    end
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    PlayerData = val or QBCore.Functions.GetPlayerData() or {}
end)

RegisterNetEvent('QBCore:Player:UpdatePlayerDataField', function(field, _)
    PlayerData = QBCore.Functions.GetPlayerData() or {}
    if field == 'items' then
        if GetGameTimer() < reloadGuardUntil then return end
        if not (currentWeapon and isThrowableInventoryWeaponName(currentWeapon)) then
            scheduleHolsteredWeaponVisuals()
        end
    end
end)

-- Functions

local function DrawText3Ds(x, y, z, text)
    if GetResourceState('fivempro_fonts') == 'started' then
        exports['fivempro_fonts']:DrawText3D(x, y, z, text)
        return
    end
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
    -- Tik aiškus `false` blokuoja šaudymą (sugęstas ginklas). `nil` = gali šaudyti.
    -- Tai ne liečia šovinių naudojimo / R perkrovimo / priedų – tik LMB šūvių logiką.
    CanShoot = bool ~= false
end)

RegisterNetEvent('qb-weapons:client:SetWeaponQuality', function(amount)
    if CurrentWeaponData and next(CurrentWeaponData) then
        TriggerServerEvent('qb-weapons:server:SetWeaponQuality', CurrentWeaponData, amount)
    end
end)

RegisterNetEvent('qb-weapons:client:AddAmmo', function(ammoType, amount, itemData)
    if isReloading then return end

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

    local normalizedAmmoType = tostring(ammoType or ''):upper()
    local weaponAmmoNorm = tostring(selectedWeaponData.ammotype or ''):upper()
    if weaponAmmoNorm == '' and selectedWeaponData.name and selectedWeaponData.name:find('assaultrifle', 1, true) then
        weaponAmmoNorm = 'AMMO_RIFLE'
    end
    if weaponAmmoNorm ~= normalizedAmmoType then
        QBCore.Functions.Notify(Lang:t('error.wrong_ammo'), 'error')
        return
    end

    if (not CurrentWeaponData or not CurrentWeaponData.slot or CurrentWeaponData.name ~= selectedWeaponData.name) then
        CurrentWeaponData = resolveCurrentWeaponDataByName(selectedWeaponData.name) or CurrentWeaponData
    end

    local curInClip, maxC, clipMissing = getClipAmmoState(ped, weapon, CurrentWeaponData or selectedWeaponData)

    if clipMissing <= 0 then
        QBCore.Functions.Notify(Lang:t('error.max_ammo') or 'Apkaba pilna.', 'error')
        return
    end

    local ammoItemName = pickAmmoItemForType(normalizedAmmoType) or (itemData and itemData.name)
    -- Ammo items are treated as bullet units (1 item = 1 bullet).
    local availableBullets = 0
    if itemData and itemData.quickReload then
        availableBullets = math.max(0, tonumber(amount) or 0)
    else
        availableBullets = getTotalAmmoItems(ammoItemName)
    end
    if availableBullets <= 0 then
        QBCore.Functions.Notify('No ammo in inventory.', 'error')
        return
    end

    local bulletsToLoad = math.min(clipMissing, availableBullets)
    if maxC > 0 then
        bulletsToLoad = math.min(bulletsToLoad, maxC)
    end
    if bulletsToLoad <= 0 then
        return
    end

    local function finishReload()
        reloadGuardUntil = GetGameTimer() + 600
        ped = PlayerPedId()
        weapon = GetSelectedPedWeapon(ped)
        local current = QBCore.Shared.Weapons[weapon]

        if not current or tostring(current.ammotype or ''):upper() ~= normalizedAmmoType then
            reloadGuardUntil = 0
            stopReloadAnimation(ped)
            return QBCore.Functions.Notify(Lang:t('error.wrong_ammo'), 'error')
        end

        local weaponPayload = CurrentWeaponData
        if not weaponPayload or not weaponPayload.name then
            weaponPayload = resolveCurrentWeaponDataByName(current.name) or selectedWeaponData
        end

        local curInClipNow, maxCNow, clipMissingNow = getClipAmmoState(ped, weapon, weaponPayload or current)
        if clipMissingNow <= 0 then
            reloadGuardUntil = 0
            stopReloadAnimation(ped)
            return
        end

        local bulletsNow = math.min(clipMissingNow, availableBullets)
        if maxCNow > 0 then
            bulletsNow = math.min(bulletsNow, maxCNow)
        end
        if bulletsNow <= 0 then
            reloadGuardUntil = 0
            stopReloadAnimation(ped)
            return
        end

        local reallyLoaded = loadBulletsIntoClip(ped, weapon, current, bulletsNow)
        if reallyLoaded <= 0 then
            reloadGuardUntil = 0
            stopReloadAnimation(ped)
            return QBCore.Functions.Notify('Nepavyko užpildyti apkabos.', 'error')
        end

        local refreshedAmmo = GetAmmoInPedWeapon(ped, weapon)
        local unitsToRemove = math.min(reallyLoaded, bulletsNow, availableBullets)
        local payload = CurrentWeaponData
        if not payload or not payload.name then
            payload = resolveCurrentWeaponDataByName(current.name)
        end
        if payload and payload.name then
            TriggerServerEvent('qb-weapons:server:UpdateWeaponAmmo', payload, refreshedAmmo)
        end
        local ammoInvSlot = itemData and tonumber(itemData.slot)
        TriggerServerEvent('qb-weapons:server:removeWeaponAmmoItem', ammoItemName, unitsToRemove, ammoInvSlot)
        if ammoItemName and QBCore.Shared.Items[ammoItemName] then
            TriggerEvent('qb-inventory:client:ItemBox', QBCore.Shared.Items[ammoItemName], 'use', unitsToRemove)
        end
        QBCore.Functions.Notify(Lang:t('success.reloaded'), 'success')

        SetTimeout(150, function()
            if currentWeapon ~= current.name then return end
            local p = PlayerPedId()
            local w = GetSelectedPedWeapon(p)
            if w ~= weapon then return end
            applyWeaponAmmoState(p, w, GetAmmoInPedWeapon(p, w), CurrentWeaponData)
            reloadGuardUntil = 0
        end)
    end

    isReloading = true
    reloadGuardUntil = GetGameTimer() + getReloadWaitMs() + 900
    local reloadPed = ped
    local reloadWeapon = weapon
    local reloadBullets = bulletsToLoad

    CreateThread(function()
        local ok, err = pcall(function()
            playWeaponReloadAnimation(reloadPed, reloadWeapon, reloadBullets)
            finishReload()
        end)
        if not ok then
            print(('[qb-weapons] reload error: %s'):format(tostring(err)))
            stopReloadAnimation(PlayerPedId())
            reloadGuardUntil = 0
        end
        isReloading = false
    end)
end)

RegisterNetEvent('qb-weapons:client:UseWeapon', function(weaponData, shootbool)
    local info = weaponData and weaponData.info
    if not info or info.quality == nil then
        shootbool = true
    elseif shootbool == nil then
        shootbool = tonumber(info.quality) > 0
    end
    local ped = PlayerPedId()
    local weaponName = tostring(weaponData.name)
    local weaponHash = joaat(weaponData.name)
    local weaponInfo = weaponData.info or {}
    if currentWeapon == weaponName then
        TriggerEvent('qb-weapons:client:DrawWeapon', nil)
        TriggerEvent('qb-weapons:client:SetCurrentWeapon', nil, shootbool)
        currentWeapon = nil
        applyHolsteredWeaponsFromInventory()
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
        currentWeapon = weaponName
        applyHolsteredWeaponsFromInventory()
        weaponHash = joaat(weaponData.name)
        local syncedAmmo = GetAmmoInPedWeapon(ped, weaponHash)
        TriggerServerEvent('qb-weapons:server:UpdateWeaponAmmo', weaponData, syncedAmmo)
    end
end)

RegisterNetEvent('qb-weapons:client:CheckWeapon', function(weaponName)
    local wname = weaponName and tostring(weaponName):lower()
    if not wname or currentWeapon ~= wname then return end
    TriggerEvent('qb-weapons:ResetHolster')
    TriggerEvent('qb-weapons:client:SetCurrentWeapon', nil, CanShoot)
    currentWeapon = nil
    applyHolsteredWeaponsFromInventory()
end)

-- Threads

CreateThread(function()
    SetWeaponsNoAutoswap(true)
end)

--- Kai kurie resursai vėl įjungia begalinę apkabą – blokuoja tikrą kulkų mažėjimą.
CreateThread(function()
    while true do
        Wait(75)
        local ped = PlayerPedId()
        if IsPedArmed(ped, 7) then
            local w = GetSelectedPedWeapon(ped)
            if w and w ~= 0 and w ~= `WEAPON_UNARMED` then
                clearPedWeaponInfiniteAmmo(ped, w)
            end
        end
    end
end)

CreateThread(function()
    while true do
        -- R = INPUT_RELOAD (45). Kiti resursai gali išjungti valdiklį — vis tiek leidžiame ir tikriname „disabled“ būseną.
        EnableControlAction(0, 45, true)
        local reloadPressed = IsControlJustPressed(0, 45) or IsDisabledControlJustPressed(0, 45)
        if reloadPressed then
            local now = GetGameTimer()
            if not isReloading and now - lastAutoReloadAt > 500 then
                lastAutoReloadAt = now

                local ped = PlayerPedId()
                local weapon = GetSelectedPedWeapon(ped)
                local selectedWeaponData = QBCore.Shared.Weapons[weapon]
                if selectedWeaponData and selectedWeaponData.name ~= 'weapon_unarmed' then
                    local ammoType = tostring(selectedWeaponData.ammotype or ''):upper()
                    local ammoItemName = pickAmmoItemForType(ammoType)
                    if ammoItemName and PlayerData and PlayerData.items then
                        for _, item in pairs(PlayerData.items) do
                            if item and item.name == ammoItemName and (tonumber(item.amount) or 0) > 0 then
                                local invSlot = tonumber(item.slot)
                                TriggerServerEvent('qb-weapons:server:requestQuickReload', ammoItemName, ammoType, invSlot)
                                break
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
        if IsPedArmed(ped, 7) then
            local weapon = GetSelectedPedWeapon(ped)
            local selectedWeaponData = QBCore.Shared.Weapons[weapon]
            if selectedWeaponData then
                CurrentWeaponData = resolveCurrentWeaponDataByName(selectedWeaponData.name) or CurrentWeaponData
                local ammo = GetAmmoInPedWeapon(ped, weapon)
                local hasMaxTotal, maxTotalAmmo = GetMaxAmmo(ped, weapon)
                if hasMaxTotal and maxTotalAmmo and maxTotalAmmo > 0 and ammo > maxTotalAmmo then
                    SetPedAmmo(ped, weapon, maxTotalAmmo)
                    ammo = maxTotalAmmo
                end
                if CurrentWeaponData and CurrentWeaponData.name then
                    -- Tik kai ped kulkų sk. pasikeičia (šūvis / perkrova) ar keičiasi ginklas — atnaujinam ginklo item info.ammo serveryje.
                    local now = GetGameTimer()
                    local weaponSwitched = lastSyncedWeapon ~= selectedWeaponData.name
                    local ammoDelta = lastSyncedAmmo ~= ammo
                    local rareResync = (now - lastAmmoSyncAt) >= 120000
                    if weaponSwitched or ammoDelta or rareResync then
                        TriggerServerEvent('qb-weapons:server:UpdateWeaponAmmo', CurrentWeaponData, tonumber(ammo))
                        lastSyncedWeapon = selectedWeaponData.name
                        lastSyncedAmmo = ammo
                        lastAmmoSyncAt = now
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
            lastAmmoSyncAt = 0
        end
        Wait(100)
    end
end)

CreateThread(function()
    while true do
        if LocalPlayer.state.isLoggedIn then
            local ped = PlayerPedId()
            if CurrentWeaponData and next(CurrentWeaponData) then
                if IsPedShooting(ped) or IsControlJustPressed(0, 24) then
                    local weapon = GetSelectedPedWeapon(ped)
                    clearPedWeaponInfiniteAmmo(ped, weapon)
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
            local myCitizenId = (QBCore.Functions.GetPlayerData() or {}).citizenid
            for k, data in pairs(Config.WeaponRepairPoints) do
                local distance = #(pos - data.coords)
                if distance < 10 then
                    inRange = true
                    if distance < 1 then
                        if data.IsRepairing then
                            if data.RepairingData.CitizenId ~= myCitizenId then
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
                                    if data.RepairingData.CitizenId ~= myCitizenId then
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
                                elseif data.RepairingData.CitizenId == myCitizenId then
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
