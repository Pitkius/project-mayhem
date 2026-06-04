local QBCore = exports['qb-core']:GetCoreObject()

ShopSession = ShopSession or { active = false, kind = nil }

local function notify(msg, t)
    QBCore.Functions.Notify(msg, t or 'error')
end

function ShopSession.IsActive()
    return ShopSession.active == true
end

function ShopSession.Teardown(reloadSkin)
    if not ShopSession.active and not ShopSession.inCreator then return end

    CharCamera.disable()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)

    if reloadSkin then
        TriggerServerEvent('qb-clothing:loadPlayerSkin')
    end

    ShopSession.active = false
    ShopSession.kind = nil
    ShopSession.inCreator = false
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })

    SetTimeout(80, function()
        TriggerEvent('qb-clothing:client:onMenuClose')
    end)
end

local function setupShopPed(skinJson, gender)
    local ped = PlayerPedId()
    ShopSession.previewPed = ped
    CharAppearance.setPreviewPed(ped)
    if skinJson then
        CharAppearance.loadFromJson(skinJson)
    else
        CharAppearance.init(gender or 0)
    end
    FreezeEntityPosition(ped, true)
    local c = GetEntityCoords(ped)
    local h = GetEntityHeading(ped)
    CharCamera.setShopAnchor(vector4(c.x, c.y, c.z, h))
    CharCamera.enable()
    if ShopSession.kind == 'barber' then
        CharCamera.setPreset('hair', true)
    else
        CharCamera.setPreset('clothes', true)
    end
end

function ShopSession.Open(kind, camLoc)
    if ShopSession.active or ShopSession.inCreator then return end
    if not LocalPlayer.state.isLoggedIn then
        return notify('Pirmiausia prisijunk prie personažo.')
    end

    kind = kind == 'clothing' and 'clothing' or 'barber'
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
        data.shopSteps = kind == 'barber' and (Config.BarberSteps or { 'hair', 'facedetails' }) or (Config.ClothingShopSteps or { 'clothes' })
        data.clothingItems = kind == 'clothing' and (Config.ClothingShopItems or {}) or nil

        local gender = 0
        if data.current and data.current.personal then
            gender = data.current.personal.gender or 0
        else
            local pd = QBCore.Functions.GetPlayerData()
            gender = pd.charinfo and pd.charinfo.gender or 0
        end

        setupShopPed(data.current and data.current.skin, gender)

        ShopSession.inCreator = true
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(true)
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

RegisterNUICallback('cancelShop', function(_, cb)
    ShopSession.Teardown(true)
    cb('ok')
end)

RegisterNUICallback('setClothing', function(data, cb)
    CharAppearance.setComponent(data.key, data.item, data.texture)
    cb('ok')
end)

exports('OpenBarber', function()
    ShopSession.Open('barber')
end)

exports('OpenClothing', function()
    ShopSession.Open('clothing')
end)
