local blocked = {
    [`WEAPON_RPG`] = true,
    [`WEAPON_MINIGUN`] = true,
    [`WEAPON_GRENADELAUNCHER`] = true,
    [`WEAPON_HOMINGLAUNCHER`] = true,
    [`WEAPON_RAILGUN`] = true,
    [`WEAPON_GRENADE`] = true,
    [`WEAPON_STICKYBOMB`] = true,
    [`WEAPON_MOLOTOV`] = true,
    [`WEAPON_PIPEBOMB`] = true
}

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local currentWeapon = GetSelectedPedWeapon(ped)
        if blocked[currentWeapon] then
            RemoveWeaponFromPed(ped, currentWeapon)
            SetCurrentPedWeapon(ped, `WEAPON_UNARMED`, true)
            BeginTextCommandThefeedPost('STRING')
            AddTextComponentSubstringPlayerName('Sis ginklas siame serveryje uzdraustas.')
            EndTextCommandThefeedPostTicker(false, false)
        end
        Wait(300)
    end
end)
