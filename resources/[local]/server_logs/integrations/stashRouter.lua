-- Sandėlių / namų / frakcijų inventoriaus logų maršrutizavimas
StashRouter = StashRouter or {}

local function itemLabel(itemName)
    if not itemName then return '?' end
    if GetResourceState('qb-core') == 'started' then
        local QBCore = exports['qb-core']:GetCoreObject()
        local info = QBCore.Shared.Items[itemName:lower()]
        if info and info.label then return info.label end
    end
    return itemName
end

local function isPlayerInv(id)
    return id == 'player'
end

local function isIgnoredInv(id)
    if not id or id == '' then return true end
    if isPlayerInv(id) then return false end
    if id:find('otherplayer%-') then return true end
    if id:find('shop%-') then return true end
    if id:find('^drop%-') then return true end
    return false
end

--- @return string|nil logType
--- @return string|nil stashLabel
function StashRouter.Classify(inventoryId)
    if not inventoryId or isIgnoredInv(inventoryId) or isPlayerInv(inventoryId) then
        return nil, nil
    end

    local id = inventoryId:lower()

    if id:find('^ltpd_') then
        return 'police', 'Policijos sandėlis'
    end
    if id:find('^fivempro_ems_') then
        return 'ems', 'Medikų sandėlis'
    end
    if id:find('^fivempro_mechanic') then
        return 'mechanic', 'Mechanikų sandėlis'
    end
    if id:find('^fivempro_taxi') then
        return 'taxi', 'Taksistų sandėlis'
    end
    if id:find('^property_') then
        return 'warehouse', 'Civiliai namai'
    end
    if id:find('^motel_public_') then
        return 'warehouse', 'Viešas sandėlis'
    end
    if id:find('^trunk%-') then
        return 'vehicle', 'Bagažinė'
    end
    if id:find('^glovebox%-') then
        return 'vehicle', 'Bardachė'
    end

    return nil, nil
end

local function sendStashLog(src, logType, action, stashId, stashLabel, itemName, amount)
    local label = itemLabel(itemName)
    local actionLt = action == 'deposit' and 'Įdėjo' or 'Išėmė'
    local title = action == 'deposit' and 'Sandėlis — įdėta' or 'Sandėlis — išimta'

    local fields = {
        { name = 'Veiksmas', value = actionLt, inline = true },
        { name = 'Sandėlis', value = ('`%s`'):format(stashId or '?'), inline = true },
        { name = 'Kiekis', value = tostring(amount or 1), inline = true },
        { name = 'Daiktas', value = ('%s (`%s`)'):format(label, itemName or '?'), inline = false },
    }

    if stashLabel then
        table.insert(fields, 1, { name = 'Tipas', value = stashLabel, inline = true })
    end

    if Identifiers and Identifiers.GetCoordsField then
        fields[#fields + 1] = Identifiers.GetCoordsField(src)
    end

    SendLog(logType, title, ('**%s** x%s'):format(label, amount or 1), fields, src)
end

function StashRouter.ProcessTransfer(src, fromInventory, toInventory, itemName, amount)
    if not src or src <= 0 or not itemName or not amount or amount <= 0 then return end
    if isIgnoredInv(fromInventory) and isIgnoredInv(toInventory) then return end

    local fromType, fromLabel = StashRouter.Classify(fromInventory)
    local toType, toLabel = StashRouter.Classify(toInventory)

    if isPlayerInv(fromInventory) and toType then
        sendStashLog(src, toType, 'deposit', toInventory, toLabel, itemName, amount)
        return
    end

    if isPlayerInv(toInventory) and fromType then
        sendStashLog(src, fromType, 'withdraw', fromInventory, fromLabel, itemName, amount)
        return
    end

    if fromType and toType then
        sendStashLog(src, fromType, 'withdraw', fromInventory, fromLabel, itemName, amount)
        sendStashLog(src, toType, 'deposit', toInventory, toLabel, itemName, amount)
    end
end

AddEventHandler('server_logs:inventoryTransfer', function(src, fromInventory, toInventory, itemName, amount)
    StashRouter.ProcessTransfer(src, fromInventory, toInventory, itemName, amount)
end)
