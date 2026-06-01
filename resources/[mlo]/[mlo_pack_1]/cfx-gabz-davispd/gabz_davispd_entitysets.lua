--- Davis PD interjero kambarių entity set'ai (turi būti šiame resurse, ne mapdata – stream dar neįkeltas).
local IPL = 'gabz_davispd_milo_'
local INTERIOR_COORDS = vector3(371.0543, -1600.378, 34.73263)
local REAPPLY_RADIUS = 160.0

local ENTITY_SETS = {
    'davispd_room01_rainhall_es',
    'davispd_room02_reception_es',
    'davispd_room03_captainoffice_es',
    'davispd_room04_officeleft_es',
    'davispd_room05_officeright_es',
    'davispd_room06_archives_es',
    'davispd_room07_staircase_es',
    'davispd_room08_basementa_es',
    'davispd_room09_listening_es',
    'davispd_room10_interrogation_es',
    'davispd_room11_toilets_es',
    'davispd_room12_mugshot_es',
    'davispd_room13_basementb_es',
    'davispd_room14_armory_es',
    'davispd_room15_forensics_es',
    'davispd_room16_lockers_es',
    'davispd_room17_showerleft_es',
    'davispd_room18_showerright_es',
}

local applied = false

local function applyDavisPdInterior()
    RequestIpl(IPL)
    local interiorId = GetInteriorAtCoords(INTERIOR_COORDS.x, INTERIOR_COORDS.y, INTERIOR_COORDS.z)
    if not interiorId or interiorId == 0 or not IsValidInterior(interiorId) then
        return false
    end
    for i = 1, #ENTITY_SETS do
        EnableInteriorProp(interiorId, ENTITY_SETS[i])
    end
    RefreshInterior(interiorId)
    if PinInteriorInMemory then
        PinInteriorInMemory(interiorId)
    end
    applied = true
    return true
end

CreateThread(function()
    Wait(1500)
    local ok = false
    for _ = 1, 80 do
        if applyDavisPdInterior() then
            ok = true
            print('^5[GABZ]^7 Davis PD interior loaded.')
            break
        end
        Wait(500)
    end
    if not ok then
        print('^5[GABZ]^7 ^1Davis PD interior failed – patikrink ar `cfx-gabz-davispd` startuoja be klaidų.^7')
    end
end)

--- Jei interjeras išsikrauna ar žaidėjas prisijungia vėliau – pakartoti arti komisariato.
CreateThread(function()
    while true do
        local sleep = 4000
        local ped = PlayerPedId()
        if ped and ped ~= 0 then
            local p = GetEntityCoords(ped)
            if #(p - INTERIOR_COORDS) < REAPPLY_RADIUS then
                sleep = 1500
                if not applied or not IsValidInterior(GetInteriorAtCoords(INTERIOR_COORDS.x, INTERIOR_COORDS.y, INTERIOR_COORDS.z)) then
                    applied = false
                    if applyDavisPdInterior() then
                        print('^5[GABZ]^7 Davis PD interior re-applied (proximity).')
                    end
                end
            end
        end
        Wait(sleep)
    end
end)
