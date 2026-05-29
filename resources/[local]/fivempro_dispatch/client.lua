local QBCore = exports['qb-core']:GetCoreObject()

local currentService = nil
local serviceState = { calls = {}, crews = {}, units = {} }
local blips = {}
local panicBlips = {}

local function myService()
    local p = QBCore.Functions.GetPlayerData()
    if not p or not p.job or not p.job.onduty then return nil end
    local jn = p.job.name
    for service, cfg in pairs(Config.Services or {}) do
        for _, j in ipairs(cfg.jobs or {}) do
            if j == jn then
                return service
            end
        end
    end
    return nil
end

local function clearUnitBlips()
    for _, b in pairs(blips) do
        if b and DoesBlipExist(b) then RemoveBlip(b) end
    end
    blips = {}
end

local function syncUnitBlips()
    if not currentService then
        clearUnitBlips()
        return
    end
    local myId = GetPlayerServerId(PlayerId())
    local seen = {}
    for _, u in ipairs(serviceState.units or {}) do
        if u.source ~= myId then
            seen[u.source] = true
            local b = blips[u.source]
            if not b or not DoesBlipExist(b) then
                b = AddBlipForCoord(u.x + 0.0, u.y + 0.0, u.z + 0.0)
                blips[u.source] = b
                SetBlipSprite(b, 1)
                SetBlipScale(b, 0.85)
                SetBlipColour(b, (Config.Services[currentService] and Config.Services[currentService].color) or 38)
                SetBlipAsShortRange(b, false)
            else
                SetBlipCoords(b, u.x + 0.0, u.y + 0.0, u.z + 0.0)
            end
            ShowHeadingIndicatorOnBlip(b, true)
            SetBlipRotation(b, math.floor((u.heading or 0.0) + 0.5))
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(('%s %s'):format(u.callsign ~= '' and ('[' .. u.callsign .. ']') or '', u.name or 'Pareigūnas'))
            EndTextCommandSetBlipName(b)
        end
    end
    for src, b in pairs(blips) do
        if not seen[src] then
            if b and DoesBlipExist(b) then RemoveBlip(b) end
            blips[src] = nil
        end
    end
end

RegisterNetEvent('fivempro_dispatch:client:update', function(payload)
    if not payload or payload.service ~= currentService then return end
    local oldIds = {}
    for _, c in ipairs(serviceState.calls or {}) do
        oldIds[c.id] = true
    end
    serviceState = payload
    syncUnitBlips()
    for _, c in ipairs(payload.calls or {}) do
        if not oldIds[c.id] then
            QBCore.Functions.Notify(
                ('[%s] %s — %s'):format(c.id, c.callTypeLabel or c.callType or 'Iškvietimas', c.text or ''),
                'error',
                10000
            )
            PlaySoundFrontend(-1, 'CONFIRM_BEEP', 'HUD_MINI_GAME_SOUNDSET', true)
            local b = AddBlipForCoord((c.x or 0.0) + 0.0, (c.y or 0.0) + 0.0, (c.z or 0.0) + 0.0)
            SetBlipSprite(b, 161)
            SetBlipColour(b, 1)
            SetBlipScale(b, 1.0)
            SetBlipAsShortRange(b, false)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(c.callTypeLabel or 'Dispatch')
            EndTextCommandSetBlipName(b)
            SetTimeout(90000, function()
                if DoesBlipExist(b) then RemoveBlip(b) end
            end)
        end
    end
end)

RegisterNetEvent('fivempro_dispatch:client:panic', function(data)
    if currentService ~= 'police' then return end
    QBCore.Functions.Notify(('PANIC: %s %s'):format(data.callsign or '', data.officerName or 'Pareigūnas'), 'error', 10000)
    PlaySoundFrontend(-1, 'TIMER_STOP', 'HUD_MINI_GAME_SOUNDSET', true)
    local b = AddBlipForCoord((data.x or 0.0) + 0.0, (data.y or 0.0) + 0.0, (data.z or 0.0) + 0.0)
    SetBlipSprite(b, 161)
    SetBlipColour(b, 1)
    SetBlipScale(b, 1.25)
    SetBlipFlashes(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('PANIC ALERT')
    EndTextCommandSetBlipName(b)
    if data and data.callId then
        panicBlips[tostring(data.callId)] = b
    end
    SetTimeout(120000, function()
        if DoesBlipExist(b) then RemoveBlip(b) end
        if data and data.callId then
            panicBlips[tostring(data.callId)] = nil
        end
    end)
end)

RegisterNetEvent('fivempro_dispatch:client:panicClear', function(data)
    local callId = tostring(data and data.callId or '')
    if callId == '' then return end
    local b = panicBlips[callId]
    if b and DoesBlipExist(b) then
        RemoveBlip(b)
    end
    panicBlips[callId] = nil
    QBCore.Functions.Notify('PANIC išjungtas.', 'primary')
end)

RegisterCommand('panic', function()
    if myService() ~= 'police' then
        return QBCore.Functions.Notify('Tik policijai tarnyboje.', 'error')
    end
    TriggerServerEvent('fivempro_dispatch:server:panic')
end, false)

RegisterCommand('servicemdt', function()
    local service = myService()
    if not service then
        return QBCore.Functions.Notify('Tik tarnyboms duty metu.', 'error')
    end
    QBCore.Functions.TriggerCallback('fivempro_dispatch:server:getSnapshot', function(res)
        if not res or not res.ok then return end
        serviceState = res
        local menu = {
            { header = ('%s MDT'):format((Config.Services[service] and Config.Services[service].label) or service), isMenuHeader = true },
            { header = ('Aktyvūs iškvietimai: %s'):format(#(res.calls or {})), isMenuHeader = true },
        }
        for _, c in ipairs(res.calls or {}) do
            local accepted = 0
            for _ in pairs(c.acceptedBy or {}) do accepted = accepted + 1 end
            menu[#menu + 1] = {
                header = ('[%s] %s (%s)'):format(c.id, c.callTypeLabel or c.callType or 'Kitas', c.statusLabel or c.status),
                txt = ('Lokacija: %.1f %.1f | Ekipažai: %s'):format(c.x or 0.0, c.y or 0.0, accepted),
                params = {
                    isAction = true,
                    event = function()
                        local callMenu = {
                            { header = ('Iškvietimas %s'):format(c.id), isMenuHeader = true },
                            {
                                header = 'Priimti',
                                params = {
                                    isAction = true,
                                    event = function()
                                        TriggerServerEvent('fivempro_dispatch:server:updateCallStatus', c.id, 'accept')
                                        QBCore.Functions.Notify('Iškvietimas priimtas.', 'success')
                                    end,
                                },
                            },
                            {
                                header = 'Vykstu',
                                params = {
                                    isAction = true,
                                    event = function()
                                        TriggerServerEvent('fivempro_dispatch:server:updateCallStatus', c.id, 'enroute')
                                        SetNewWaypoint((c.x or 0.0) + 0.0, (c.y or 0.0) + 0.0)
                                        QBCore.Functions.Notify('Pažymėta: vykstu.', 'success')
                                    end,
                                },
                            },
                            {
                                header = 'Baigta',
                                params = {
                                    isAction = true,
                                    event = function()
                                        TriggerServerEvent('fivempro_dispatch:server:updateCallStatus', c.id, 'done')
                                        QBCore.Functions.Notify('Iškvietimas užbaigtas.', 'success')
                                    end,
                                },
                            },
                            {
                                header = 'Atmesti',
                                params = {
                                    isAction = true,
                                    event = function()
                                        TriggerServerEvent('fivempro_dispatch:server:updateCallStatus', c.id, 'reject')
                                        QBCore.Functions.Notify('Iškvietimas atmestas.', 'error')
                                    end,
                                },
                            },
                        }
                        TriggerEvent('qb-menu:client:openMenu', callMenu, false, true)
                    end,
                },
            }
        end
        menu[#menu + 1] = {
            header = 'Sukurti ekipažą',
            params = {
                isAction = true,
                event = function()
                    TriggerServerEvent('fivempro_dispatch:server:createCrew', '')
                    QBCore.Functions.Notify('Ekipažas sukurtas.', 'success')
                end,
            },
        }
        menu[#menu + 1] = {
            header = 'Išeiti iš ekipažo',
            params = {
                isAction = true,
                event = function()
                    TriggerServerEvent('fivempro_dispatch:server:leaveCrew')
                    QBCore.Functions.Notify('Išeita iš ekipažo.', 'primary')
                end,
            },
        }
        TriggerEvent('qb-menu:client:openMenu', menu, false, true)
    end, service)
end, false)

RegisterCommand('servicecall', function(_, args)
    local service = myService()
    if not service then
        return QBCore.Functions.Notify('Tik tarnyboms duty metu.', 'error')
    end
    local callType = tostring(args and args[1] or 'custom')
    local text = table.concat(args or {}, ' ', 2)
    TriggerServerEvent('fivempro_dispatch:server:createServiceCall', service, callType, text ~= '' and text or 'Tarnybinis iškvietimas')
    QBCore.Functions.Notify('Iškvietimas sukurtas MDT sistemoje.', 'success')
end, false)

RegisterCommand('callsign', function(_, args)
    local cs = args and args[1]
    if not cs then
        return QBCore.Functions.Notify('Naudok: /callsign LIMA67', 'error')
    end
    TriggerServerEvent('fivempro_dispatch:server:setCallsign', cs)
end, false)

CreateThread(function()
    while true do
        local s = myService()
        if s ~= currentService then
            currentService = s
            serviceState = { calls = {}, crews = {}, units = {} }
            clearUnitBlips()
            if currentService then
                QBCore.Functions.TriggerCallback('fivempro_dispatch:server:getSnapshot', function(res)
                    if res and res.ok and currentService == s then
                        serviceState = res
                        syncUnitBlips()
                    end
                end, currentService)
            end
        end
        Wait(1200)
    end
end)

