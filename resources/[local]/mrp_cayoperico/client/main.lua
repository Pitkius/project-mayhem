local islandIplsLoaded = false
local islandMapActive = false
local islandBlip = nil

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

local function islandCenter()
    return Config.IslandCenter or vector3(4840.57, -5174.42, 2.0)
end

local function distanceToIsland(coords)
    return #(coords - islandCenter())
end

local function setIslandMapEnabled(enabled)
    if islandMapActive == enabled then return end
    islandMapActive = enabled

    SetIslandHopperEnabled('HeistIsland', enabled)
    SetToggleMinimapHeistIsland(enabled)
    pcall(function()
        Citizen.InvokeNative(0x9A9D1BA639675CF1, 'HeistIsland', enabled)
    end)
    pcall(function()
        Citizen.InvokeNative(0x5E1460624D194A38, enabled)
    end)
    pcall(function()
        Citizen.InvokeNative(0xF74B1FFA4A15FBEA, enabled)
    end)
end

local function removeAllIslandIpls()
    for _, ipl in ipairs(IPLS) do
        RemoveIpl(ipl)
    end
end

local function requestCollisionAt(x, y, z)
    RequestCollisionAtCoord(x, y, z)
    for i = 0, 4 do
        RequestCollisionAtCoord(x, y, z + (i * 12.0))
    end
end

local function notifyIslandState(loaded)
    TriggerEvent('mrp_cayoperico:client:islandState', loaded)
end

local function createIslandBlip()
    if islandBlip and DoesBlipExist(islandBlip) then return end
    local cfg = Config.IslandBlip
    if not cfg or not cfg.enabled or not cfg.coords then return end
    local c = cfg.coords
    islandBlip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(islandBlip, cfg.sprite or 836)
    SetBlipColour(islandBlip, cfg.color or 2)
    SetBlipScale(islandBlip, cfg.scale or 0.95)
    SetBlipAsShortRange(islandBlip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(cfg.label or 'Cayo Perico')
    EndTextCommandSetBlipName(islandBlip)
    if GetResourceState('mrp_fonts') == 'started' then
        exports['mrp_fonts']:SetBlipName(islandBlip, cfg.label or 'Cayo Perico')
    end
end

local function removeIslandBlip()
    if islandBlip and DoesBlipExist(islandBlip) then
        RemoveBlip(islandBlip)
    end
    islandBlip = nil
end

--- Tik IPL / pasaulio mesh (be HeistIsland pause žemėlapio)
local function loadIslandIpls()
    if islandIplsLoaded then return end
    for _, ipl in ipairs(IPLS) do
        RequestIpl(ipl)
    end
    islandIplsLoaded = true
    createIslandBlip()
    notifyIslandState(true)
end

local function unloadIslandIpls()
    if not islandIplsLoaded then
        setIslandMapEnabled(false)
        return
    end
    setIslandMapEnabled(false)
    removeIslandBlip()
    removeAllIslandIpls()
    islandIplsLoaded = false
    notifyIslandState(false)
end

--- Pradžioje — tik LS žemėlapis, jokio Cayo
CreateThread(function()
    Wait(250)
    setIslandMapEnabled(false)
    removeAllIslandIpls()
end)

--- IPL + blipai priartėjus; HeistIsland pause/minimap tik ant salos
CreateThread(function()
    local streamR = Config.StreamRadius or 2200.0
    local unloadR = Config.UnloadRadius or (streamR + 350.0)
    local mapR = Config.MapRadius or Config.MinimapRadius or Config.IslandLoadRadius or 1800.0

    while true do
        local sleep = 1000
        local coords = GetEntityCoords(PlayerPedId())
        local dist = distanceToIsland(coords)

        if dist <= streamR then
            loadIslandIpls()
            sleep = 450
        elseif dist > unloadR then
            unloadIslandIpls()
        end

        if islandIplsLoaded and dist <= mapR then
            setIslandMapEnabled(true)
            sleep = 0
            SetRadarAsExteriorThisFrame()
            SetRadarAsInteriorThisFrame(joaat('h4_fake_islandx'), 4700.0, -5145.0, 0, 0)
            requestCollisionAt(coords.x, coords.y, coords.z)
            for _, zone in ipairs(Config.StreamZones or {}) do
                if #(coords - zone) < 220.0 then
                    requestCollisionAt(zone.x, zone.y, zone.z)
                end
            end
        else
            setIslandMapEnabled(false)
        end

        Wait(sleep)
    end
end)

exports('RequestIslandCollision', function(x, y, z)
    local mapR = Config.MapRadius or Config.MinimapRadius or Config.IslandLoadRadius or 1800.0
    local dist = distanceToIsland(vector3(x, y, z))
    if dist <= (Config.StreamRadius or 2200.0) + 400.0 then
        loadIslandIpls()
    end
    requestCollisionAt(x, y, z)
    if dist <= mapR then
        setIslandMapEnabled(true)
    end
end)

exports('IsOnCayoIsland', function(coords)
    coords = coords or GetEntityCoords(PlayerPedId())
    local mapR = Config.MapRadius or Config.MinimapRadius or Config.IslandLoadRadius or 1800.0
    return distanceToIsland(coords) <= mapR
end)

exports('IsIslandLoaded', function()
    return islandIplsLoaded
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    unloadIslandIpls()
end)
