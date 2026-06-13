CreateThread(function()
    RequestIpl('gabz_biker_milo_')
    RequestIpl('lost_garage_milo_')

    local coords = vector3(994.4787, -122.9949, 73.11467)
    local interiorID = 0

    for _ = 1, 100 do
        interiorID = GetInteriorAtCoords(coords.x, coords.y, coords.z)
        if interiorID ~= 0 and IsValidInterior(interiorID) then
            break
        end
        Wait(100)
    end

    if interiorID == 0 or not IsValidInterior(interiorID) then
        print('^1[cfx-gabz-lost]^7 Clubhouse interjeras neužsikrovė – patikrink ytyp ir IPL.')
        return
    end

    PinInteriorInMemory(interiorID)

    EnableInteriorProp(interiorID, 'walls_02')
    SetInteriorPropColor(interiorID, 'walls_02', 8)
    EnableInteriorProp(interiorID, 'Furnishings_02')
    SetInteriorPropColor(interiorID, 'Furnishings_02', 8)
    EnableInteriorProp(interiorID, 'decorative_02')
    EnableInteriorProp(interiorID, 'mural_03')
    EnableInteriorProp(interiorID, 'lower_walls_default')
    SetInteriorPropColor(interiorID, 'lower_walls_default', 8)
    EnableInteriorProp(interiorID, 'mod_booth')
    EnableInteriorProp(interiorID, 'gun_locker')
    EnableInteriorProp(interiorID, 'cash_small')
    EnableInteriorProp(interiorID, 'id_small')
    EnableInteriorProp(interiorID, 'weed_small')

    RefreshInterior(interiorID)
end)
