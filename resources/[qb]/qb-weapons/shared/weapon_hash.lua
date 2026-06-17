WeaponHash = WeaponHash or {}

local nativeByInventory = {}

local function rebuildNativeMap()
    nativeByInventory = {}
    local map = Config.WeaponNativeHash
    if type(map) ~= 'table' then return end
    for invName, nativeName in pairs(map) do
        if type(invName) == 'string' and type(nativeName) == 'string' then
            nativeByInventory[string.lower(invName)] = string.lower(nativeName)
        end
    end
end

function WeaponHash.nativeName(inventoryName)
    rebuildNativeMap()
    local key = inventoryName and string.lower(tostring(inventoryName))
    if not key then return nil end
    return nativeByInventory[key] or key
end

function WeaponHash.resolve(inventoryName)
    return joaat(WeaponHash.nativeName(inventoryName))
end

function WeaponHash.inventoryNameFromNative(nativeHash)
    rebuildNativeMap()
    for invName, nativeName in pairs(nativeByInventory) do
        if joaat(nativeName) == nativeHash then
            return invName
        end
    end
    return nil
end

function WeaponHash.recoilLookupHash(pedWeaponHash)
    local inv = WeaponHash.inventoryNameFromNative(pedWeaponHash)
    if inv then
        return joaat(inv)
    end
    return pedWeaponHash
end
