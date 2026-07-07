local QBCore = exports['qb-core']:GetCoreObject()

PhoneCamera = PhoneCamera or {}

local function photosEnabled()
    return Config.Phone and Config.Phone.enablePhotos == true
end

local camActive = false
local camFront = false
local camZoom = 1.0
local camFlash = false
local camThread = nil

local function sendUi(action, payload)
    SendNUIMessage({ action = action, payload = payload or {} })
end

local function setFrontCamera(front)
    camFront = front == true
    pcall(function()
        CellFrontCamActivate(camFront)
    end)
    sendUi('cameraState', { front = camFront, zoom = camZoom, flash = camFlash })
end

local function applyZoom()
    pcall(function()
        Citizen.InvokeNative(0x96C34EEFB3434381, camZoom + 0.0)
    end)
    sendUi('cameraState', { front = camFront, zoom = camZoom, flash = camFlash })
end

function PhoneCamera.stop()
    if not camActive then return end
    camActive = false
    pcall(function() CellCamActivate(false, false) end)
    pcall(function() DestroyMobilePhone() end)
    pcall(function() CellFrontCamActivate(false) end)
    local ped = PlayerPedId()
    if ped and ped ~= 0 then
        FreezeEntityPosition(ped, false)
        SetEntityCollision(ped, true, true)
        SetPlayerControl(PlayerId(), true, 0)
    end
    RenderScriptCams(false, false, 0, true, true)
    sendUi('cameraMode', { active = false })
end

function PhoneCamera.isActive()
    return camActive
end

function PhoneCamera.start(opts)
    if not photosEnabled() then return end
    opts = opts or {}
    PhoneCamera.stop()
    camActive = true
    camFront = opts.front == true
    camZoom = tonumber(opts.zoom) or 1.0
    camFlash = opts.flash == true

    CreateMobilePhone(1)
    CellCamActivate(true, true)
    setFrontCamera(camFront)
    applyZoom()

    sendUi('cameraMode', { active = true, front = camFront, zoom = camZoom, flash = camFlash })

    if camThread then return end
    camThread = CreateThread(function()
        while camActive do
            Wait(0)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 37, true)
            DisableControlAction(0, 44, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)

            if IsDisabledControlJustPressed(0, 241) then
                camZoom = math.min(2.5, camZoom + 0.08)
                applyZoom()
            elseif IsDisabledControlJustPressed(0, 242) then
                camZoom = math.max(0.55, camZoom - 0.08)
                applyZoom()
            end
        end
        camThread = nil
    end)
end

local function normalizeImageData(raw)
    local imageData = tostring(raw or '')
    imageData = imageData:match('^%s*(.-)%s*$') or ''
    if imageData == '' then return '' end

    if imageData:sub(1, 1) == '{' then
        local ok, parsed = pcall(json.decode, imageData)
        if ok and type(parsed) == 'table' and type(parsed.data) == 'string' then
            imageData = parsed.data:match('^%s*(.-)%s*$') or ''
        end
    end

    if imageData ~= '' and not imageData:find('^data:') then
        if imageData:sub(1, 3) == '/9j' then
            imageData = 'data:image/jpeg;base64,' .. imageData
        elseif imageData:sub(1, 8) == 'iVBORw0K' then
            imageData = 'data:image/png;base64,' .. imageData
        else
            imageData = 'data:image/jpeg;base64,' .. imageData
        end
    end

    return imageData
end

local function captureScreenshot(cb)
    local state = GetResourceState('screenshot-basic')
    if state ~= 'started' then
        cb(nil, state)
        return
    end
    local ok, err = pcall(function()
        exports['screenshot-basic']:requestScreenshot({
            encoding = 'jpg',
            quality = 0.58,
        }, function(data)
            cb(normalizeImageData(data))
        end)
    end)
    if not ok then
        cb(nil, tostring(err))
    end
end

function PhoneCamera.capture()
    if not camActive then return end
    if camFlash then
        sendUi('cameraFlash', {})
        Wait(80)
    end
    captureScreenshot(function(data, errState)
        if not data or data == '' then
            if errState and errState ~= 'started' then
                QBCore.Functions.Notify('screenshot-basic neįkeltas. Serverio konsolėje: ensure screenshot-basic', 'error', 7000)
            else
                QBCore.Functions.Notify('Nepavyko padaryti nuotraukos. Bandyk dar kartą.', 'error', 5000)
            end
            return
        end
        QBCore.Functions.TriggerCallback('mrp_phone:server:savePhoto', function(res)
            if res and res.ok then
                QBCore.Functions.Notify('Nuotrauka išsaugota galerijoje.', 'success')
                sendUi('photoSaved', { id = res.id, count = res.count })
            else
                QBCore.Functions.Notify(res and res.message or 'Nepavyko išsaugoti nuotraukos.', 'error')
            end
        end, {
            imageData = data,
            front = camFront,
            zoom = camZoom,
        })
    end)
end

RegisterNUICallback('cameraStartLive', function(data, cb)
    if not photosEnabled() then return cb({ ok = false, message = 'Nuotraukos išjungtos.' }) end
    PhoneCamera.start({
        front = data and data.front == true,
        zoom = data and data.zoom,
        flash = data and data.flash == true,
    })
    cb({ ok = true, front = camFront, zoom = camZoom, flash = camFlash })
end)

RegisterNUICallback('cameraStopLive', function(_, cb)
    PhoneCamera.stop()
    cb({ ok = true })
end)

RegisterNUICallback('cameraFlip', function(_, cb)
    if not camActive then
        PhoneCamera.start({ front = not camFront, zoom = camZoom, flash = camFlash })
    else
        setFrontCamera(not camFront)
    end
    cb({ ok = true, front = camFront })
end)

RegisterNUICallback('cameraSetZoom', function(data, cb)
    camZoom = math.max(0.55, math.min(2.5, tonumber(data and data.zoom) or camZoom))
    if camActive then applyZoom() end
    cb({ ok = true, zoom = camZoom })
end)

RegisterNUICallback('cameraToggleFlash', function(_, cb)
    camFlash = not camFlash
    sendUi('cameraState', { front = camFront, zoom = camZoom, flash = camFlash })
    cb({ ok = true, flash = camFlash })
end)

RegisterNUICallback('cameraCapture', function(_, cb)
    if not photosEnabled() then return cb({ ok = false, message = 'Nuotraukos išjungtos.' }) end
    PhoneCamera.capture()
    cb({ ok = true })
end)

RegisterNUICallback('deletePhoto', function(data, cb)
    QBCore.Functions.TriggerCallback('mrp_phone:server:deletePhoto', function(res)
        cb(res or { ok = false })
    end, data or {})
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    PhoneCamera.stop()
end)
