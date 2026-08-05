PhoneFactoryReset = PhoneFactoryReset or {}

local DATA_TABLES = {
    { table = 'mrp_phone_contacts', col = 'phone_id' },
    { table = 'mrp_phone_messages', col = 'phone_id' },
    { table = 'mrp_phone_call_log', col = 'phone_id' },
    { table = 'mrp_phone_photos', col = 'phone_id' },
    { table = 'mrp_phone_notes', col = 'phone_id' },
    { table = 'mrp_phone_ads', col = 'phone_id' },
    { table = 'mrp_phone_ad_profiles', col = 'phone_id' },
    { table = 'mrp_phone_posts', col = 'phone_id' },
    { table = 'mrp_phone_installed_apps', col = 'phone_id' },
    { table = 'mrp_phone_bank_accounts', col = 'phone_id' },
    { table = 'mrp_phone_bank_transactions', col = 'phone_id' },
    { table = 'mrp_phone_encrypted_threads', col = 'phone_id' },
    { table = 'mrp_phone_encrypted_messages', col = 'phone_id' },
}

function PhoneFactoryReset.Run(phoneId, actorCitizenid)
    local row = PhoneCore.GetById(phoneId)
    if not row then return false, 'Telefonas nerastas.' end
    if PhoneStates.Normalize(row.status) == PhoneStates.DESTROYED then
        return false, 'Sunaikinto telefono resetinti negalima.'
    end
    if PhoneStates.Normalize(row.status) == PhoneStates.EVIDENCE then
        return false, 'Telefonas pažymėtas kaip įrodymas.'
    end

    for _, t in ipairs(DATA_TABLES) do
        MySQL.update.await(('DELETE FROM `%s` WHERE `%s` = ?'):format(t.table, t.col), { phoneId })
    end

    local number = PhoneIdentity.NewNumber()
    local imei = PhoneIdentity.NewImei()
    local simId = PhoneIdentity.NewSimId()

    MySQL.update.await([[
        UPDATE mrp_phones
        SET owner_citizenid = NULL,
            phone_number = ?,
            imei = ?,
            sim_id = ?,
            pin_hash = NULL,
            status = 'active',
            pin_fail_count = 0,
            pin_lockout_until = 0
        WHERE phone_id = ?
    ]], { number, imei, simId, phoneId })

    PhoneCore.EnsureDefaults(phoneId, row.phone_type)
    PhoneDB.Audit(phoneId, actorCitizenid, 'factory_reset', nil)

    for _, playerId in ipairs(GetPlayers()) do
        local src = tonumber(playerId)
        local s = PhoneSession.Get(src)
        if s and s.phoneId == phoneId then
            PhoneSession.Clear(src)
            TriggerClientEvent('mrp_phone:client:forceClose', src, { reason = 'factory_reset' })
        end
    end

    return true, PhoneCore.Public(PhoneCore.GetById(phoneId))
end
