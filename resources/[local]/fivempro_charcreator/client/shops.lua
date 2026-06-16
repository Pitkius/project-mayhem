local QBCore = exports['qb-core']:GetCoreObject()

ShopSession = ShopSession or { active = false, kind = nil }

local function notify(msg, t)
    QBCore.Functions.Notify(msg, t or 'error')
end

function ShopSession.IsActive()
    return ShopSession.active == true
end

function ShopSession.Teardown(reloadSkin)
    local kind = ShopSession.kind
    CharCamera.disable()

    local ped = PlayerPedId()
    if ped and ped ~= 0 and DoesEntityExist(ped) then
        ClearPedTasks(ped)
        FreezeEntityPosition(ped, false)
        SetEntityCollision(ped, true, true)
        SetEntityVisible(ped, true, false)
        ResetEntityAlpha(ped)
    end
    SetPlayerControl(PlayerId(), true, 0)

    if ShopSession.active and reloadSkin then
        if ShopSession.originalSkinJson then
            CharAppearance.setPreviewPed(ped)
            CharAppearance.loadFromJson(ShopSession.originalSkinJson)
        end
        TriggerServerEvent('qb-clothes:loadPlayerSkin')
    elseif ShopSession.active and kind == 'tattoo' and not reloadSkin then
        TriggerServerEvent('qb-clothes:loadPlayerSkin')
    end

    ShopSession.active = false
    ShopSession.kind = nil
    ShopSession.previewPed = nil
    ShopSession.originalSkinJson = nil
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })

    SetTimeout(80, function()
        TriggerEvent('qb-clothing:client:onMenuClose')
    end)
end

local function getSessionGender(data)
    if data and data.current and data.current.personal then
        return data.current.personal.gender or 0
    end
    local pd = QBCore.Functions.GetPlayerData()
    return pd and pd.charinfo and pd.charinfo.gender or 0
end

local function applyOpts()
    local tattooShop = ShopSession.kind == 'tattoo'
    local pd = QBCore.Functions.GetPlayerData()
    local gender = pd and pd.charinfo and pd.charinfo.gender or 0
    return { gender = gender, tattooShop = tattooShop }
end

local function setupShopPed(skinJson, gender, kind)
    local ped = PlayerPedId()
    ShopSession.previewPed = ped
    CharAppearance.setPreviewPed(ped)
    local opts = { gender = gender or 0, tattooShop = kind == 'tattoo' }
    if skinJson then
        CharAppearance.loadFromJson(skinJson, opts)
    else
        CharAppearance.init(gender or 0)
        CharAppearance.applyToPed(ped, CharAppearance.getSkin(), opts)
    end
    FreezeEntityPosition(ped, true)
    local c = GetEntityCoords(ped)
    local h = GetEntityHeading(ped)
    CharCamera.setShopAnchor(vector4(c.x, c.y, c.z, h))
    CharCamera.setTargetPed(ped)
    CharCamera.enable()
    if kind == 'barber' then
        CharCamera.setPreset('hair')
    elseif kind == 'tattoo' then
        CharCamera.setPreset('body')
    else
        CharCamera.setPreset('body')
    end
end

function ShopSession.Open(kind, camLoc)
    if ShopSession.active then return end
    if exports[GetCurrentResourceName()]:IsInCreator() then return end
    if not LocalPlayer.state.isLoggedIn then
        return notify('Pirmiausia prisijunk prie personažo.')
    end

    kind = (kind == 'clothing' or kind == 'barber' or kind == 'tattoo') and kind or 'clothing'
    ShopSession.kind = kind
    ShopSession.active = true

    QBCore.Functions.TriggerCallback('fivempro_charcreator:server:getSession', function(data)
        if not data or not data.ok then
            ShopSession.active = false
            ShopSession.kind = nil
            return notify('Nepavyko užkrauti išvaizdos.')
        end

        data.editMode = true
        data.shopMode = kind
        if kind == 'barber' then
            data.shopSteps = Config.BarberSteps or { 'hair', 'facedetails' }
        elseif kind == 'tattoo' then
            data.shopSteps = Config.TattooShopSteps or { 'tattoos' }
            data.tattooZones = Config.TattooZones or {}
        else
            data.shopSteps = Config.ClothingShopSteps or { 'clothes' }
            data.clothingItems = Config.ClothingShopItems or {}
        end

        local gender = getSessionGender(data)

        if kind == 'clothing' or kind == 'tattoo' then
            ShopSession.originalSkinJson = data.current and data.current.skin or nil
        else
            ShopSession.originalSkinJson = nil
        end

        setupShopPed(data.current and data.current.skin, gender, kind)

        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(false)
        SendNUIMessage({
            action = 'openShop',
            data = data,
        })
    end)
end

RegisterNetEvent('fivempro_charcreator:client:openShop', function(arg1, _)
    local kind = arg1
    if type(arg1) == 'table' then
        kind = arg1.shopKind or arg1.kind or 'clothing'
    elseif type(arg1) ~= 'string' then
        kind = 'clothing'
    end
    ShopSession.Open(kind)
end)

RegisterNetEvent('fivempro_charcreator:client:openClothingShop', function()
    ShopSession.Open('clothing')
end)

RegisterNetEvent('fivempro_charcreator:client:openBarberShop', function()
    ShopSession.Open('barber')
end)

RegisterNetEvent('fivempro_charcreator:client:openTattooShop', function()
    ShopSession.Open('tattoo')
end)

RegisterNUICallback('cancelShop', function(_, cb)
    ShopSession.Teardown(true)
    cb('ok')
end)

RegisterNUICallback('saveShop', function(_, cb)
    if not ShopSession.active then
        cb('ok')
        return
    end

    local pd = QBCore.Functions.GetPlayerData()
    local gender = pd and pd.charinfo and pd.charinfo.gender or 0
    local model = CharAppearance.modelHash(gender)
    local skinJson = json.encode(CharAppearance.exportForSave())

    if ShopSession.kind == 'clothing' then
        QBCore.Functions.TriggerCallback('fivempro_charcreator:server:saveClothingShop', function(ok, msg)
            if ok then
                ShopSession.originalSkinJson = nil
                ShopSession.Teardown(false)
                QBCore.Functions.Notify(msg or 'Išsaugota.', 'success')
            else
                ShopSession.Teardown(true)
                QBCore.Functions.Notify(msg or 'Nepakanka pinigų — drabužiai nuimti.', 'error')
            end
            cb('ok')
        end, model, skinJson, ShopSession.originalSkinJson)
        return
    end

    if ShopSession.kind == 'tattoo' then
        QBCore.Functions.TriggerCallback('fivempro_charcreator:server:saveTattooShop', function(ok, msg)
            if ok then
                ShopSession.originalSkinJson = nil
                ShopSession.Teardown(false)
                QBCore.Functions.Notify(msg or 'Išsaugota.', 'success')
            else
                ShopSession.Teardown(true)
                QBCore.Functions.Notify(msg or 'Nepakanka pinigų — tatuiruotės nuimtos.', 'error')
            end
            cb('ok')
        end, model, skinJson, ShopSession.originalSkinJson)
        return
    end

    TriggerServerEvent('qb-clothing:saveSkin', model, skinJson)
    ShopSession.Teardown(false)
    QBCore.Functions.Notify('Išsaugota.', 'success')
    cb('ok')
end)

RegisterNUICallback('setClothing', function(data, cb)
    CharAppearance.setComponent(data.key, data.item, data.texture)
    cb('ok')
end)

RegisterNUICallback('getTattooZoneCatalog', function(data, cb)
    local pd = QBCore.Functions.GetPlayerData()
    local gender = pd and pd.charinfo and pd.charinfo.gender or 0
    cb(CharTattoos.getZoneCatalog(data.zone or 'ZONE_TORSO', gender))
end)

RegisterNUICallback('getPlayerTattoos', function(_, cb)
    local skin = CharAppearance.getSkin()
    cb(skin and skin.tattoos or {})
end)

RegisterNUICallback('toggleTattoo', function(data, cb)
    local skin = CharAppearance.getSkin()
    if not skin then
        cb({ tattoos = {} })
        return
    end
    CharTattoos.toggle(skin, data.name, data.zone)
    local ped = ShopSession.previewPed or PlayerPedId()
    CharTattoos.refreshPreview(ped, skin, applyOpts().gender, ShopSession.kind == 'tattoo')
    cb({ tattoos = skin.tattoos })
end)

RegisterNUICallback('clearTattooZone', function(data, cb)
    local skin = CharAppearance.getSkin()
    if not skin then
        cb({ tattoos = {} })
        return
    end
    CharTattoos.clearZone(skin, data.zone)
    local ped = ShopSession.previewPed or PlayerPedId()
    CharTattoos.refreshPreview(ped, skin, applyOpts().gender, ShopSession.kind == 'tattoo')
    cb({ tattoos = skin.tattoos })
end)

RegisterNUICallback('setTattooZoneCamera', function(data, cb)
    CharCamera.forTattooZone(data.zone)
    cb('ok')
end)

exports('OpenBarber', function()
    ShopSession.Open('barber')
end)

exports('OpenClothing', function()
    ShopSession.Open('clothing')
end)

exports('OpenTattoo', function()
    ShopSession.Open('tattoo')
end)
