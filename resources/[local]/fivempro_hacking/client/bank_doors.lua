--- Banko seifo durų atidarymas po hack / drill (Fleeca + Pacific)
local vaultDoors = (Config.Robberies and Config.Robberies.BankVaultDoors) or {}

local function openVaultDoor(locId, fallbackCoords)
    local cfg = vaultDoors[locId]
    if not cfg then return end

    local model = type(cfg.model) == 'string' and joaat(cfg.model) or cfg.model
    local c = cfg.coords or fallbackCoords
    if not c or not model then return end

    local radius = cfg.radius or 8.0
    local obj = GetClosestObjectOfType(c.x, c.y, c.z, radius, model, false, false, false)
    if obj == 0 and fallbackCoords then
        obj = GetClosestObjectOfType(fallbackCoords.x, fallbackCoords.y, fallbackCoords.z, 12.0, model, false, false, false)
    end

    local doorHash = joaat(('vault_%s'):format(locId))
    pcall(function()
        AddDoorToSystem(doorHash, model, c.x, c.y, c.z, false, false, false)
        DoorSystemSetDoorState(doorHash, 0, false, false)
        DoorSystemSetOpenRatio(doorHash, cfg.openRatio or 1.0, false, false)
    end)

    if obj ~= 0 then
        FreezeEntityPosition(obj, false)
        local base = cfg.heading or GetEntityHeading(obj)
        local openHeading = cfg.openHeading or (base + (cfg.openDelta or -90.0))
        SetEntityHeading(obj, openHeading)
    end
end

function OpenBankVaultAfterHack(locId, coords)
    openVaultDoor(locId, coords)
end

function OpenBankVaultAfterDrill(locId, coords)
    openVaultDoor(locId, coords)
    PlaySoundFromCoord(-1, 'Vault_Door_Unlock', coords.x, coords.y, coords.z, 'dlc_heist_fleeca_bank_door_sounds', false, 0, false)
end

exports('OpenBankVaultAfterHack', OpenBankVaultAfterHack)
exports('OpenBankVaultAfterDrill', OpenBankVaultAfterDrill)
