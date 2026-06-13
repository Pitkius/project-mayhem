local QBCore = exports['qb-core']:GetCoreObject()

RegisterNetEvent('fivempro_motel:client:openPublicStash', function()
    TriggerServerEvent('fivempro_motel:server:openPublicStash')
end)

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do
        Wait(300)
    end

    local st = Config.PublicStash
    if not st or not st.coords then return end

    exports['qb-target']:AddBoxZone('fivempro_motel_public_stash', st.coords, st.length or 1.6, st.width or 1.6, {
        name = 'fivempro_motel_public_stash',
        heading = st.heading or 0.0,
        debugPoly = false,
        minZ = st.coords.z - 1.2,
        maxZ = st.coords.z + 2.0,
    }, {
        options = {
            {
                type = 'client',
                event = 'fivempro_motel:client:openPublicStash',
                icon = 'fas fa-box-open',
                label = st.label or 'Motelio sandėlis',
            },
        },
        distance = Config.TargetDistance or 2.5,
    })
end)
