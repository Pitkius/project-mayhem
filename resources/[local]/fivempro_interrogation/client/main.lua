local QBCore = exports['qb-core']:GetCoreObject()

activeSession = nil

local function notify(msg, typ)
    QBCore.Functions.Notify(msg, typ or 'primary')
end

function InterrogationIsLeadAt(kind, id)
    if not activeSession or activeSession.role ~= 'lead' then return false end
    return activeSession.locationKind == kind and tostring(activeSession.locationId) == tostring(id)
end

local function getNearbyPlayers(maxDist)
    local out = {}
    local myCoords = GetEntityCoords(PlayerPedId())
    for _, pid in ipairs(GetActivePlayers()) do
        if pid ~= PlayerId() then
            local ped = GetPlayerPed(pid)
            if ped and ped ~= 0 then
                local d = #(GetEntityCoords(ped) - myCoords)
                if d <= (maxDist or 4.0) then
                    out[#out + 1] = { serverId = GetPlayerServerId(pid), dist = d }
                end
            end
        end
    end
    table.sort(out, function(a, b) return a.dist < b.dist end)
    return out
end

local function resolveSeat(state)
    if state.locationKind == 'station' then
        local st = GetPoliceStation and GetPoliceStation(state.stationId or state.locationId)
        return st and st.suspectSeat, st and st.spotlight
    end
    if state.locationKind == 'kit' and state.kit then
        return GetKitSeatWorld(state.kit), GetKitSpotlight(state.kit)
    end
end

RegisterNetEvent('fivempro_interrogation:client:startPickSuspect', function(data)
    local nearby = getNearbyPlayers(4.5)
    if #nearby == 0 then return notify('Šalia nėra žaidėjų.', 'error') end
    local menu = { { header = 'Pasirink įtariamąjį', isMenuHeader = true } }
    for _, p in ipairs(nearby) do
        menu[#menu + 1] = {
            header = ('Žaidėjas #%s (%.1f m)'):format(p.serverId, p.dist),
            params = {
                isAction = true,
                event = function()
                    TriggerServerEvent(
                        'fivempro_interrogation:server:requestStart',
                        data.locationKind,
                        data.locationId,
                        p.serverId
                    )
                    exports['qb-menu']:closeMenu()
                end,
            },
        }
    end
    menu[#menu + 1] = {
        header = 'Atšaukti',
        params = { isAction = true, event = function() exports['qb-menu']:closeMenu() end },
    }
    exports['qb-menu']:openMenu(menu)
end)

RegisterNetEvent('fivempro_interrogation:client:consentPrompt', function(data)
    exports['qb-menu']:openMenu({
        { header = 'RP sutikimas', isMenuHeader = true },
        { header = data and data.roomLabel or 'Scena', txt = (data and data.leadName) or '', isMenuHeader = true },
        { header = 'Sutinku (be žalos RP)', params = { event = 'fivempro_interrogation:client:consentReply', args = { accept = true } } },
        { header = 'Atsisakau', params = { event = 'fivempro_interrogation:client:consentReply', args = { accept = false } } },
    })
end)

RegisterNetEvent('fivempro_interrogation:client:consentReply', function(data)
    TriggerServerEvent('fivempro_interrogation:server:consent', data and data.accept == true)
end)

RegisterNetEvent('fivempro_interrogation:client:sessionStarted', function(data)
    activeSession = data
    if data.role == 'lead' then
        if data.mode == 'police' then
            notify('Pasodink įtariamąjį arba pradėk intensyvią apklausą (mygtukai).', 'success')
            TriggerServerEvent('fivempro_interrogation:server:action', 'seat')
            Wait(400)
            SendNUIMessage({ action = 'policeControls', show = true })
            SetNuiFocus(true, true)
        else
            notify('Gaujų RP – naudok mygtukus (dantys / benzinas / elektra).', 'success')
            TriggerServerEvent('fivempro_interrogation:server:action', 'seat')
            Wait(300)
            SendNUIMessage({ action = 'gangControls', show = true })
            SetNuiFocus(true, true)
        end
    else
        notify('RP scena prasidėjo.', 'primary')
    end
end)

RegisterNetEvent('fivempro_interrogation:client:sessionEnded', function()
    activeSession = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
    SendNUIMessage({ action = 'policeControls', show = false })
    SendNUIMessage({ action = 'gangControls', show = false })
    InterrogationScene.cleanup()
end)

RegisterNetEvent('fivempro_interrogation:client:syncState', function(state)
    if not state or not activeSession then return end
    local ped = PlayerPedId()
    local isSuspect = activeSession.role == 'suspect'
    local seat, spotlight = resolveSeat(state)

    if state.seated and isSuspect and seat then
        local animKey = state.suspectAnim or (state.intense and 'suspectInterrogate' or 'suspectSitCalm')
        InterrogationScene.seatSuspect(ped, seat, animKey)
    elseif state.seated == false and isSuspect then
        InterrogationScene.unseatSuspect(ped)
    elseif isSuspect and state.seated and state.suspectAnim then
        InterrogationScene.playAnim(ped, state.suspectAnim)
    end

    if state.spotlight ~= nil and spotlight and activeSession.mode == 'police' then
        InterrogationScene.setSpotlight(state.spotlight, spotlight)
    end

    if state.pressure and isSuspect and activeSession.mode == 'criminal' then
        InterrogationScene.setPressureLevel(state.pressure)
        SendNUIMessage({
            action = 'pressure',
            level = state.pressure,
            modeLabel = 'RP spaudimas',
        })
    end

    if state.animLead and activeSession.role == 'lead' then
        InterrogationScene.playAnim(ped, state.animLead)
    end
    if state.animSuspect and isSuspect then
        InterrogationScene.playAnim(ped, state.animSuspect)
    end
    if state.noise and isSuspect then
        InterrogationScene.playNoiseBurst()
    end
end)

RegisterNetEvent('fivempro_interrogation:client:showPoliceControls', function(on)
    SendNUIMessage({ action = 'policeControls', show = on == true })
    SetNuiFocus(on == true, on == true)
end)

RegisterNetEvent('fivempro_interrogation:client:toggleDoor', function(groupId)
    if type(groupId) == 'string' then
        TriggerServerEvent('fivempro_ltpd:server:togglePdDoorGroup', groupId)
    end
end)

RegisterNUICallback('interrUi', function(data, cb)
    local act = data and data.action
    if act == 'close' then
        SetNuiFocus(false, false)
    elseif act == 'slap' or act == 'spotlight' or act == 'start_intense' or act == 'seat' then
        TriggerServerEvent('fivempro_interrogation:server:action', act)
    elseif act == 'tooth' or act == 'gas' or act == 'electric' then
        TriggerServerEvent('fivempro_interrogation:server:action', act)
    elseif act == 'finish_police' then
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'policeControls', show = false })
        local input = exports['qb-input']:ShowInput({
            header = 'Apklausos rezultatas',
            submitText = 'Išsaugoti MDT',
            inputs = {
                { text = 'Santrauka', name = 'summary', type = 'text', isRequired = false },
            },
        })
        TriggerServerEvent('fivempro_interrogation:server:endSession', {
            result = 'cooperative',
            summary = input and input.summary or '',
        })
    elseif act == 'finish_gang' then
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'gangControls', show = false })
        TriggerServerEvent('fivempro_interrogation:server:endSession', { result = 'complied' })
    elseif act == 'cancel' then
        SetNuiFocus(false, false)
        TriggerServerEvent('fivempro_interrogation:server:cancelSession')
    end
    cb('ok')
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    activeSession = nil
    SetNuiFocus(false, false)
    InterrogationScene.cleanup()
end)
