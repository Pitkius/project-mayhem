FPMFurniture = FPMFurniture or {}

function FPMFurniture.ItemName(key)
    return ('furn_%s'):format(key)
end

function FPMFurniture.GetEntry(key)
    return Config.Catalog and Config.Catalog[key] or nil
end

function FPMFurniture.GetCap(propertyClass)
    local caps = Config.FurnitureCaps or {}
    return caps[propertyClass or 'standard'] or 20
end

function FPMFurniture.BuildShopItems()
    local items = {}
    for key, entry in pairs(Config.Catalog or {}) do
        items[#items + 1] = {
            name = FPMFurniture.ItemName(key),
            price = entry.price or 100,
            amount = 50,
            info = {},
            type = 'item',
            slot = #items + 1,
        }
    end
    table.sort(items, function(a, b) return a.name < b.name end)
    for i, it in ipairs(items) do
        it.slot = i
    end
    return items
end
