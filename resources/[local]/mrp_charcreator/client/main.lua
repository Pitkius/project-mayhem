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

local function revealAndUnfreezePlayerPed(ped)
    ped = ped or PlayerPedId()
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    SetEntityVisible(ped, true, false)
    ResetEntityAlpha(ped)
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    SetPlayerInvincible(PlayerId(), false)
end

local function placePlayerAtSpawn(spawn)
    if not spawn then return PlayerPedId() end
    local x, y, z, h = spawn.x + 0.0, spawn.y + 0.0, spawn.z + 0.0, spawn.w or 0.0
    RequestCollisionAtCoord(x, y, z)
    local deadline = GetGameTimer() + 2500
    while not HasCollisionLoadedAroundEntity(PlayerPedId()) and GetGameTimer() < deadline do
        RequestCollisionAtCoord(x, y, z)
        Wait(0)
    end
    NetworkResurrectLocalPlayer(x, y, z, h, true, false)
    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
    SetEntityHeading(ped, h)
    revealAndUnfreezePlayerPed(ped)
    return ped
end

local function applyPlayerModelAndSkin(model, skinJson)
    if type(model) == 'string' then model = joaat(model) end
    loadModel(model)
    SetPlayerModel(PlayerId(), model)
    local ped = PlayerPedId()
    SetPedDefaultComponentVariation(ped)
    if skinJson then
        local ok, skinTbl = pcall(json.decode, skinJson)
        if ok and type(skinTbl) == 'table' then
            CharAppearance.applyToPed(ped, skinTbl)
            TriggerServerEvent('qb-clothing:saveSkin', model, skinJson)
        end
    end
    revealAndUnfreezePlayerPed(ped)
    return ped
end

local function teardownScene()
    CharCamera.disable()
    if inPlaceMode then
        FreezeEntityPosition(PlayerPedId(), false)
        inPlaceMode = false
    else
        if previewPed ~= 0 and DoesEntityExist(previewPed) then
            DeleteEntity(previewPed)
            previewPed = 0
        end
        CharAppearance.setPreviewPed(0)
        revealAndUnfreezePlayerPed(PlayerPedId())
    end
    inCreator = false
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function closeLoadscreen()
    if GetResourceState('mrp_loadscreen') == 'started' then
        pcall(function() exports['mrp_loadscreen']:CloseLoadscreen() end)
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
        QBCore.Functions.TriggerCallback('mrp_charcreator:server:getSession', show)
    end
end

RegisterNetEvent('mrp_charcreator:client:openWizard', function(editMode)
    if inCreator or (ShopSession and ShopSession.IsActive()) then return end
    pendingEditMode = editMode == true

    QBCore.Functions.TriggerCallback('mrp_charcreator:server:getSession', function(data)
        if not data or not data.ok then
            DoScreenFadeIn(0)
            return
        end
        local isEdit = (editMode == true or pendingEditMode) and LocalPlayer.state.isLoggedIn
        if isEdit then
            setupInPlaceEdit(data)
        else
            setupScene()
        end
        --- Loadscreen uždarom po scene setup, kad restore loop nenužudytų creator cam.
        closeLoadscreen()
        openWizardUi(editMode, data)
    end)
end)

RegisterNetEvent('mrp_charcreator:client:applyAppearance', function(data)
    if ShopSession and ShopSession.IsActive() then
        local ped = PlayerPedId()
        if data.skin then
            local ok, skinTbl = pcall(json.decode, data.skin)
            if ok and type(skinTbl) == 'table' then
                CharAppearance.applyToPed(ped, skinTbl)
            end
        end
        ShopSession.Teardown(false)
        return
    end

    teardownScene()
    applyPlayerModelAndSkin(data.model or CharAppearance.modelHash(0), data.skin)
    DoScreenFadeIn(500)
end)

RegisterNetEvent('mrp_charcreator:client:refreshList', function()
    if not inCreator then return end
    openWizardUi()
end)

RegisterNetEvent('mrp_charcreator:client:finishCreate', function(data)
    --- Tik UI/scene teardown — tikrą spawn daro mrp_spawnfix (be antro fade race).
    teardownScene()
    Wait(100)
    DestroyAllCams(true)
    RenderScriptCams(false, false, 0, true, true)
    ClearFocus()
    ClearTimecycleModifier()
    if data and data.model then
        local model = data.model
        if type(model) == 'string' then model = joaat(model) end
        loadModel(model)
        SetPlayerModel(PlayerId(), model)
        SetPedDefaultComponentVariation(PlayerPedId())
        if data.skin then
            local ok, skinTbl = pcall(json.decode, data.skin)
            if ok and type(skinTbl) == 'table' then
                CharAppearance.applyToPed(PlayerPedId(), skinTbl)
            end
        end
    end
    revealAndUnfreezePlayerPed(PlayerPedId())
end)

RegisterNUICallback('close', function(_, cb)
    cb('ok')
end)

RegisterNUICallback('selectChar', function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    teardownScene()
    TriggerServerEvent('mrp_charcreator:server:selectCharacter', data.citizenid)
    cb('ok')
end)

RegisterNUICallback('deleteChar', function(data, cb)
    TriggerServerEvent('mrp_charcreator:server:deleteCharacter', data.citizenid)
    cb('ok')
end)

RegisterNUICallback('createChar', function(data, cb)
    local skin = CharAppearance.exportForSave()
    data.model = CharAppearance.modelHash(data.personal and data.personal.gender or 0)
    data.skin = json.encode(skin)
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    TriggerServerEvent('mrp_charcreator:server:createCharacter', data)
    cb('ok')
end)

RegisterNUICallback('saveAppearance', function(data, cb)
    if ShopSession and ShopSession.IsActive() then
        local pd = QBCore.Functions.GetPlayerData()
        local gender = pd and pd.charinfo and pd.charinfo.gender or 0
        local model = CharAppearance.modelHash(gender)
        TriggerServerEvent('qb-clothing:saveSkin', model, json.encode(CharAppearance.exportForSave()))
        ShopSession.Teardown(false)
        cb('ok')
        return
    end

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    local skin = CharAppearance.exportForSave()
    data.model = CharAppearance.modelHash(data.personal and data.personal.gender or 0)
    data.skin = json.encode(skin)
    TriggerServerEvent('mrp_charcreator:server:saveAppearance', data)
    teardownScene()
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
    cb(CharAppearance.getClothingLimits(nil, items))
end)

RegisterNUICallback('getTextureLimit', function(data, cb)
    cb({ maxTex = CharAppearance.getTextureLimit(nil, data.key, data.item) })
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
        local opts
        if ShopSession and ShopSession.IsActive and ShopSession.IsActive() then
            local pd = QBCore.Functions.GetPlayerData()
            opts = {
                gender = pd and pd.charinfo and pd.charinfo.gender or 0,
                tattooShop = ShopSession.kind == 'tattoo',
            }
        end
        CharAppearance.loadFromJson(data.skin, opts)
    end
    cb('ok')
end)

RegisterNUICallback('savePreset', function(data, cb)
    TriggerServerEvent('mrp_charcreator:server:savePreset', data.name, CharAppearance.exportForSave())
    cb('ok')
end)

RegisterNUICallback('getPresets', function(_, cb)
    QBCore.Functions.TriggerCallback('mrp_charcreator:server:getPresets', function(rows)
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
    if ShopSession and ShopSession.IsActive() then
        ShopSession.Teardown(true)
    end
    teardownScene()
end)

exports('IsInCreator', function()
    if ShopSession and ShopSession.IsActive() then return true end
    return inCreator
end)

exports('OpenWizard', function(editMode)
    TriggerEvent('mrp_charcreator:client:openWizard', editMode == true)
end)
