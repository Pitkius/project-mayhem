CharTattoos = CharTattoos or {}

local function catalog()
    return Config.Tattoos or {}
end

function CharTattoos.overlayForEntry(entry, gender)
    if not entry then return nil, nil end
    if entry.collection and entry.overlay then
        return entry.collection, entry.overlay
    end
    local zoneList = catalog()[entry.zone]
    if not zoneList or not entry.name then return nil, nil end
    for _, t in ipairs(zoneList) do
        if t.name == entry.name then
            local overlay = (gender == 1) and t.hashFemale or t.hashMale
            return t.collection, overlay
        end
    end
    return nil, nil
end

function CharTattoos.applyToPed(ped, tattoos, gender)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    ClearPedDecorations(ped)
    if type(tattoos) ~= 'table' then return end
    for _, entry in ipairs(tattoos) do
        local collection, overlay = CharTattoos.overlayForEntry(entry, gender)
        if collection and overlay then
            AddPedDecorationFromHashes(ped, joaat(collection), joaat(overlay))
        end
    end
end

function CharTattoos.applyPreviewOutfit(ped, gender)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    local female = gender == 1
    if female then
        SetPedComponentVariation(ped, 8, 14, 0, 0)
        SetPedComponentVariation(ped, 11, 15, 0, 0)
        SetPedComponentVariation(ped, 4, 15, 0, 0)
        SetPedComponentVariation(ped, 3, 15, 0, 0)
        SetPedComponentVariation(ped, 6, 35, 0, 0)
    else
        SetPedComponentVariation(ped, 8, 15, 0, 0)
        SetPedComponentVariation(ped, 11, 15, 0, 0)
        SetPedComponentVariation(ped, 4, 14, 0, 0)
        SetPedComponentVariation(ped, 3, 15, 0, 0)
        SetPedComponentVariation(ped, 6, 34, 0, 0)
    end
end

function CharTattoos.refreshPreview(ped, skin, gender, tattooShop)
    if not ped or ped == 0 or not skin then return end
    if tattooShop then
        CharTattoos.applyPreviewOutfit(ped, gender)
    end
    CharTattoos.applyToPed(ped, skin.tattoos, gender)
end

function CharTattoos.getZoneCatalog(zone, gender)
    local list = catalog()[zone]
    if not list then return {} end
    local out = {}
    for _, t in ipairs(list) do
        out[#out + 1] = {
            name = t.name,
            label = t.label or t.name,
            zone = zone,
            collection = t.collection,
            overlay = (gender == 1) and t.hashFemale or t.hashMale,
        }
    end
    table.sort(out, function(a, b)
        return (a.label or '') < (b.label or '')
    end)
    return out
end

function CharTattoos.hasTattoo(tattoos, name, zone)
    if type(tattoos) ~= 'table' then return false end
    for _, t in ipairs(tattoos) do
        if t.name == name and t.zone == zone then return true end
    end
    return false
end

function CharTattoos.ensureList(skin)
    if not skin.tattoos or type(skin.tattoos) ~= 'table' then
        skin.tattoos = {}
    end
    return skin.tattoos
end

function CharTattoos.toggle(skin, name, zone)
    if not skin or not name or not zone then return skin and skin.tattoos or {} end
    local tattoos = CharTattoos.ensureList(skin)
    for i = #tattoos, 1, -1 do
        if tattoos[i].name == name and tattoos[i].zone == zone then
            table.remove(tattoos, i)
            return tattoos
        end
    end
    tattoos[#tattoos + 1] = { name = name, zone = zone }
    return tattoos
end

function CharTattoos.clearZone(skin, zone)
    if not skin or not zone then return skin and skin.tattoos or {} end
    local tattoos = CharTattoos.ensureList(skin)
    for i = #tattoos, 1, -1 do
        if tattoos[i].zone == zone then
            table.remove(tattoos, i)
        end
    end
    return tattoos
end

function CharTattoos.labelFor(name, zone)
    local list = catalog()[zone]
    if not list then return name end
    for _, t in ipairs(list) do
        if t.name == name then return t.label or name end
    end
    return name
end

exports('ApplyTattoos', function(ped, tattoos, gender)
    CharTattoos.applyToPed(ped, tattoos, gender)
end)
