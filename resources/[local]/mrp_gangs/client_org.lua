--[[
  mrp_gangs — Organizacijos meniu (client)
  NUI fokusas, saugus callback tiltas, narių pakvietimų pop-up.
  Klientas NIEKADA nesprendžia teisių — tik atvaizduoja serverio duomenis.
]]

local QBCore = exports['qb-core']:GetCoreObject()

local orgOpen = false
local inviteOpen = false

-- Serverio callback'ai, kuriuos NUI leidžiama kviesti (baltasis sąrašas).
local ALLOWED_CALLBACKS = {
    ['getState'] = true,
    ['getLogs'] = true,
    ['createRank'] = true, ['editRank'] = true, ['setRankPermissions'] = true,
    ['setRankParent'] = true, ['deleteRank'] = true, ['moveRankMembers'] = true,
    ['setMemberRank'] = true, ['kickMember'] = true, ['setMemberStatus'] = true,
    ['setMemberNotes'] = true, ['setMemberResponsibilities'] = true,
    ['setMemberOverrides'] = true, ['transferOwnership'] = true,
    ['addAssociate'] = true, ['editAssociate'] = true, ['removeAssociate'] = true, ['promoteAssociate'] = true,
    ['setRelation'] = true, ['acceptRelation'] = true, ['declineRelation'] = true, ['breakRelation'] = true,
    ['saveSettings'] = true,
}

local function closeOrg()
    if not orgOpen and not inviteOpen then return end
    orgOpen = false
    inviteOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'orgClose' })
end

RegisterNetEvent('mrp_gangs:client:org:open', function()
    if orgOpen then closeOrg() end
    orgOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'orgOpen' })
end)

RegisterNetEvent('mrp_gangs:client:org:refresh', function()
    if not orgOpen then return end
    SendNUIMessage({ action = 'orgRefresh' })
end)

-- Narių pakvietimo pasiūlymas (rodomas net jei meniu uždarytas).
RegisterNetEvent('mrp_gangs:client:org:invite', function(data)
    inviteOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'orgInvite', payload = data or {} })
end)

-- ── NUI callback'ai ────────────────────────────────────────────────
RegisterNUICallback('org:close', function(_, cb)
    closeOrg()
    TriggerServerEvent('mrp_gangs:server:clearTabletSession')
    cb({ ok = true })
end)

-- Saugus tiltas į serverio callback'us (tik iš baltojo sąrašo).
RegisterNUICallback('org:call', function(data, cb)
    local name = data and tostring(data.name or '')
    if not ALLOWED_CALLBACKS[name] then return cb({ ok = false, msg = 'Neleidžiamas veiksmas.' }) end
    QBCore.Functions.TriggerCallback('mrp_gangs:server:org:' .. name, function(res)
        cb(res or { ok = false })
    end, data.payload or {})
end)

-- Nario pakvietimas (serverio event; serveris notifikuoja).
RegisterNUICallback('org:invitePlayer', function(data, cb)
    local targetId = data and tonumber(data.targetServerId)
    if targetId then
        TriggerServerEvent('mrp_gangs:server:org:invitePlayer', targetId, data.rankId)
    end
    cb({ ok = true })
end)

-- Atsakymas į pakvietimą.
RegisterNUICallback('org:respondInvite', function(data, cb)
    TriggerServerEvent('mrp_gangs:server:org:respondInvite', data and data.accept == true)
    inviteOpen = false
    if not orgOpen then SetNuiFocus(false, false) end
    cb({ ok = true })
end)

-- Uždarymą (ESC / mygtukas) inicijuoja NUI per org:close callback'ą.

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and (orgOpen or inviteOpen) then
        SetNuiFocus(false, false)
    end
end)
