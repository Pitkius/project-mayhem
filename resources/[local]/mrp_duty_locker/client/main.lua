local QBCore = exports['qb-core']:GetCoreObject()

local session = nil
local applyBusy = false
local applyPending = nil

local function runApplyJob(itemId, data)
    if applyBusy then
        applyPending = { id = itemId, data = data }
        return
    end
    applyBusy = true
    CreateThread(function()
        if session and session.onApply and itemId ~= nil then
            session.onApply(itemId, data)
        end
        Wait(280)
        applyBusy = false
        if applyPending and session then
            local nextJob = applyPending
            applyPending = nil
            runApplyJob(nextJob.id, nextJob.data)
        end
    end)
end

local function notify(msg, ntype)
    QBCore.Functions.Notify(msg, ntype or 'primary')
end

local function closeLocker(reason)
    if not session then return end
    applyPending = nil
    applyBusy = false
    session = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    if reason == 'escape' then
        notify('Rūbinė uždaryta.', 'primary')
    elseif reason == 'distance' then
        notify('Per toli nuo rūbinės — meniu uždaryta.', 'error')
    end
end

local function categoryMetaList(activeIds)
    local active = {}
    for _, id in ipairs(activeIds or {}) do active[id] = true end
    local out = {}
    for _, cat in ipairs(DutyLocker.Categories) do
        if active[cat.id] then
            out[#out + 1] = { id = cat.id, label = cat.label }
        end
    end
    table.sort(out, function(a, b)
        local oa, ob = 99, 99
        for _, c in ipairs(DutyLocker.Categories) do
            if c.id == a.id then oa = c.order end
            if c.id == b.id then ob = c.order end
        end
        return oa < ob
    end)
    return out
end

local function buildUiPayload(opts)
    local categoriesWithItems = {}
    local catSet = {}
    for _, item in ipairs(opts.items or {}) do
        if item.category then catSet[item.category] = true end
    end
    for _, cat in ipairs(DutyLocker.Categories) do
        if catSet[cat.id] then
            categoriesWithItems[#categoriesWithItems + 1] = cat.id
        end
    end

    return {
        title = opts.title or 'Darbo apranga',
        subtitle = opts.subtitle or '',
        categories = categoryMetaList(categoriesWithItems),
        items = opts.items or {},
        actions = opts.actions or {},
        hint = 'ESC — uždaryti · palik markerį — meniu užsidaro',
    }
end

function OpenDutyLocker(opts)
    if not opts or type(opts.items) ~= 'table' then return false end
    if opts.canOpen and not opts.canOpen() then return false end
    if #opts.items == 0 then
        notify('Nėra prieinamos aprangos.', 'error')
        return false
    end

    if session then closeLocker() end

    local ped = PlayerPedId()
    local anchor = opts.anchor
    if anchor then
        if type(anchor) == 'vector4' then
            anchor = vector3(anchor.x, anchor.y, anchor.z)
        elseif type(anchor) == 'table' then
            anchor = vector3(anchor.x + 0.0, anchor.y + 0.0, anchor.z + 0.0)
        end
    else
        anchor = GetEntityCoords(ped)
    end

    session = {
        anchor = anchor,
        radius = tonumber(opts.radius) or 2.6,
        onApply = opts.onApply,
        onAction = opts.onAction,
        onClose = opts.onClose,
    }

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        data = buildUiPayload(opts),
    })
    return true
end

exports('Open', OpenDutyLocker)
exports('Close', function() closeLocker('manual') end)
exports('IsOpen', function() return session ~= nil end)
exports('InferCategory', function(outfit, genderKey)
    return DutyLocker.inferCategory(outfit, genderKey)
end)
exports('ApplyCategory', function(ped, tbl, category)
    DutyApply.applyPartial(ped, tbl, category)
end)
exports('ClearCategory', function(ped, category)
    DutyApply.clearCategory(ped, category)
end)
exports('GetGenderKey', function(ped)
    return DutyApply.getGenderKey(ped)
end)

RegisterNUICallback('dutyLockerClose', function(_, cb)
    closeLocker('escape')
    cb({ ok = true })
end)

RegisterNUICallback('dutyLockerApply', function(data, cb)
    cb({ ok = true })
    if not session then return end
    local itemId = data and data.id
    if session.onApply and itemId ~= nil then
        runApplyJob(itemId, data)
    end
end)

RegisterNUICallback('dutyLockerAction', function(data, cb)
    if not session then cb({ ok = false }) return end
    local actionId = data and data.id
    if session.onAction and actionId then
        session.onAction(actionId)
    end
    cb({ ok = true })
end)

CreateThread(function()
    while true do
        if session then
            local ped = PlayerPedId()
            local dist = #(GetEntityCoords(ped) - session.anchor)
            if dist > session.radius then
                closeLocker('distance')
            else
                DisableControlAction(0, 200, true)
                if IsDisabledControlJustReleased(0, 200) or IsControlJustReleased(0, 322) then
                    closeLocker('escape')
                end
            end
            Wait(0)
        else
            Wait(400)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        if session then
            SetNuiFocus(false, false)
            session = nil
        end
    end
end)
