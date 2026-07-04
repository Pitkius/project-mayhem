DutyLocker = DutyLocker or {}

DutyLocker.Categories = {
    { id = 'hat',          label = 'Kepurės',           order = 1 },
    { id = 'uniform_top',  label = 'Viršutiniai rūbai', order = 2 },
    { id = 'vest',         label = 'Liemenės',          order = 3 },
    { id = 'uniform_pants', label = 'Kelnės',           order = 4 },
    { id = 'belt',         label = 'Diržai',            order = 5 },
    { id = 'extra',        label = 'Extra',             order = 6 },
}

--- Kuriuos slotus keičia kategorija (ne visi komponentai iš įrašo)
DutyLocker.CategorySlots = {
    hat = { props = { 0 } },
    uniform_top = { components = { 3, 8, 11 } },
    vest = { components = { 9 } },
    uniform_pants = { components = { 4, 6 } },
    belt = { components = { 7 } },
    extra = { components = { 1, 5, 10 }, props = { 1, 2, 6, 7 } },
}

DutyLocker.ComponentApplyOrder = { 3, 8, 11, 4, 6, 7, 9, 10, 1, 2, 5 }

function DutyLocker.inferCategory(outfit, genderKey)
    if outfit.category and outfit.category ~= '' then
        return outfit.category
    end
    local tbl = genderKey and outfit[genderKey] or nil
    if not tbl then return 'uniform_top' end
    local comps = tbl.components or tbl
    if type(comps) ~= 'table' then return 'uniform_top' end

    local has = {}
    for comp, _ in pairs(comps) do
        local c = tonumber(comp)
        if c then has[c] = true end
    end
    if tbl.props and tbl.props[0] then return 'hat' end
    if has[9] and not has[11] and not has[4] then return 'vest' end
    if has[7] and not has[4] and not has[11] then return 'belt' end
    if has[4] or has[6] then
        if has[11] or has[3] or has[8] then return 'uniform_top' end
        return 'uniform_pants'
    end
    if has[10] or has[5] or has[1] then return 'extra' end
    if has[11] or has[3] or has[8] then return 'uniform_top' end
    return 'extra'
end
