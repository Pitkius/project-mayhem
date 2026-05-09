local QBCore = exports['qb-core']:GetCoreObject()
local vendorPed = nil

local function getCurrentTurfId()
    local ped = PlayerPedId()
    local p = GetEntityCoords(ped)
    for turfId, turf in pairs(Config.Turfs or {}) do
        local c = turf.center
        local d = #(p - vector3(c.x, c.y, c.z))
        if d <= (turf.radius or 150.0) then
            return turfId, turf
        end
    end
    return nil, nil
end

local function openAdminMenu()
    QBCore.Functions.TriggerCallback('fivempro_gangs:server:getAdminSnapshot', function(res)
        if not res or not res.ok then
            return QBCore.Functions.Notify('Nėra teisių.', 'error')
        end
        local menu = {
            { header = 'Gang Admin Panel', txt = 'Valdyk gaujas ir teritorijas', isMenuHeader = true },
        }
        for _, g in ipairs(res.gangs or {}) do
            menu[#menu + 1] = {
                header = ('#%s %s (%s)'):format(g.id, g.name, g.gang_type),
                txt = ('Rep: %s | Heat: %s | Color: %s'):format(g.reputation or 0, g.heat or 0, g.color_hex or '#FFFFFF'),
                params = {
                    isAction = true,
                    event = function()
                        local input = exports['qb-input']:ShowInput({
                            header = ('Admin: %s'):format(g.name),
                            submitText = 'Saugoti',
                            inputs = {
                                { text = 'Reputation', name = 'reputation', type = 'number', default = tostring(g.reputation or 0) },
                                { text = 'Heat', name = 'heat', type = 'number', default = tostring(g.heat or 0) },
                                { text = 'DELETE (yes/no)', name = 'delete', type = 'text' },
                            },
                        })
                        if not input then return end
                        if tostring(input.delete or ''):lower() == 'yes' then
                            TriggerServerEvent('fivempro_gangs:server:adminDeleteGang', g.id)
                            return
                        end
                        TriggerServerEvent('fivempro_gangs:server:adminSetGangStats', g.id, tonumber(input.reputation) or 0, tonumber(input.heat) or 0)
                    end,
                },
            }
        end
        TriggerEvent('qb-menu:client:openMenu', menu, false, true)
    end)
end

RegisterNetEvent('fivempro_gangs:client:openTablet', function()
    QBCore.Functions.TriggerCallback('fivempro_gangs:server:getTabletState', function(res)
        if not res or not res.ok then return end
        local menu = {
            { header = 'Gang Tablet', txt = 'Gaujos valdymas ir turf sistema', isMenuHeader = true },
        }

        if not res.hasGang then
            menu[#menu + 1] = {
                header = 'Registruoti gaują',
                txt = 'Sukurk naują gaują (pavadinimas, tipas, spalva)',
                params = {
                    isAction = true,
                    event = function()
                        local input = exports['qb-input']:ShowInput({
                            header = 'Gaujos registracija',
                            submitText = 'Registruoti',
                            inputs = {
                                { text = 'Pavadinimas', name = 'name', type = 'text', isRequired = true },
                                { text = 'Tipas (street/biker/cartel/mafia/racing)', name = 'gangType', type = 'text', isRequired = true },
                                { text = 'Spalva HEX (#00FFAA)', name = 'colorHex', type = 'text', default = '#FFFFFF' },
                            },
                        })
                        if not input then return end
                        TriggerServerEvent('fivempro_gangs:server:createGang', input)
                    end,
                },
            }
        else
            menu[#menu + 1] = { header = ('%s [%s]'):format(res.gang.name, Config.Ranks[tonumber(res.gang.rank) or 0] or 'Narys'), isMenuHeader = true }
            menu[#menu + 1] = {
                header = 'Pakviesti narį',
                txt = 'Pakvietimas pagal server ID',
                params = {
                    isAction = true,
                    event = function()
                        local input = exports['qb-input']:ShowInput({
                            header = 'Pakviesti narį',
                            submitText = 'Pakviesti',
                            inputs = {
                                { text = 'Server ID', name = 'targetId', type = 'number', isRequired = true },
                            },
                        })
                        if not input then return end
                        TriggerServerEvent('fivempro_gangs:server:inviteMember', tonumber(input.targetId))
                    end,
                },
            }
            menu[#menu + 1] = {
                header = 'Narių sąrašas / rangai',
                txt = ('Narių: %s'):format(#(res.members or {})),
                params = {
                    isAction = true,
                    event = function()
                        local mm = { { header = 'Gang nariai', isMenuHeader = true } }
                        for _, m in ipairs(res.members or {}) do
                            mm[#mm + 1] = {
                                header = ('%s (%s)'):format(m.name, Config.Ranks[tonumber(m.rank) or 0] or ('Rank ' .. tostring(m.rank))),
                                txt = m.citizenid,
                                params = {
                                    isAction = true,
                                    event = function()
                                        local input = exports['qb-input']:ShowInput({
                                            header = m.name,
                                            submitText = 'Pritaikyti',
                                            inputs = {
                                                { text = 'Naujas rangas (0-4)', name = 'rank', type = 'number' },
                                                { text = 'Kick? (yes/no)', name = 'kick', type = 'text' },
                                            },
                                        })
                                        if not input then return end
                                        if tostring(input.kick or ''):lower() == 'yes' then
                                            TriggerServerEvent('fivempro_gangs:server:kickMember', m.citizenid)
                                            return
                                        end
                                        if input.rank and input.rank ~= '' then
                                            TriggerServerEvent('fivempro_gangs:server:setMemberRank', m.citizenid, tonumber(input.rank) or 0)
                                        end
                                    end,
                                },
                            }
                        end
                        TriggerEvent('qb-menu:client:openMenu', mm, false, true)
                    end,
                },
            }
            menu[#menu + 1] = {
                header = 'Vykdyti turf veiklą',
                txt = 'Task: drug / smuggle / theft / extortion / racing',
                params = {
                    isAction = true,
                    event = function()
                        local turfId, turf = getCurrentTurfId()
                        if not turfId then return QBCore.Functions.Notify('Nesi jokio turf zonoje.', 'error') end
                        local input = exports['qb-input']:ShowInput({
                            header = ('Turf veikla: %s'):format(turf.label or turfId),
                            submitText = 'Vykdyti',
                            inputs = {
                                { text = 'Task tipas', name = 'taskType', type = 'text', default = 'drug', isRequired = true },
                            },
                        })
                        if not input then return end
                        TriggerServerEvent('fivempro_gangs:server:completeTask', turfId, input.taskType)
                    end,
                },
            }
        end

        menu[#menu + 1] = {
            header = 'Turf žemėlapis',
            txt = 'Parodo owner/progresą ir padeda waypoint',
            params = {
                isAction = true,
                event = function()
                    local tm = { { header = 'Turf statusas', isMenuHeader = true } }
                    local idx = {}
                    for _, t in ipairs(res.turfs or {}) do idx[t.turf_id] = t end
                    for turfId, turfCfg in pairs(Config.Turfs or {}) do
                        local d = idx[turfId] or {}
                        tm[#tm + 1] = {
                            header = ('%s (%s)'):format(turfCfg.label or turfId, d.owner_name or 'Niekas'),
                            txt = ('Progress: %s | Heat: %s | Sales: %s'):format(d.progress or 0, d.heat or 0, d.sales_count or 0),
                            params = {
                                isAction = true,
                                event = function()
                                    SetNewWaypoint(turfCfg.center.x + 0.0, turfCfg.center.y + 0.0)
                                end,
                            },
                        }
                    end
                    TriggerEvent('qb-menu:client:openMenu', tm, false, true)
                end,
            },
        }
        TriggerEvent('qb-menu:client:openMenu', menu, false, true)
    end)
end)

RegisterCommand('gangsell', function()
    local turfId = getCurrentTurfId()
    if not turfId then
        return QBCore.Functions.Notify('Nesi turf teritorijoje.', 'error')
    end
    local ped = PlayerPedId()
    local p = GetEntityCoords(ped)
    local handle, foundPed = FindFirstPed()
    local ok = true
    local target = 0
    repeat
        if foundPed and foundPed ~= ped and not IsPedAPlayer(foundPed) and not IsEntityDead(foundPed) then
            local tp = GetEntityCoords(foundPed)
            if #(p - tp) <= (Config.DrugSell.maxDistanceToPed or 3.0) then
                target = foundPed
                break
            end
        end
        ok, foundPed = FindNextPed(handle)
    until not ok
    EndFindPed(handle)

    if target == 0 then
        return QBCore.Functions.Notify('Netoliese nėra NPC pirkėjų.', 'error')
    end

    QBCore.Functions.TriggerCallback('fivempro_gangs:server:tryDrugSale', function(res)
        if not res or not res.ok then
            if res and res.refused then
                QBCore.Functions.Notify('NPC atsisakė. Bandyk kitą.', 'error')
            else
                QBCore.Functions.Notify((res and res.reason) or 'Pardavimas nepavyko.', 'error')
            end
            return
        end
        QBCore.Functions.Notify(('Parduota (%s) už $%s'):format(res.item or 'item', res.price or 0), 'success')
        if res.alertPolice then
            local cp = GetEntityCoords(PlayerPedId())
            TriggerServerEvent('fivempro_dispatch:server:createServiceCall', 'police', 'drug', 'Pranešta apie įtartiną sandorį', { x = cp.x, y = cp.y, z = cp.z })
        end
    end, turfId, NetworkGetNetworkIdFromEntity(target))
end, false)

RegisterCommand('gangadmin', function()
    openAdminMenu()
end, false)

local function openVendorMenu()
    local price = tonumber(Config.TabletVendor and Config.TabletVendor.tabletPrice) or 5000
    local menu = {
        { header = 'Gaujų ryšininkas', txt = 'Planšetės ir kontaktai', isMenuHeader = true },
        {
            header = ('Pirkti gang planšetę ($%s)'):format(price),
            txt = 'Reikalinga gaujos registravimui ir valdymui',
            params = {
                isAction = true,
                event = function()
                    TriggerServerEvent('fivempro_gangs:server:buyTablet')
                end,
            },
        },
    }
    TriggerEvent('qb-menu:client:openMenu', menu, false, true)
end

CreateThread(function()
    local v = Config.TabletVendor
    if not v or not v.coords then return end

    if v.blip and v.blip.enabled then
        local b = AddBlipForCoord(v.coords.x + 0.0, v.coords.y + 0.0, v.coords.z + 0.0)
        SetBlipSprite(b, v.blip.sprite or 521)
        SetBlipDisplay(b, 4)
        SetBlipScale(b, v.blip.scale or 0.8)
        SetBlipColour(b, v.blip.color or 1)
        SetBlipAsShortRange(b, v.blip.shortRange ~= false)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(v.blip.label or 'Gang Tablet NPC')
        EndTextCommandSetBlipName(b)
    end

    local model = joaat(v.model or 'g_m_y_lost_01')
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(0)
    end
    vendorPed = CreatePed(4, model, v.coords.x + 0.0, v.coords.y + 0.0, v.coords.z - 1.0, v.coords.w + 0.0, false, true)
    SetEntityInvincible(vendorPed, true)
    SetBlockingOfNonTemporaryEvents(vendorPed, true)
    FreezeEntityPosition(vendorPed, true)

    if GetResourceState('qb-target') == 'started' then
        exports['qb-target']:AddTargetEntity(vendorPed, {
            options = {
                {
                    icon = 'fas fa-tablet-alt',
                    label = v.label or 'Gaujų ryšininkas',
                    action = function()
                        openVendorMenu()
                    end,
                },
            },
            distance = 2.5,
        })
    else
        while true do
            Wait(0)
            local ped = PlayerPedId()
            local p = GetEntityCoords(ped)
            local d = #(p - vector3(v.coords.x, v.coords.y, v.coords.z))
            if d <= 2.0 then
                SetTextComponentFormat('STRING')
                AddTextComponentString('Spausk ~INPUT_CONTEXT~ kalbėti su gaujų ryšininku')
                DisplayHelpTextFromStringLabel(0, 0, 1, -1)
                if IsControlJustReleased(0, 38) then
                    openVendorMenu()
                    Wait(400)
                end
            end
        end
    end
end)
