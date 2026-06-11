local QBCore = exports['qb-core']:GetCoreObject()

PhoneCamera = PhoneCamera or {}

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

local function captureScreenshot(cb)
    if GetResourceState('screenshot-basic') == 'started' then
        exports['screenshot-basic']:requestScreenshot(function(data)
            cb(data)
        end)
        return
    end
    cb(nil)
end

function PhoneCamera.capture()
    if not camActive then return end
    if camFlash then
        sendUi('cameraFlash', {})
        Wait(80)
    end
    captureScreenshot(function(data)
        if not data or data == '' then
            QBCore.Functions.Notify('Nuotraukai reikia screenshot-basic resurso.', 'error', 6000)
            return
        end
        QBCore.Functions.TriggerCallback('fivempro_phone:server:savePhoto', function(res)
            if res and res.ok then
                QBCore.Functions.Notify('Nuotrauka išsaugota galerijoje.', 'success')
                sendUi('photoSaved', { id = res.id, count = res.count })
                TriggerEvent('fivempro_phone:client:refreshData')
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
    PhoneCamera.capture()
    cb({ ok = true })
end)

RegisterNUICallback('deletePhoto', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_phone:server:deletePhoto', function(res)
        cb(res or { ok = false })
    end, data or {})
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    PhoneCamera.stop()
end)
