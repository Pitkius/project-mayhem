local QBCore = exports['qb-core']:GetCoreObject()

local activeSkin = nil
local slotBackups = {}
local slotRemoved = {}
local selfUpdating = false
local radialMenuOpen = false

local CLOTHING_SLOTS = {
    mask = { label = 'Kaukė', offLabel = 'kaukę', commands = { 'mask', 'kauke' } },
    hat = { label = 'Kepurė', offLabel = 'kepurę', commands = { 'hat', 'kepure' }, prop = 0 },
    glass = { label = 'Akiniai', offLabel = 'akinius', commands = { 'glasses', 'akiniai', 'ak' } },
    ear = { label = 'Ausinukai', offLabel = 'ausinukus', commands = { 'ear', 'ausinukai' } },
    watch = { label = 'Laikrodis', offLabel = 'laikrodį', commands = { 'watch', 'laikrodis' } },
    bracelet = { label = 'Apyrankė', offLabel = 'apyrankę', commands = { 'bracelet', 'apyranke' } },
    accessory = { label = 'Kaklaraištis', offLabel = 'kaklaraištį', commands = { 'chain', 'kaklaruoste' } },
    ['t-shirt'] = { label = 'Marškinėliai', offLabel = 'marškinėlius', commands = { 'shirt', 'marskiniai', 'mar' } },
    torso2 = { label = 'Striukė / viršus', offLabel = 'striukę', commands = { 'top', 'striuke', 'virsus' } },
    vest = { label = 'Liemenė', offLabel = 'liemenę', commands = { 'vest', 'liemene' } },
    arms = { label = 'Pirštinės / rankos', offLabel = 'pirštines', commands = { 'gloves', 'pirstines' } },
    pants = { label = 'Kelnės', offLabel = 'kelnes', commands = { 'pants', 'kelnes' } },
    shoes = { label = 'Batai', offLabel = 'batus', commands = { 'shoes', 'batai' } },
    bag = { label = 'Kuprinė', offLabel = 'kuprinę', commands = { 'bag', 'kuprine' } },
    decals = { label = 'Ženkleliai', offLabel = 'ženklelius', commands = { 'decals', 'zenkleliai' } },
}

local COMMAND_TO_SLOT = {}
for slotKey, cfg in pairs(CLOTHING_SLOTS) do
    for _, cmd in ipairs(cfg.commands) do
        COMMAND_TO_SLOT[cmd:lower()] = slotKey
    end
end

local function isFemalePed(ped)
    return GetEntityModel(ped) == `mp_f_freemode_01`
end

local function getUndressedDefault(slotKey, ped)
    local female = isFemalePed(ped)
    local defaults = {
        mask = { item = 0, texture = 0 },
        hat = { item = -1, texture = 0 },
        glass = { item = -1, texture = 0 },
        ear = { item = -1, texture = 0 },
        watch = { item = -1, texture = 0 },
        bracelet = { item = -1, texture = 0 },
        accessory = { item = 0, texture = 0 },
        vest = { item = 0, texture = 0 },
        bag = { item = 0, texture = 0 },
        decals = { item = 0, texture = 0 },
        arms = { item = 15, texture = 0 },
        ['t-shirt'] = { item = 15, texture = 0 },
        torso2 = { item = 15, texture = 0 },
        pants = { item = female and 15 or 14, texture = 0 },
        shoes = { item = female and 35 or 34, texture = 0 },
    }
    return defaults[slotKey]
end

local function isSlotEmpty(slotKey, ped)
    local def = getUndressedDefault(slotKey, ped)
    if not def then return true end
    if not activeSkin or not activeSkin[slotKey] then return true end
    local cur = activeSkin[slotKey]
    if cur.item == def.item and (cur.texture or 0) == (def.texture or 0) then
        return true
    end
    if slotKey == 'hat' or slotKey == 'glass' or slotKey == 'ear' or slotKey == 'watch' or slotKey == 'bracelet' then
        return (cur.item or -1) <= 0
    end
    return false
end

local function canToggleClothing()
    if not LocalPlayer.state.isLoggedIn then
        return false, 'Pirmiausia prisijunk prie personažo.'
    end
    local ped = PlayerPedId()
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        return false, 'Personažas nerastas.'
    end
    if IsEntityDead(ped) then
        return false, 'Negali keisti drabužių būdamas negyvas.'
    end
    local pd = QBCore.Functions.GetPlayerData()
    if pd and pd.metadata and pd.metadata.ishandcuffed then
        return false, 'Negali keisti drabužių surakintas.'
    end
    if GetResourceState('fivempro_charcreator') == 'started' then
        local ok, inCreator = pcall(function()
            return exports['fivempro_charcreator']:IsInCreator()
        end)
        if ok and inCreator then
            return false, 'Uždaryk personažo kūrimą.'
        end
    end
    return true
end

local function ensureActiveSkin()
    if activeSkin then return true end
    QBCore.Functions.Notify('Drabužių duomenys dar kraunasi — bandyk po sekundės.', 'error')
    return false
end

local function applyActiveSkin()
    if not activeSkin then return end
    selfUpdating = true
    TriggerEvent('qb-clothing:client:loadPlayerClothing', activeSkin, PlayerPedId())
    selfUpdating = false
end

local function saveActiveSkin()
    if not activeSkin then return end
    local ped = PlayerPedId()
    local modelName = isFemalePed(ped) and 'mp_f_freemode_01' or 'mp_m_freemode_01'
    TriggerServerEvent('qb-clothing:saveSkin', modelName, json.encode(activeSkin))
end

local function playToggleAnim(slotKey)
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return end
    local dict, anim
    if slotKey == 'mask' then
        dict, anim = 'mp_masks@on_foot', 'put_on_mask'
    elseif slotKey == 'hat' or slotKey == 'glass' then
        dict, anim = 'clothingspecs', 'take_off'
    else
        dict, anim = 'clothingtie', 'try_tie_negative_a'
    end
    RequestAnimDict(dict)
    local deadline = GetGameTimer() + 2000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do
        Wait(10)
    end
    if HasAnimDictLoaded(dict) then
        TaskPlayAnim(ped, dict, anim, 4.0, 3.0, 700, 49, 0.0, false, false, false)
    end
end

local function buildRadialSlotStates()
    local slots = {}
    for slotKey, cfg in pairs(CLOTHING_SLOTS) do
        slots[slotKey] = {
            label = cfg.label,
            removed = slotRemoved[slotKey] == true,
        }
    end
    return slots
end

local function refreshRadialMenu()
    if not radialMenuOpen then return end
    SendNUIMessage({
        action = 'update',
        slots = buildRadialSlotStates(),
    })
end

local function closeClothingRadial()
    if not radialMenuOpen then return end
    radialMenuOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

function ToggleClothingSlot(slotKey)
    local ok, err = canToggleClothing()
    if not ok then
        QBCore.Functions.Notify(err, 'error')
        return
    end
    if not ensureActiveSkin() then return end

    local cfg = CLOTHING_SLOTS[slotKey]
    if not cfg then return end

    local ped = PlayerPedId()
    if not activeSkin[slotKey] then
        activeSkin[slotKey] = { item = 0, texture = 0 }
    end

    if slotRemoved[slotKey] then
        local backup = slotBackups[slotKey]
        if not backup then
            QBCore.Functions.Notify(('Nėra išsaugotos %s.'):format(cfg.offLabel), 'error')
            return
        end
        activeSkin[slotKey].item = backup.item
        activeSkin[slotKey].texture = backup.texture or 0
        slotRemoved[slotKey] = nil
        slotBackups[slotKey] = nil
        playToggleAnim(slotKey)
        applyActiveSkin()
        saveActiveSkin()
        QBCore.Functions.Notify(('%s uždėta.'):format(cfg.label), 'success')
        refreshRadialMenu()
        return
    end

    if isSlotEmpty(slotKey, ped) then
        QBCore.Functions.Notify(('%s jau nusiimta.'):format(cfg.label), 'error')
        return
    end

    slotBackups[slotKey] = {
        item = activeSkin[slotKey].item,
        texture = activeSkin[slotKey].texture or 0,
    }
    local def = getUndressedDefault(slotKey, ped)
    activeSkin[slotKey].item = def.item
    activeSkin[slotKey].texture = def.texture or 0
    slotRemoved[slotKey] = true
    playToggleAnim(slotKey)
    applyActiveSkin()
    saveActiveSkin()
    QBCore.Functions.Notify(('%s nusiimta.'):format(cfg.label), 'success')
    refreshRadialMenu()
end

function RestoreAllClothing()
    local ok, err = canToggleClothing()
    if not ok then
        QBCore.Functions.Notify(err, 'error')
        return false
    end
    if not ensureActiveSkin() then return false end

    local restored = 0
    for slotKey in pairs(CLOTHING_SLOTS) do
        if slotRemoved[slotKey] and slotBackups[slotKey] then
            if not activeSkin[slotKey] then
                activeSkin[slotKey] = { item = 0, texture = 0 }
            end
            activeSkin[slotKey].item = slotBackups[slotKey].item
            activeSkin[slotKey].texture = slotBackups[slotKey].texture or 0
            slotRemoved[slotKey] = nil
            slotBackups[slotKey] = nil
            restored = restored + 1
        end
    end

    if restored <= 0 then
        QBCore.Functions.Notify('Visi drabužiai jau uždėti.', 'primary')
        return false
    end

    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then
        RequestAnimDict('clothingtie')
        local deadline = GetGameTimer() + 2000
        while not HasAnimDictLoaded('clothingtie') and GetGameTimer() < deadline do
            Wait(10)
        end
        if HasAnimDictLoaded('clothingtie') then
            TaskPlayAnim(ped, 'clothingtie', 'try_tie_negative_a', 4.0, 3.0, 900, 49, 0.0, false, false, false)
        end
    end

    applyActiveSkin()
    saveActiveSkin()
    QBCore.Functions.Notify(('Uždėta %d drabužių dalys.'):format(restored), 'success')
    refreshRadialMenu()
    return true
end

local function openClothingMenu()
    local ok, err = canToggleClothing()
    if not ok then
        QBCore.Functions.Notify(err, 'error')
        return
    end
    if not ensureActiveSkin() then return end
    if radialMenuOpen then
        closeClothingRadial()
        return
    end
    radialMenuOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        slots = buildRadialSlotStates(),
    })
end

RegisterNUICallback('clothingRadial:toggle', function(data, cb)
    local slotKey = data and (data.slotKey or data[1])
    if slotKey then
        ToggleClothingSlot(tostring(slotKey))
        refreshRadialMenu()
    end
    cb({ ok = true })
end)

RegisterNUICallback('clothingRadial:restoreAll', function(_, cb)
    RestoreAllClothing()
    cb({ ok = true })
end)

RegisterNUICallback('clothingRadial:close', function(_, cb)
    closeClothingRadial()
    cb({ ok = true })
end)

RegisterNetEvent('fivempro_basics:client:toggleClothing', function(slotKey)
    if type(slotKey) == 'table' then
        slotKey = slotKey.slotKey or slotKey[1]
    end
    if not slotKey then return end
    ToggleClothingSlot(tostring(slotKey))
end)

RegisterNetEvent('fivempro_basics:client:openClothingMenu', openClothingMenu)

RegisterNetEvent('fivempro_basics:client:toggleClothingByCommand', function(commandName)
    local slotKey = COMMAND_TO_SLOT[tostring(commandName or ''):lower()]
    if not slotKey then return end
    ToggleClothingSlot(slotKey)
end)

RegisterNetEvent('qb-clothes:loadSkin', function(isNew, _, data)
    if isNew or not data then return end
    local ok, decoded = pcall(json.decode, data)
    if ok and type(decoded) == 'table' then
        activeSkin = decoded
        slotBackups = {}
        slotRemoved = {}
    end
end)

RegisterNetEvent('qb-clothing:client:loadPlayerClothing', function(data, ped)
    if selfUpdating then return end
    if ped and ped ~= 0 and ped ~= PlayerPedId() then return end
    if type(data) == 'table' then
        activeSkin = data
        slotBackups = {}
        slotRemoved = {}
    end
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    SetTimeout(2500, function()
        if activeSkin then return end
        TriggerServerEvent('qb-clothes:loadPlayerSkin')
    end)
end)

exports('ToggleClothingSlot', ToggleClothingSlot)
exports('OpenClothingMenu', openClothingMenu)
exports('RestoreAllClothing', RestoreAllClothing)
