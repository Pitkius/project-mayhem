local QBCore = exports['qb-core']:GetCoreObject()

local COMMAND_DEFS = {
    { 'mask', 'Nusivilkti/užsidėti kaukę' },
    { 'kauke', 'Nusivilkti/užsidėti kaukę' },
    { 'hat', 'Nusivilkti/užsidėti kepurę' },
    { 'kepure', 'Nusivilkti/užsidėti kepurę' },
    { 'glasses', 'Nusivilkti/užsidėti akinius' },
    { 'akiniai', 'Nusivilkti/užsidėti akinius' },
    { 'ak', 'Nusivilkti/užsidėti akinius' },
    { 'ear', 'Nusivilkti/užsidėti ausinukus' },
    { 'ausinukai', 'Nusivilkti/užsidėti ausinukus' },
    { 'watch', 'Nusivilkti/užsidėti laikrodį' },
    { 'laikrodis', 'Nusivilkti/užsidėti laikrodį' },
    { 'bracelet', 'Nusivilkti/užsidėti apyrankę' },
    { 'apyranke', 'Nusivilkti/užsidėti apyrankę' },
    { 'chain', 'Nusivilkti/užsidėti kaklaraištį' },
    { 'kaklaruoste', 'Nusivilkti/užsidėti kaklaraištį' },
    { 'shirt', 'Nusivilkti/užsidėti marškinėlius' },
    { 'marskiniai', 'Nusivilkti/užsidėti marškinėlius' },
    { 'mar', 'Nusivilkti/užsidėti marškinėlius' },
    { 'top', 'Nusivilkti/užsidėti striukę / viršų' },
    { 'striuke', 'Nusivilkti/užsidėti striukę / viršų' },
    { 'virsus', 'Nusivilkti/užsidėti striukę / viršų' },
    { 'vest', 'Nusivilkti/užsidėti liemenę' },
    { 'liemene', 'Nusivilkti/užsidėti liemenę' },
    { 'gloves', 'Nusivilkti/užsidėti pirštines' },
    { 'pirstines', 'Nusivilkti/užsidėti pirštines' },
    { 'pants', 'Nusivilkti/užsidėti kelnes' },
    { 'kelnes', 'Nusivilkti/užsidėti kelnes' },
    { 'shoes', 'Nusivilkti/užsidėti batus' },
    { 'batai', 'Nusivilkti/užsidėti batus' },
    { 'bag', 'Nusivilkti/užsidėti kuprinę' },
    { 'kuprine', 'Nusivilkti/užsidėti kuprinę' },
    { 'decals', 'Nusivilkti/užsidėti ženklelius' },
    { 'zenkleliai', 'Nusivilkti/užsidėti ženklelius' },
    { 'drabuziai', 'Atidaryti drabužių meniu (arba klavišas U)' },
}

for _, def in ipairs(COMMAND_DEFS) do
    local cmd, help = def[1], def[2]
    QBCore.Commands.Add(cmd, help, {}, false, function(source)
        if cmd == 'drabuziai' then
            TriggerClientEvent('fivempro_basics:client:openClothingMenu', source)
            return
        end
        TriggerClientEvent('fivempro_basics:client:toggleClothingByCommand', source, cmd)
    end, 'user')
end
