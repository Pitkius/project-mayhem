--- Papildomas klientinis sluoksnis: musketas nežaloja gyvūnų per daug ir rodo hint
CreateThread(function()
    while true do
        Wait(500)
        local ped = PlayerPedId()
        if GetSelectedPedWeapon(ped) == joaat('weapon_musket') then
            -- Sumažina žalą gyvūnams per SetWeaponDamageModifier jei reikia; pagrindinis cancel — server weaponDamageEvent
            SetPlayerWeaponDamageModifier(PlayerId(), 1.0)
        end
    end
end)

--- Blokuoja taikinį žaidėją lokaliai (papildoma apsauga)
AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end
    local victim = args[1]
    local attacker = args[2]
    if attacker ~= PlayerPedId() then return end
    if GetSelectedPedWeapon(attacker) ~= joaat('weapon_musket') then return end
    if victim and IsPedAPlayer(victim) then
        SetEntityHealth(victim, GetEntityMaxHealth(victim))
    end
end)
