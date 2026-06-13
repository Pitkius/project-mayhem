local QBCore = exports['qb-core']:GetCoreObject()

local ANIM_DICT = 'cellphone@'
local ANIM_IN = 'cellphone_text_in'
local ANIM_OUT = 'cellphone_text_out'
local ANIM_LOOP = 'cellphone_text_read_base'

local phoneProp = nil
--- idle | opening | open | closing
local phonePhase = 'idle'

local function requestAnim(dict)
    if not dict or dict == '' then return false end
    RequestAnimDict(dict)
    local t = GetGameTimer()
    while not HasAnimDictLoaded(dict) and GetGameTimer() - t < 4000 do
        Wait(0)
    end
    return HasAnimDictLoaded(dict)
end

--- Turi būti virš `ensurePhoneProp` — Lua lokalių „forward“ nėra; kitaip `clearPhoneProp` tampa global ir nil.
local function clearPhoneProp()
    if phoneProp and DoesEntityExist(phoneProp) then
        DeleteEntity(phoneProp)
    end
    phoneProp = nil
end

local function ensurePhoneProp()
    local ped = PlayerPedId()
    local model = joaat('prop_npc_phone_02')
    RequestModel(model)
    local tries = 0
    while not HasModelLoaded(model) and tries < 80 do
        Wait(0)
        tries = tries + 1
    end
    if not HasModelLoaded(model) then return end
    clearPhoneProp()
    local coords = GetEntityCoords(ped)
    phoneProp = CreateObject(model, coords.x, coords.y, coords.z + 0.2, true, true, false)
    AttachEntityToEntity(phoneProp, ped, GetPedBoneIndex(ped, 57005), 0.12, 0.02, -0.02, 90.0, 120.0, 0.0, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(model)
end

local function sendUi(action, payload)
    SendNUIMessage({
        action = action,
        payload = payload or {},
    })
end

local function pedPlayAnim(ped, dict, clip, durMs, flag)
    durMs = durMs or -1
    flag = flag or 49
    if not ped or ped == 0 then return false end
    if not requestAnim(dict) then return false end
    TaskPlayAnim(ped, dict, clip, 8.0, -8.0, durMs, flag, 0.0, false, false, false)
    return true
end

local function stopPhoneAnims(ped)
    ped = ped or PlayerPedId()
    if requestAnim(ANIM_DICT) then
        StopAnimTask(ped, ANIM_DICT, ANIM_IN, 1.5)
        StopAnimTask(ped, ANIM_DICT, ANIM_LOOP, 1.5)
        StopAnimTask(ped, ANIM_DICT, ANIM_OUT, 1.5)
    end
end

--- Laukti tik kol `phonePhase == 'opening'` (leidžia nutraukti uždarant telefoną).
local function waitWhileOpening(ms)
    local untilT = GetGameTimer() + ms
    while GetGameTimer() < untilT do
        if phonePhase ~= 'opening' then return false end
        Wait(0)
    end
    return phonePhase == 'opening'
end

--- Užbaigti įtraukimo animaciją, tada laikyti ramybės loop iki uždarymo.
local function runPhoneOpenAnim()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return end
    stopPhoneAnims(ped)
    if not pedPlayAnim(ped, ANIM_DICT, ANIM_IN, 1200, 49) then return end
    if not waitWhileOpening(780) then return end
    ensurePhoneProp()
    if not waitWhileOpening(420) then return end
    if phonePhase ~= 'opening' then return end
    if not DoesEntityExist(ped) then return end
    pedPlayAnim(ped, ANIM_DICT, ANIM_LOOP, -1, 49)
end

--- Pasidėti telefoną ir tik tada sutvarkyti prop / taskus.
local function runPhonePutAwayAnim()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return end
    stopPhoneAnims(ped)
    Wait(50)
    if not pedPlayAnim(ped, ANIM_DICT, ANIM_OUT, 1200, 49) then
        ClearPedSecondaryTask(ped)
        ClearPedTasks(ped)
        clearPhoneProp()
        return
    end
    Wait(420)
    clearPhoneProp()
    Wait(850)
    if requestAnim(ANIM_DICT) then
        StopAnimTask(ped, ANIM_DICT, ANIM_OUT, 1.0)
    end
    ClearPedSecondaryTask(ped)
end

local activeVoiceCallId = 0

local function setPhoneVoiceCall(callId)
    if GetResourceState('pma-voice') ~= 'started' then return end
    callId = tonumber(callId) or 0
    if callId == activeVoiceCallId then return end
    activeVoiceCallId = callId
    pcall(function()
        if callId > 0 then
            exports['pma-voice']:addPlayerToCall(callId)
        else
            exports['pma-voice']:removePlayerFromCall()
        end
    end)
end

local function closePhone()
    if phonePhase == 'idle' or phonePhase == 'closing' then return end

    if PhoneCamera and PhoneCamera.stop then PhoneCamera.stop() end
    phonePhase = 'closing'
    SetNuiFocus(false, false)
    sendUi('close')

    CreateThread(function()
        runPhonePutAwayAnim()
        phonePhase = 'idle'
    end)
end

local function fetchPhoneData(cb)
    QBCore.Functions.TriggerCallback('fivempro_phone:server:getInitialData', function(data)
        if cb then cb(data or {}) end
    end)
end

local function showPhone(opts)
    opts = opts or {}
    if IsPauseMenuActive() then return end
    if phonePhase == 'closing' then return end
    if phonePhase == 'opening' then return end

    if phonePhase == 'open' then
        if opts.refreshIfOpen then
            fetchPhoneData(function(data)
                sendUi('hydrate', data)
            end)
        end
        return
    end

    phonePhase = 'opening'
    CreateThread(function()
        runPhoneOpenAnim()
        if phonePhase ~= 'opening' then return end
        phonePhase = 'open'
        SetNuiFocus(true, true)
        sendUi('open')
        fetchPhoneData(function(data)
            sendUi('hydrate', data)
        end)
    end)
end

local function togglePhone()
    if phonePhase == 'closing' then return end
    if phonePhase == 'open' or phonePhase == 'opening' then
        closePhone()
        return
    end
    showPhone({})
end

RegisterCommand(Config.KeybindCommand or 'fivempro_phone_toggle', function()
    local itemName = Config.PhoneItem or 'phone'
    if Config.RequirePhoneItemForKeybind and not QBCore.Functions.HasItem(itemName, 1) then
        QBCore.Functions.Notify('Jums reikia telefono inventoriuje.', 'error')
        return
    end
    togglePhone()
end, false)

RegisterKeyMapping(
    Config.KeybindCommand or 'fivempro_phone_toggle',
    'Atidaryti telefoną',
    'keyboard',
    Config.KeybindDefault or 'F1'
)

--- Uždaryti telefoną atidarius pause meniu (ESC / meniu).
CreateThread(function()
    while true do
        Wait(200)
        if phonePhase == 'open' or phonePhase == 'opening' then
            if IsPauseMenuActive() then
                closePhone()
            end
        end
    end
end)

RegisterNetEvent('fivempro_phone:client:refreshData', function()
    if phonePhase ~= 'open' then return end
    fetchPhoneData(function(data)
        sendUi('hydrate', data)
    end)
end)

RegisterNetEvent('fivempro_phone:client:newMessageNotify', function(fromNumber)
    fromNumber = tostring(fromNumber or 'Nežinomas')
    if phonePhase ~= 'open' then
        QBCore.Functions.Notify(('Nauja žinutė iš %s'):format(fromNumber), 'primary')
    end
    sendUi('newMessageNotify', { fromNumber = fromNumber })
end)

RegisterNetEvent('fivempro_phone:client:incomingCall', function(call)
    if phonePhase ~= 'open' then
        QBCore.Functions.Notify(('Gaunamas skambutis: %s'):format(call and call.fromNumber or 'Nežinomas'), 'primary')
    end
    sendUi('incomingCall', call or {})
end)

RegisterNetEvent('fivempro_phone:client:callState', function(call)
    call = call or {}
    local st = tostring(call.status or '')
    if st == 'connected' and call.id then
        setPhoneVoiceCall(call.id)
        QBCore.Functions.Notify('Skambutis prijungtas — kalbėkite.', 'success', 4000)
    elseif st == 'ringing' and call.id then
        -- laukiam atsakymo
    elseif st == 'rejected' or st == 'ended' or st == 'busy' or st == 'failed' then
        setPhoneVoiceCall(0)
    end
    sendUi('callState', call)
end)

RegisterNetEvent('fivempro_phone:client:closePhone', function()
    closePhone()
end)

RegisterNetEvent('fivempro_phone:client:openPhoneFromItem', function()
    local itemName = Config.PhoneItem or 'phone'
    if not QBCore.Functions.HasItem(itemName, 1) then
        QBCore.Functions.Notify('Neturite telefono.', 'error')
        return
    end
    showPhone({ refreshIfOpen = true })
end)

RegisterNUICallback('close', function(_, cb)
    closePhone()
    cb('ok')
end)

RegisterNUICallback('refresh', function(_, cb)
    fetchPhoneData(function(data)
        cb(data or {})
    end)
end)

RegisterNUICallback('saveContact', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_phone:server:saveContact', function(res)
        cb(res or { ok = false })
    end, data or {})
end)

RegisterNUICallback('updateContact', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_phone:server:updateContact', function(res)
        cb(res or { ok = false })
    end, data or {})
end)

RegisterNUICallback('deleteContact', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_phone:server:deleteContact', function(res)
        cb(res or { ok = false })
    end, data or {})
end)

RegisterNUICallback('sendMessage', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_phone:server:sendMessage', function(res)
        cb(res or { ok = false })
    end, data or {})
end)

RegisterNUICallback('getConversation', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_phone:server:getConversation', function(res)
        cb(res or { ok = false, messages = {} })
    end, data or {})
end)

RegisterNUICallback('createAd', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_phone:server:createAd', function(res)
        cb(res or { ok = false })
    end, data or {})
end)

RegisterNUICallback('deleteAd', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_phone:server:deleteAd', function(res)
        cb(res or { ok = false })
    end, data or {})
end)

RegisterNUICallback('createPost', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_phone:server:createPost', function(res)
        cb(res or { ok = false })
    end, data or {})
end)

RegisterNUICallback('likePost', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_phone:server:likePost', function(res)
        cb(res or { ok = false })
    end, data or {})
end)

RegisterNUICallback('startCall', function(data, cb)
    TriggerServerEvent('fivempro_phone:server:startCall', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('respondCall', function(data, cb)
    TriggerServerEvent('fivempro_phone:server:respondCall', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('endCall', function(data, cb)
    TriggerServerEvent('fivempro_phone:server:endCall', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('emergencyCall', function(data, cb)
    local c = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('fivempro_phone:server:emergencyCall', data and data.service or '', {
        x = c.x,
        y = c.y,
        z = c.z,
    })
    cb({ ok = true })
end)

RegisterNUICallback('createAccount', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_phone:server:createAccount', function(res)
        cb(res or { ok = false })
    end, data or {})
end)

RegisterNUICallback('installApp', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_phone:server:installApp', function(res)
        cb(res or { ok = false })
    end, data or {})
end)

RegisterNUICallback('openCamera', function(_, cb)
    cb({ ok = true })
end)

RegisterNUICallback('closeCamera', function(_, cb)
    if PhoneCamera and PhoneCamera.stop then PhoneCamera.stop() end
    cb({ ok = true })
end)

RegisterNUICallback('getPhoto', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_phone:server:getPhoto', function(res)
        cb(res or { ok = false })
    end, data or {})
end)

RegisterNUICallback('saveAdProfile', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_phone:server:saveAdProfile', function(res)
        cb(res or { ok = false })
    end, data or {})
end)

RegisterNUICallback('getAdProfileAvatar', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_phone:server:getAdProfileAvatar', function(res)
        cb(res or { ok = false })
    end, data or {})
end)

RegisterNUICallback('getWeather', function(_, cb)
    local rain = 0.0
    if GetRainLevel then rain = GetRainLevel() end
    local label = rain > 0.15 and 'Lietinga, ~18°C' or 'Giedra, ~24°C'
    cb({ ok = true, label = label })
end)

RegisterNUICallback('shopHint', function(_, cb)
    QBCore.Functions.Notify('Ieškokite parduotuvių žemėlapyje (24/7, Ammu-Nation ir kt.).', 'primary', 6000)
    cb({ ok = true })
end)

RegisterNUICallback('openCargoNet', function(_, cb)
    cb({ ok = true })
    CreateThread(function()
        if GetResourceState('fivempro_trucking') ~= 'started' then
            QBCore.Functions.Notify('CargoNet šiuo metu nepasiekiama.', 'error')
            return
        end
        closePhone()
        local deadline = GetGameTimer() + 2500
        while phonePhase ~= 'idle' and GetGameTimer() < deadline do
            Wait(50)
        end
        Wait(100)
        local ok, err = pcall(function()
            TriggerEvent('fivempro_trucking:client:openUI', { mode = 'phone' })
        end)
        if not ok then
            print(('[fivempro_phone] CargoNet open error: %s'):format(tostring(err)))
            QBCore.Functions.Notify('Nepavyko atidaryti CargoNet.', 'error')
        end
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    setPhoneVoiceCall(0)
    if PhoneCamera and PhoneCamera.stop then PhoneCamera.stop() end
end)

RegisterNetEvent('fivempro_phone:client:serviceDispatch', function(data)
    if not data or not data.x then return end
    local service = tostring(data.service or '')
    local blip = AddBlipForCoord(data.x + 0.0, data.y + 0.0, data.z + 0.0)
    SetBlipSprite(blip, tonumber(data.sprite) or 161)
    SetBlipScale(blip, tonumber(data.scale) or 1.0)
    if service == 'police' then
        SetBlipColour(blip, 38)
    elseif service == 'ems' then
        SetBlipColour(blip, 1)
    elseif service == 'taxi' then
        SetBlipColour(blip, 5)
    else
        SetBlipColour(blip, 5)
    end
    SetBlipFlashes(blip, true)
    exports['fivempro_fonts']:SetBlipName(blip, data.title or 'Skubus iškvietimas')
    QBCore.Functions.Notify(data.title or 'Skubus iškvietimas', 'primary', 7500)
    local dur = tonumber(data.duration) or 120000
    SetTimeout(dur, function()
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end)
end)

RegisterNetEvent('fivempro_phone:client:hospitalWake', function(data)
    local c = data
    if not c or c.x == nil then
        local h = Config.HospitalWake
        local locs = h and h.locations
        if type(locs) == 'table' and locs[1] then
            c = { x = locs[1].x, y = locs[1].y, z = locs[1].z, w = locs[1].w }
        elseif h and h.coords then
            c = { x = h.coords.x, y = h.coords.y, z = h.coords.z, w = h.coords.w }
        else
            return
        end
    end
    local ped = PlayerPedId()
    NetworkResurrectLocalPlayer(c.x, c.y, c.z + 0.35, c.w, true, false)
    ped = PlayerPedId()
    SetPlayerInvincible(PlayerId(), false)
    ClearPedBloodDamage(ped)
    ClearPedTasksImmediately(ped)
    SetEntityCoordsNoOffset(ped, c.x, c.y, c.z, false, false, false)
    SetEntityHeading(ped, c.w)
    SetEntityHealth(ped, 200)
    SetPedArmour(ped, 0)
    TriggerEvent('fivempro_phone:local:AfterHospitalWake')
end)
