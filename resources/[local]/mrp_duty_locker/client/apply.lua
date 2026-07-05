DutyApply = DutyApply or {}

local function applyComponent(ped, compId, val)
    if not ped or compId == nil or val == nil then return end
    local draw, tex, collection = 0, 0, nil
    if type(val) == 'table' then
        draw = tonumber(val.draw or val[1]) or 0
        tex = tonumber(val.tex or val[2]) or 0
        collection = val.collection
    else
        draw = tonumber(val) or 0
    end
    if collection and collection ~= '' then
        SetPedCollectionComponentVariation(ped, compId, collection, draw, tex, 0)
        Wait(0)
    else
        SetPedComponentVariation(ped, compId, draw, tex, 0)
    end
end

local function applyProp(ped, propSlot, val)
    if not ped or propSlot == nil then return end
    if val == false or val == -1 then
        ClearPedProp(ped, propSlot)
        return
    end
    if val == nil then return end
    local draw, tex, collection = 0, 0, nil
    if type(val) == 'table' then
        draw = tonumber(val.draw or val[1]) or 0
        tex = tonumber(val.tex or val[2]) or 0
        collection = val.collection
    else
        draw = tonumber(val) or 0
    end
    if collection and collection ~= '' then
        SetPedCollectionPropIndex(ped, propSlot, collection, draw, tex, true)
    else
        SetPedPropIndex(ped, propSlot, draw, tex, true)
    end
end

local function applyProp(ped, propSlot, val)
    local slots = DutyLocker.CategorySlots[category]
    if not slots then return true end
    if compId then
        for _, id in ipairs(slots.components or {}) do
            if id == compId then return true end
        end
        return false
    end
    if propId then
        for _, id in ipairs(slots.props or {}) do
            if id == propId then return true end
        end
        return false
    end
    return false
end

function DutyApply.clearCategory(ped, category)
    if not ped or not category then return end
    if category == 'hat' then
        ClearPedProp(ped, 0)
    elseif category == 'vest' then
        SetPedComponentVariation(ped, 9, 0, 0, 0)
    elseif category == 'belt' then
        SetPedComponentVariation(ped, 7, 0, 0, 0)
        SetPedComponentVariation(ped, 8, 0, 0, 0)
    elseif category == 'extra' then
        for _, compId in ipairs({ 1, 5, 10 }) do
            SetPedComponentVariation(ped, compId, 0, 0, 0)
        end
        for _, propId in ipairs({ 1, 2, 6, 7 }) do
            ClearPedProp(ped, propId)
        end
    end
end

function DutyApply.applyPartial(ped, tbl, category)
    if not ped or not tbl or not category then return end
    if tbl.remove then
        DutyApply.clearCategory(ped, category)
        return
    end

    local comps = tbl.components or tbl
    if type(comps) == 'table' then
        local filtered = {}
        for comp, val in pairs(comps) do
            local c = tonumber(comp)
            if c and slotAllowed(category, c, nil) then
                filtered[c] = val
            end
        end
        for _, compId in ipairs(DutyLocker.ComponentApplyOrder) do
            if filtered[compId] ~= nil then
                applyComponent(ped, compId, filtered[compId])
            end
        end
    end

    local props = tbl.props
    if type(props) == 'table' then
        for slot, val in pairs(props) do
            local p = tonumber(slot)
            if p ~= nil and slotAllowed(category, nil, p) then
                applyProp(ped, p, val)
            end
        end
    end
end

function DutyApply.getGenderKey(ped)
    return GetEntityModel(ped) == `mp_m_freemode_01` and 'male' or 'female'
end
