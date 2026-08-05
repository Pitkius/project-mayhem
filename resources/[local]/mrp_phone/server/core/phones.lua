PhoneCore = PhoneCore or {}

local QBCore = exports['qb-core']:GetCoreObject()

local function rowPublic(row, includePinMeta)
    if not row then return nil end
    local out = {
        phoneId = row.phone_id,
        ownerCitizenid = row.owner_citizenid,
        phoneNumber = tostring(row.phone_number or ''),
        imei = tostring(row.imei or ''),
        simId = tostring(row.sim_id or ''),
        phoneType = PhoneTypes.Normalize(row.phone_type),
        status = PhoneStates.Normalize(row.status),
        hasPin = row.pin_hash ~= nil and row.pin_hash ~= '',
        createdAt = row.created_at,
    }
    if includePinMeta then
        out.pinFailCount = tonumber(row.pin_fail_count) or 0
        out.pinLockoutUntil = tonumber(row.pin_lockout_until) or 0
    end
    return out
end

function PhoneCore.GetById(phoneId)
    if not phoneId then return nil end
    return MySQL.single.await('SELECT * FROM mrp_phones WHERE phone_id = ? LIMIT 1', { phoneId })
end

function PhoneCore.GetByNumber(number)
    number = tostring(number or ''):gsub('%D+', '')
    if number == '' then return nil end
    return MySQL.single.await('SELECT * FROM mrp_phones WHERE phone_number = ? LIMIT 1', { number })
end

function PhoneCore.Public(row)
    return rowPublic(row, true)
end

function PhoneCore.EnsureDefaults(phoneId, phoneType)
    phoneType = PhoneTypes.Normalize(phoneType)
    if phoneType ~= PhoneTypes.LEGAL then return end
    for _, contact in ipairs((Config.Phone and Config.Phone.DefaultContacts) or {}) do
        local exists = MySQL.scalar.await(
            'SELECT id FROM mrp_phone_contacts WHERE phone_id = ? AND number = ? LIMIT 1',
            { phoneId, tostring(contact.number) }
        )
        if not exists then
            MySQL.insert.await(
                'INSERT INTO mrp_phone_contacts (phone_id, name, number, service, icon, is_default) VALUES (?, ?, ?, ?, ?, 1)',
                { phoneId, contact.name, tostring(contact.number), contact.service, contact.icon }
            )
        end
    end
    for appId, enabled in pairs(PhoneApps.LegalDefaults or {}) do
        if enabled then
            if not (appId == 'camera' or appId == 'gallery') or (Config.Phone and Config.Phone.enablePhotos) then
                MySQL.insert.await(
                    'INSERT IGNORE INTO mrp_phone_installed_apps (phone_id, app_id) VALUES (?, ?)',
                    { phoneId, appId }
                )
            end
        end
    end
end

--- Create a brand-new phone device row (no owner / no PIN yet).
function PhoneCore.CreateDevice(phoneType)
    phoneType = PhoneTypes.Normalize(phoneType)
    local phoneId = PhoneIdentity.NewPhoneId()
    local number = PhoneIdentity.NewNumber()
    local imei = PhoneIdentity.NewImei()
    local simId = PhoneIdentity.NewSimId()
    MySQL.insert.await([[
        INSERT INTO mrp_phones
          (phone_id, owner_citizenid, phone_number, imei, sim_id, pin_hash, phone_type, status, pin_fail_count, pin_lockout_until)
        VALUES (?, NULL, ?, ?, ?, NULL, ?, 'active', 0, 0)
    ]], { phoneId, number, imei, simId, phoneType })
    PhoneCore.EnsureDefaults(phoneId, phoneType)
    PhoneDB.Audit(phoneId, nil, 'create_device', phoneType)
    return PhoneCore.GetById(phoneId)
end

function PhoneCore.FindPlayerPhoneItem(src, phoneId)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Player.PlayerData or not Player.PlayerData.items then return nil, nil end
    for slot, item in pairs(Player.PlayerData.items) do
        if item and item.info and tostring(item.info.phone_id or '') == tostring(phoneId) then
            return item, tonumber(item.slot) or tonumber(slot)
        end
    end
    return nil, nil
end

function PhoneCore.FindAnyPhoneItem(src, preferredType)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player or not Player.PlayerData or not Player.PlayerData.items then return nil end
    local wantType = preferredType and PhoneTypes.Normalize(preferredType) or nil
    local fallback = nil
    for _, item in pairs(Player.PlayerData.items) do
        if item and item.name and PhoneTypes.TypeByItem[item.name] then
            local itemType = PhoneTypes.FromItem(item.name)
            local info = item.info or {}
            if not info.phone_id then
                -- unbound item — usable for binding
                if not wantType or wantType == itemType then
                    return item, itemType, true
                end
            else
                if wantType and wantType == itemType then
                    return item, itemType, false
                end
                if not fallback then
                    fallback = { item = item, itemType = itemType, unbound = false }
                end
            end
        end
    end
    if fallback then
        return fallback.item, fallback.itemType, fallback.unbound
    end
    return nil
end

local function setItemPhoneId(src, itemName, slot, phoneId, phoneType)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    local items = Player.PlayerData.items
    local target = nil
    if slot and items[slot] then
        target = items[slot]
    else
        for s, it in pairs(items) do
            if it and it.name == itemName and (not it.info or not it.info.phone_id) then
                target = it
                slot = tonumber(it.slot) or tonumber(s)
                break
            end
        end
    end
    if not target then return false end
    target.info = target.info or {}
    target.info.phone_id = phoneId
    target.info.phone_type = phoneType
    Player.Functions.SetPlayerData('items', items)
    if GetResourceState('qb-inventory') == 'started' then
        pcall(function()
            exports['qb-inventory']:SaveInventory(src, false)
        end)
    end
    return true
end

--- Bind inventory item to a device (create if needed). Returns phone row.
function PhoneCore.BindOrCreateFromItem(src, itemName, slot)
    local phoneType = PhoneTypes.FromItem(itemName)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return nil, 'Žaidėjas nerastas.' end

    local items = Player.PlayerData.items or {}
    local item = slot and items[slot] or nil
    if not item then
        for s, it in pairs(items) do
            if it and it.name == itemName then
                item = it
                slot = tonumber(it.slot) or tonumber(s)
                break
            end
        end
    end
    if not item then return nil, 'Telefono itemas nerastas.' end

    local existingId = item.info and item.info.phone_id
    if existingId then
        local row = PhoneCore.GetById(existingId)
        if row then return row end
    end

    local row = PhoneCore.CreateDevice(phoneType)
    if not row then return nil, 'Nepavyko sukurti telefono.' end
    setItemPhoneId(src, itemName, slot, row.phone_id, phoneType)
    return row
end

function PhoneCore.SetOwnerAndPin(phoneId, citizenid, pin)
    if not PhonePin.IsValidFormat(pin) then
        return false, 'PIN turi būti 4 skaitmenys.'
    end
    local hash = PhonePin.Hash(pin)
    if not hash or hash == '' then
        return false, 'Nepavyko užšifruoti PIN.'
    end
    MySQL.update.await([[
        UPDATE mrp_phones
        SET owner_citizenid = ?, pin_hash = ?, status = 'active', pin_fail_count = 0, pin_lockout_until = 0
        WHERE phone_id = ?
    ]], { citizenid, hash, phoneId })
    PhoneDB.Audit(phoneId, citizenid, 'activate', 'pin_set')
    return true
end

function PhoneCore.TryUnlock(src, phoneId, pin)
    local row = PhoneCore.GetById(phoneId)
    if not row then return false, 'Telefonas nerastas.', nil end

    if PhoneStates.BlocksUse(row.status) then
        return false, ('Telefonas nepasiekiamas (%s).'):format(row.status), rowPublic(row, true)
    end

    local now = os.time()
    local lockoutUntil = tonumber(row.pin_lockout_until) or 0
    if lockoutUntil > now then
        local left = lockoutUntil - now
        return false, ('Telefonas užrakintas. Palauk %ss.'):format(left), rowPublic(row, true)
    end

    if not row.pin_hash or row.pin_hash == '' then
        return false, 'need_setup', rowPublic(row, true)
    end

    if not PhonePin.IsValidFormat(pin) or not PhonePin.Verify(pin, row.pin_hash) then
        local fails = (tonumber(row.pin_fail_count) or 0) + 1
        local lockout = 0
        local status = row.status
        if fails >= PhonePin.FailsBeforeLockedStatus() then
            status = PhoneStates.LOCKED
            fails = fails
        elseif fails % PhonePin.FailsBeforeLockout() == 0 then
            lockout = now + PhonePin.LockoutSeconds()
        end
        MySQL.update.await(
            'UPDATE mrp_phones SET pin_fail_count = ?, pin_lockout_until = ?, status = ? WHERE phone_id = ?',
            { fails, lockout, status, phoneId }
        )
        PhoneDB.Audit(phoneId, nil, 'pin_fail', tostring(fails))
        if status == PhoneStates.LOCKED then
            return false, 'Telefonas užrakintas po per daug neteisingų bandymų.', rowPublic(PhoneCore.GetById(phoneId), true)
        end
        if lockout > now then
            return false, ('Neteisingas PIN. Užrakinta %ss.'):format(PhonePin.LockoutSeconds()), rowPublic(PhoneCore.GetById(phoneId), true)
        end
        return false, 'Neteisingas PIN.', rowPublic(PhoneCore.GetById(phoneId), true)
    end

    MySQL.update.await(
        'UPDATE mrp_phones SET pin_fail_count = 0, pin_lockout_until = 0 WHERE phone_id = ?',
        { phoneId }
    )
    -- If someone else unlocks with PIN, they can use it; ownership stays until factory reset
    PhoneSession.Set(src, phoneId, row.phone_type)
    PhoneDB.Audit(phoneId, nil, 'pin_ok', tostring(src))
    return true, nil, rowPublic(PhoneCore.GetById(phoneId), true)
end

function PhoneCore.BuildOpenPayload(src, phoneId)
    local row = PhoneCore.GetById(phoneId)
    if not row then return nil end
    local phoneType = PhoneTypes.Normalize(row.phone_type)
    local installed = {}
    if phoneType == PhoneTypes.LEGAL then
        local rows = MySQL.query.await('SELECT app_id FROM mrp_phone_installed_apps WHERE phone_id = ?', { phoneId }) or {}
        for _, r in ipairs(rows) do
            installed[tostring(r.app_id)] = true
        end
        -- always include defaults
        for appId, on in pairs(PhoneApps.LegalDefaults or {}) do
            if on then installed[appId] = true end
        end
    else
        for _, appId in ipairs(PhoneApps.ByType.darknet or {}) do
            installed[appId] = true
        end
    end

    local apps = {}
    for _, app in ipairs(PhoneApps.ListForType(phoneType)) do
        if phoneType == PhoneTypes.DARKNET or installed[app.id] then
            apps[#apps + 1] = app
        end
    end

    return {
        phone = rowPublic(row, true),
        apps = apps,
        needSetup = not row.pin_hash or row.pin_hash == '',
        session = PhoneSession.Get(src) ~= nil and PhoneSession.Get(src).phoneId == phoneId,
        config = {
            enablePhotos = Config.Phone and Config.Phone.enablePhotos == true,
            pinLength = (Config.Phone and Config.Phone.Pin and Config.Phone.Pin.length) or 4,
            appStore = Config.Phone and Config.Phone.AppStoreApps or {},
        },
    }
end

exports('GetPhoneById', PhoneCore.GetById)
exports('GetPhoneByNumber', PhoneCore.GetByNumber)
exports('CreatePhoneDevice', function(phoneType)
    return PhoneCore.CreateDevice(phoneType)
end)
