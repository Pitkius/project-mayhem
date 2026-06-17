--- Ginklų žalos daugikliai + vienoda žala visoms kūno vietoms.
local applied = {}

local function resolveModifier(entry)
    return WeaponDamage.resolveModifier(entry)
end

CreateThread(function()
    while true do
        local balance = Config.WeaponDamageBalance
        if type(balance) ~= 'table' or next(balance) == nil then
            Wait(1000)
        else
            local ped = PlayerPedId()
            local current = GetSelectedPedWeapon(ped)
            local tickFast = false
            for weaponName, entry in pairs(balance) do
                local hash = joaat(weaponName)
                local mult = resolveModifier(entry)
                if mult and mult > 0 then
                    if current == hash then
                        tickFast = true
                        SetWeaponDamageModifier(hash, mult)
                        applied[hash] = mult
                    elseif applied[hash] then
                        applied[hash] = nil
                    end
                end
            end
            Wait(tickFast and 0 or 450)
        end
    end
end)

CreateThread(function()
    if Config.DisableCriticalHits == false then return end
    while true do
        local ped = PlayerPedId()
        if ped and ped ~= 0 then
            SetPedSuffersCriticalHits(ped, false)
        end
        Wait(0)
    end
end)
