--[[
  Phone lifecycle callbacks: open, setup PIN, unlock, factory reset, police status.
  Loaded after core modules.
]]

local QBCore = exports['qb-core']:GetCoreObject()

local function citizenOf(src)
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return nil, nil end
    return P.PlayerData.citizenid, P
end

QBCore.Functions.CreateCallback('mrp_phone:server:prepareOpen', function(src, cb, data)
    local itemName = tostring((data and data.itemName) or Config.PhoneItem or 'phone')
    local slot = data and tonumber(data.slot) or nil
    local phoneId = data and data.phoneId or nil

    local row
    if phoneId then
        row = PhoneCore.GetById(phoneId)
        local item = select(1, PhoneCore.FindPlayerPhoneItem(src, phoneId))
        if not item then
            return cb({ ok = false, message = 'Neturi šio telefono inventoriuje.' })
        end
    else
        row = select(1, PhoneCore.BindOrCreateFromItem(src, itemName, slot))
    end

    if not row then
        return cb({ ok = false, message = 'Nepavyko paruošti telefono.' })
    end

    if PhoneStates.BlocksUse(row.status) then
        return cb({ ok = false, message = ('Telefonas nepasiekiamas (%s).'):format(row.status) })
    end

    if PhoneTypes.Normalize(row.phone_type) == PhoneTypes.DARKNET then
        if GetResourceState('mrp_drugs') == 'started' then
            local okAccess, has = pcall(function()
                return exports['mrp_drugs']:DarkNetHasAccess(src)
            end)
            if not okAccess or not has then
                return cb({ ok = false, message = 'Įrenginys neaktyvuotas (nėra DarkNet prieigos).' })
            end
        end
    end

    local payload = PhoneCore.BuildOpenPayload(src, row.phone_id)
    payload.ok = true
    cb(payload)
end)

QBCore.Functions.CreateCallback('mrp_phone:server:setupPin', function(src, cb, data)
    local phoneId = data and data.phoneId
    local pin = data and data.pin
    local row = PhoneCore.GetById(phoneId)
    if not row then return cb({ ok = false, message = 'Telefonas nerastas.' }) end
    if not PhoneCore.FindPlayerPhoneItem(src, phoneId) then
        return cb({ ok = false, message = 'Neturi šio telefono.' })
    end
    if row.pin_hash and row.pin_hash ~= '' then
        return cb({ ok = false, message = 'PIN jau nustatytas.' })
    end
    if PhoneStates.BlocksUse(row.status) then
        return cb({ ok = false, message = 'Telefonas užblokuotas.' })
    end
    local cid = citizenOf(src)
    local ok, err = PhoneCore.SetOwnerAndPin(phoneId, cid, pin)
    if not ok then return cb({ ok = false, message = err }) end
    PhoneSession.Set(src, phoneId, row.phone_type)
    cb({ ok = true, payload = PhoneCore.BuildOpenPayload(src, phoneId) })
end)

QBCore.Functions.CreateCallback('mrp_phone:server:unlockPin', function(src, cb, data)
    local phoneId = data and data.phoneId
    local pin = data and data.pin
    if not PhoneCore.FindPlayerPhoneItem(src, phoneId) then
        return cb({ ok = false, message = 'Neturi šio telefono.' })
    end
    local ok, err, pub = PhoneCore.TryUnlock(src, phoneId, pin)
    if not ok then
        return cb({ ok = false, message = err, phone = pub })
    end
    cb({ ok = true, payload = PhoneCore.BuildOpenPayload(src, phoneId) })
end)

QBCore.Functions.CreateCallback('mrp_phone:server:factoryReset', function(src, cb, data)
    local phoneId = data and data.phoneId
    local pin = data and data.pin
    if not PhoneCore.FindPlayerPhoneItem(src, phoneId) then
        return cb({ ok = false, message = 'Neturi šio telefono.' })
    end
    local row = PhoneCore.GetById(phoneId)
    if not row or not row.pin_hash then
        return cb({ ok = false, message = 'Telefonas neaktyvuotas.' })
    end
    if not PhonePin.Verify(pin, row.pin_hash) then
        return cb({ ok = false, message = 'Neteisingas PIN.' })
    end
    local cid = citizenOf(src)
    local ok, result = PhoneFactoryReset.Run(phoneId, cid)
    if not ok then return cb({ ok = false, message = result }) end
    PhoneSession.Clear(src)
    cb({ ok = true, phone = result })
end)

QBCore.Functions.CreateCallback('mrp_phone:server:policeSetStatus', function(src, cb, data)
    local ok, result = PhonePolice.SetStatus(src, data and data.phoneId, data and data.status, data and data.reason)
    if not ok then return cb({ ok = false, message = result }) end
    cb({ ok = true, phone = result })
end)

RegisterNetEvent('mrp_phone:server:closeSession', function()
    PhoneSession.Clear(source)
end)

-- Useable items → open with that item
CreateThread(function()
    Wait(500)
    local function registerUse(itemName)
        QBCore.Functions.CreateUseableItem(itemName, function(source, item)
            TriggerClientEvent('mrp_phone:client:openPhoneDevice', source, {
                itemName = itemName,
                slot = item and item.slot or nil,
                phoneId = item and item.info and item.info.phone_id or nil,
            })
        end)
    end
    registerUse(Config.PhoneItem or 'phone')
    registerUse('darknet_phone')
end)
