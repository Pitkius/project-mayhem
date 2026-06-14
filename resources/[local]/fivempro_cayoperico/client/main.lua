local islandLoaded = false

local IPLS = {
    'h4_islandairstrip',
    'h4_islandairstrip_props',
    'h4_islandairstrip_propsb',
    'h4_islandxparty',
    'h4_islandxparty_props',
    'h4_islandxparty_props_2',
    'h4_islandx_mask',
    'h4_islandxdock',
    'h4_islandxdock_props',
    'h4_islandxdock_props_2',
    'h4_islandxtower',
    'h4_islandxtower_veg',
    'h4_islandx_maindock',
    'h4_islandx_maindock_props',
    'h4_islandx_maindock_props_2',
    'h4_IslandX_Mansion',
    'h4_islandx_mansion_props',
    'h4_islandx_mansion_b',
    'h4_islandxbarrack_props',
    'h4_islandxcanal_props',
    'h4_islandx_checkpoint',
    'h4_islandx_checkpoint_props',
    'h4_islandx_Mansion_Office',
    'h4_islandx_Mansion_LockUp_01',
    'h4_islandx_Mansion_LockUp_02',
    'h4_islandx_Mansion_LockUp_03',
    'h4_islandairstrip_hangar_props',
    'h4_islandx_mechanical',
    'h4_islandx_mechanical_props',
    'h4_islandx_garage',
    'h4_islandx_garage_props',
    'h4_islandx_guardhouse',
    'h4_islandx_guardhouse_props',
    'h4_islandx_hangar_props',
    'h4_islandx_hangar_props_2',
    'h4_islandx_mansion_office',
    'h4_islandx_mansion_vault',
    'h4_islandx_mansion_vault_props',
    'h4_mansion_remains',
    'h4_mansion_remains_props',
    'h4_mansion_gate_closed',
    'h4_Underwater_Gate_Closed',
    'h4_islandairstrip_doorsclosed',
    'h4_ne_ipl_00',
    'h4_ne_ipl_01',
    'h4_ne_ipl_02',
    'h4_ne_ipl_03',
    'h4_ne_ipl_04',
    'h4_ne_ipl_05',
    'h4_ne_ipl_06',
    'h4_ne_ipl_07',
    'h4_ne_ipl_08',
    'h4_ne_ipl_09',
    'h4_nw_ipl_00',
    'h4_nw_ipl_01',
    'h4_nw_ipl_02',
    'h4_nw_ipl_03',
    'h4_nw_ipl_04',
    'h4_nw_ipl_05',
    'h4_nw_ipl_06',
    'h4_nw_ipl_07',
    'h4_nw_ipl_08',
    'h4_nw_ipl_09',
    'h4_se_ipl_00',
    'h4_se_ipl_01',
    'h4_se_ipl_02',
    'h4_se_ipl_03',
    'h4_se_ipl_04',
    'h4_se_ipl_05',
    'h4_se_ipl_06',
    'h4_se_ipl_07',
    'h4_se_ipl_08',
    'h4_se_ipl_09',
    'h4_sw_ipl_00',
    'h4_sw_ipl_01',
    'h4_sw_ipl_02',
    'h4_sw_ipl_03',
    'h4_sw_ipl_04',
    'h4_sw_ipl_05',
    'h4_sw_ipl_06',
    'h4_sw_ipl_07',
    'h4_sw_ipl_08',
    'h4_sw_ipl_09',
}

local function enableIslandMap()
    SetIslandHopperEnabled('HeistIsland', true)
    SetToggleMinimapHeistIsland(true)
    pcall(function()
        Citizen.InvokeNative(0x9A9D1BA639675CF1, 'HeistIsland', true)
    end)
    pcall(function()
        Citizen.InvokeNative(0x5E1460624D194A38, true)
    end)
    pcall(function()
        Citizen.InvokeNative(0xF74B1FFA4A15FBEA, true)
    end)
end

local function requestCollisionAt(x, y, z)
    RequestCollisionAtCoord(x, y, z)
    for i = 0, 4 do
        RequestCollisionAtCoord(x, y, z + (i * 12.0))
    end
end

local function loadIsland()
    if islandLoaded then return end
    for _, ipl in ipairs(IPLS) do
        RequestIpl(ipl)
    end
    enableIslandMap()
    islandLoaded = true
end

local function createIslandBlip()
    local cfg = Config.IslandBlip
    if not cfg or not cfg.enabled or not cfg.coords then return end
    local c = cfg.coords
    local blip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(blip, cfg.sprite or 836)
    SetBlipColour(blip, cfg.color or 2)
    SetBlipScale(blip, cfg.scale or 0.95)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(cfg.label or 'Cayo Perico')
    EndTextCommandSetBlipName(blip)
    if GetResourceState('fivempro_fonts') == 'started' then
        exports['fivempro_fonts']:SetBlipName(blip, cfg.label or 'Cayo Perico')
    end
end

CreateThread(function()
    Wait(500)
    loadIsland()
    createIslandBlip()
end)

--- Minimapas saloje + collision streaming
CreateThread(function()
    local center = Config.IslandCenter or vector3(4840.57, -5174.42, 2.0)
    local radius = Config.IslandLoadRadius or 2400.0
    while true do
        local sleep = 800
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local dist = #(coords - center)
        if dist <= radius then
            sleep = 0
            SetRadarAsExteriorThisFrame()
            SetRadarAsInteriorThisFrame(joaat('h4_fake_islandx'), 4700.0, -5145.0, 0, 0)
            requestCollisionAt(coords.x, coords.y, coords.z)
            for _, zone in ipairs(Config.StreamZones or {}) do
                if #(coords - zone) < 220.0 then
                    requestCollisionAt(zone.x, zone.y, zone.z)
                end
            end
        end
        Wait(sleep)
    end
end)

exports('RequestIslandCollision', function(x, y, z)
    loadIsland()
    requestCollisionAt(x, y, z)
end)

exports('IsOnCayoIsland', function(coords)
    coords = coords or GetEntityCoords(PlayerPedId())
    local center = Config.IslandCenter or vector3(4840.57, -5174.42, 2.0)
    return #(coords - center) <= (Config.IslandLoadRadius or 2400.0)
end)
