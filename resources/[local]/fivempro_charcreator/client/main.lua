local QBCore = exports['qb-core']:GetCoreObject()

local previewPed = 0
local inCreator = false
local inPlaceMode = false

local function loadCreatorInterior()
    local c = Config.Interior
    local interior = GetInteriorAtCoords(c.x, c.y, c.z)
    if interior == 0 then
        interior = GetInteriorAtCoords(c.x, c.y, c.z - 1.0)
    end
    if interior ~= 0 then
        LoadInterior(interior)
        PinInteriorInMemory(interior)
        RefreshInterior(interior)
        local timeout = GetGameTimer() + 8000
        while not IsInteriorReady(interior) and GetGameTimer() < timeout do
            Wait(50)
        end
    end
end

local function loadModel(hash)
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 8000 do
        Wait(10)
        t = t + 10
    end
    return HasModelLoaded(hash)
end

local function createInteriorPed(gender)
    if previewPed ~= 0 and DoesEntityExist(previewPed) then
        DeleteEntity(previewPed)
    end
    local model = CharAppearance.modelHash(gender or 0)
    loadModel(model)
    local c = Config.PedCoords
    previewPed = CreatePed(2, model, c.x, c.y, c.z, c.w, false, true)
    SetEntityInvincible(previewPed, true)
    FreezeEntityPosition(previewPed, true)
    SetBlockingOfNonTemporaryEvents(previewPed, true)
    SetEntityCoords(previewPed, c.x, c.y, c.z, false, false, false, false)
    SetEntityHeading(previewPed, c.w)
    CharAppearance.setPreviewPed(previewPed)
    CharCamera.setTargetPed(previewPed)
    CharAppearance.init(gender or 0)
    CharAppearance.applyToPed(previewPed, CharAppearance.getSkin())
end

local function setupScene()
    DoScreenFadeOut(300)
    Wait(400)
    loadCreatorInterior()

    local hid = Config.HiddenCoords
    SetEntityCoords(PlayerPedId(), hid.x, hid.y, hid.z, false, false, false, false)
    SetEntityVisible(PlayerPedId(), false, false)
    FreezeEntityPosition(PlayerPedId(), true)

    inPlaceMode = false
    createInteriorPed(0)
    CharCamera.setTargetPed(previewPed)
    CharCamera.enable()
    CharCamera.forStep('personal')
    DoScreenFadeIn(600)
end

local function setupInPlaceEdit(sessionData)
    inPlaceMode = true
    local ped = PlayerPedId()
    previewPed = ped
    SetEntityVisible(ped, true, false)
    FreezeEntityPosition(ped, true)

    local gender = 0
    if sessionData and sessionData.current and sessionData.current.personal then
        gender = sessionData.current.personal.gender or 0
    end

    CharAppearance.setPreviewPed(ped)
    if sessionData and sessionData.current and sessionData.current.skin then
        CharAppearance.loadFromJson(sessionData.current.skin)
    else
        CharAppearance.init(gender)
        CharAppearance.applyToPed(ped, CharAppearance.getSkin())
    end

    local c = GetEntityCoords(ped)
    local h = GetEntityHeading(ped)
    CharCamera.setShopAnchor(vector4(c.x, c.y, c.z, h))
    CharCamera.setTargetPed(previewPed)
    CharCamera.enable()
end

local function teardownScene()
    CharCamera.disable()
    if inPlaceMode then
        FreezeEntityPosition(PlayerPedId(), false)
        inPlaceMode = false
    else
        SetEntityVisible(PlayerPedId(), true, false)
        FreezeEntityPosition(PlayerPedId(), false)
        if previewPed ~= 0 and DoesEntityExist(previewPed) then
            DeleteEntity(previewPed)
            previewPed = 0
        end
    end
    inCreator = false
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function closeLoadscreen()
    if GetResourceState('fivempro_loadscreen') == 'started' then
        pcall(function() exports['fivempro_loadscreen']:CloseLoadscreen() end)
    else
        ShutdownLoadingScreenNui()
        ShutdownLoadingScreen()
    end
end

local pendingEditMode = false

local function openWizardUi(editMode, preloaded)
    local function show(data)
        if not data or not data.ok then return end
        if (editMode == true or pendingEditMode) and LocalPlayer.state.isLoggedIn then
            data.editMode = true
        end
        data.clothingItems = Config.CreatorClothingItems or {}
        pendingEditMode = false
        inCreator = true
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(false)
        SendNUIMessage({
            action = 'openWizard',
            data = data,
        })
    end

    if preloaded then
        show(preloaded)
    else
        QBCore.Functions.TriggerCallback('fivempro_charcreator:server:getSession', show)
    end
end

RegisterNetEvent('fivempro_charcreator:client:openWizard', function(editMode)
    if inCreator or (ShopSession and ShopSession.IsActive()) then return end
    pendingEditMode = editMode == true
    closeLoadscreen()

    QBCore.Functions.TriggerCallback('fivempro_charcreator:server:getSession', function(data)
        if not data or not data.ok then return end
        local isEdit = (editMode == true or pendingEditMode) and LocalPlayer.state.isLoggedIn
        if isEdit then
            setupInPlaceEdit(data)
        else
            setupScene()
        end
        openWizardUi(editMode, data)
    end)
end)

RegisterNetEvent('fivempro_charcreator:client:applyAppearance', function(data)
    local model = data.model or CharAppearance.modelHash(0)
    if type(model) == 'string' then model = joaat(model) end
    local ped = PlayerPedId()

    if ShopSession and ShopSession.IsActive() then
        if data.skin then
            local ok, skinTbl = pcall(json.decode, data.skin)
            if ok and type(skinTbl) == 'table' then
                TriggerEvent('qb-clothing:client:loadPlayerClothing', skinTbl, ped)
            end
        end
        ShopSession.Teardown(false)
        return
    end

    teardownScene()
    loadModel(model)
    SetPlayerModel(PlayerId(), model)
    SetPedDefaultComponentVariation(ped)
    if data.skin then
        local ok, skinTbl = pcall(json.decode, data.skin)
        if ok and type(skinTbl) == 'table' then
            TriggerEvent('qb-clothing:client:loadPlayerClothing', skinTbl, ped)
            TriggerServerEvent('qb-clothing:saveSkin', model, data.skin)
        end
    end
end)

RegisterNetEvent('fivempro_charcreator:client:refreshList', function()
    if not inCreator then return end
    openWizardUi()
end)

RegisterNetEvent('fivempro_charcreator:client:finishCreate', function(data)
    teardownScene()
    local model = data.model or CharAppearance.modelHash(0)
    if type(model) == 'string' then model = joaat(model) end
    loadModel(model)
    SetPlayerModel(PlayerId(), model)
    SetPedDefaultComponentVariation(PlayerPedId())
    local ped = PlayerPedId()
    if data.skin then
        local ok, skinTbl = pcall(json.decode, data.skin)
        if ok and type(skinTbl) == 'table' then
            TriggerEvent('qb-clothing:client:loadPlayerClothing', skinTbl, ped)
            TriggerServerEvent('qb-clothing:saveSkin', model, data.skin)
        end
    end
    if data.spawn then
        local s = data.spawn
        SetEntityCoords(ped, s.x, s.y, s.z, false, false, false, false)
        SetEntityHeading(ped, s.w or 0.0)
    end
    Wait(500)
    TriggerEvent('QBCore:Client:OnPlayerLoaded')
end)

RegisterNUICallback('close', function(_, cb)
    cb('ok')
end)

RegisterNUICallback('selectChar', function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    teardownScene()
    TriggerServerEvent('fivempro_charcreator:server:selectCharacter', data.citizenid)
    cb('ok')
end)

RegisterNUICallback('deleteChar', function(data, cb)
    TriggerServerEvent('fivempro_charcreator:server:deleteCharacter', data.citizenid)
    cb('ok')
end)

RegisterNUICallback('createChar', function(data, cb)
    local skin = CharAppearance.exportForSave()
    data.model = CharAppearance.modelHash(data.personal and data.personal.gender or 0)
    data.skin = json.encode(skin)
    TriggerServerEvent('fivempro_charcreator:server:createCharacter', data)
    cb('ok')
end)

RegisterNUICallback('saveAppearance', function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    local skin = CharAppearance.exportForSave()
    data.model = CharAppearance.modelHash(data.personal and data.personal.gender or 0)
    data.skin = json.encode(skin)
    TriggerServerEvent('fivempro_charcreator:server:saveAppearance', data)
    if not (ShopSession and ShopSession.IsActive()) then
        teardownScene()
    end
    cb('ok')
end)

RegisterNUICallback('setGender', function(data, cb)
    local g = data.gender
    if inPlaceMode then
        local model = CharAppearance.modelHash(g)
        loadModel(model)
        SetPlayerModel(PlayerId(), model)
        SetPedDefaultComponentVariation(PlayerPedId())
        previewPed = PlayerPedId()
        FreezeEntityPosition(previewPed, true)
        CharAppearance.setPreviewPed(previewPed)
        CharCamera.setTargetPed(previewPed)
        CharAppearance.init(g)
        CharAppearance.applyToPed(previewPed, CharAppearance.getSkin())
    else
        createInteriorPed(g)
        CharCamera.setTargetPed(previewPed)
    end
    cb('ok')
end)

RegisterNUICallback('applyPatch', function(data, cb)
    CharAppearance.applyPatch(data.patch or {})
    cb('ok')
end)

RegisterNUICallback('randomize', function(data, cb)
    local skin = CharAppearance.randomize(data.gender)
    cb({ skin = skin })
end)

RegisterNUICallback('setClothing', function(data, cb)
    CharAppearance.setComponent(data.key, data.item, data.texture)
    cb('ok')
end)

RegisterNUICallback('getClothingLimits', function(_, cb)
    local items = Config.CreatorClothingItems or Config.ClothingShopItems or {}
    cb(CharAppearance.getClothingLimits(previewPed, items))
end)

RegisterNUICallback('setCamera', function(data, cb)
    CharCamera.forStep(data.step)
    cb('ok')
end)

RegisterNUICallback('rotateCamera', function(data, cb)
    CharCamera.addOrbit(tonumber(data.delta) or 0)
    cb('ok')
end)

RegisterNUICallback('loadPreset', function(data, cb)
    if data.skin then
        CharAppearance.loadFromJson(data.skin)
    end
    cb('ok')
end)

RegisterNUICallback('savePreset', function(data, cb)
    TriggerServerEvent('fivempro_charcreator:server:savePreset', data.name, CharAppearance.exportForSave())
    cb('ok')
end)

RegisterNUICallback('getPresets', function(_, cb)
    QBCore.Functions.TriggerCallback('fivempro_charcreator:server:getPresets', function(rows)
        cb(rows or {})
    end)
end)

RegisterNUICallback('previewCharacter', function(data, cb)
    if not data.model or not data.skin then return cb('ok') end
    local model = type(data.model) == 'string' and joaat(data.model) or tonumber(data.model)
    if inPlaceMode then
        loadModel(model)
        SetPlayerModel(PlayerId(), model)
        previewPed = PlayerPedId()
        CharAppearance.setPreviewPed(previewPed)
        CharAppearance.loadFromJson(data.skin)
    else
        if previewPed ~= 0 and DoesEntityExist(previewPed) then DeleteEntity(previewPed) end
        loadModel(model)
        local c = Config.PedCoords
        previewPed = CreatePed(2, model, c.x, c.y, c.z, c.w, false, true)
        SetEntityInvincible(previewPed, true)
        FreezeEntityPosition(previewPed, true)
        CharAppearance.setPreviewPed(previewPed)
        CharCamera.setTargetPed(previewPed)
        CharAppearance.loadFromJson(data.skin)
    end
    cb('ok')
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    teardownScene()
end)

exports('IsInCreator', function()
    if ShopSession and ShopSession.IsActive() then return true end
    return inCreator
end)

exports('OpenWizard', function(editMode)
    TriggerEvent('fivempro_charcreator:client:openWizard', editMode == true)
end)
