local QBCore = exports['qb-core']:GetCoreObject()

local previewPed = 0
local inCreator = false

local function loadModel(hash)
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 8000 do
        Wait(10)
        t = t + 10
    end
    return HasModelLoaded(hash)
end

local function setupScene()
    DoScreenFadeOut(300)
    Wait(400)
    local interior = GetInteriorAtCoords(Config.Interior.x, Config.Interior.y, Config.Interior.z - 18.9)
    LoadInterior(interior)
    while not IsInteriorReady(interior) do Wait(50) end

    local hid = Config.HiddenCoords
    SetEntityCoords(PlayerPedId(), hid.x, hid.y, hid.z, false, false, false, false)
    SetEntityVisible(PlayerPedId(), false, false)
    FreezeEntityPosition(PlayerPedId(), true)

    if previewPed ~= 0 and DoesEntityExist(previewPed) then
        DeleteEntity(previewPed)
    end

    local model = CharAppearance.modelHash(0)
    loadModel(model)
    local c = Config.PedCoords
    previewPed = CreatePed(2, model, c.x, c.y, c.z - 0.98, c.w, false, true)
    SetEntityInvincible(previewPed, true)
    FreezeEntityPosition(previewPed, true)
    SetBlockingOfNonTemporaryEvents(previewPed, true)
    PlaceObjectOnGroundProperly(previewPed)

    CharAppearance.setPreviewPed(previewPed)
    CharAppearance.init(0)
    CharAppearance.applyToPed(previewPed, CharAppearance.getSkin())

    CharCamera.enable()
    DoScreenFadeIn(600)
end

local function teardownScene()
    CharCamera.disable()
    SetEntityVisible(PlayerPedId(), true, false)
    FreezeEntityPosition(PlayerPedId(), false)
    if previewPed ~= 0 and DoesEntityExist(previewPed) then
        DeleteEntity(previewPed)
        previewPed = 0
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

local function openWizardUi(editMode)
    QBCore.Functions.TriggerCallback('fivempro_charcreator:server:getSession', function(data)
        if not data or not data.ok then return end
        if (editMode == true or pendingEditMode) and LocalPlayer.state.isLoggedIn then
            data.editMode = true
        end
        pendingEditMode = false
        inCreator = true
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(true)
        SendNUIMessage({
            action = 'openWizard',
            data = data,
        })
    end)
end

RegisterNetEvent('fivempro_charcreator:client:openWizard', function(editMode)
    if inCreator or (ShopSession and ShopSession.IsActive()) then return end
    pendingEditMode = editMode == true
    closeLoadscreen()
    setupScene()
    openWizardUi(editMode)
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
    local model = CharAppearance.modelHash(g)
    if previewPed ~= 0 and DoesEntityExist(previewPed) then
        DeleteEntity(previewPed)
    end
    loadModel(model)
    local c = Config.PedCoords
    previewPed = CreatePed(2, model, c.x, c.y, c.z - 0.98, c.w, false, true)
    SetEntityInvincible(previewPed, true)
    FreezeEntityPosition(previewPed, true)
    CharAppearance.setPreviewPed(previewPed)
    CharAppearance.init(g)
    CharAppearance.applyToPed(previewPed, CharAppearance.getSkin())
    cb('ok')
end)

RegisterNUICallback('applyPatch', function(data, cb)
    CharAppearance.applyPatch(data.patch or {})
    cb('ok')
end)

RegisterNUICallback('applyOutfit', function(data, cb)
    CharAppearance.applyOutfit(data.outfit, data.gender)
    cb('ok')
end)

RegisterNUICallback('randomize', function(data, cb)
    local skin = CharAppearance.randomize(data.gender)
    cb({ skin = skin })
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
    if previewPed ~= 0 and DoesEntityExist(previewPed) then DeleteEntity(previewPed) end
    loadModel(model)
    local c = Config.PedCoords
    previewPed = CreatePed(2, model, c.x, c.y, c.z - 0.98, c.w, false, true)
    SetEntityInvincible(previewPed, true)
    FreezeEntityPosition(previewPed, true)
    CharAppearance.setPreviewPed(previewPed)
    CharAppearance.loadFromJson(data.skin)
    cb('ok')
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    teardownScene()
end)

exports('IsInCreator', function()
    return inCreator
end)

exports('OpenWizard', function(editMode)
    TriggerEvent('fivempro_charcreator:client:openWizard', editMode == true)
end)
