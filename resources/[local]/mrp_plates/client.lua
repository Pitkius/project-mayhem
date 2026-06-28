local textureReady = false
local patternApplied = false
local appliedPlates = {}

local function applyPlateTextPatterns()
    if patternApplied then return end
    local pattern = Config.PlatePattern or ' 111 AAA'
    for i = 0, 5 do
        SetDefaultVehicleNumberPlateTextPattern(i, pattern)
    end
    patternApplied = true
end

local function replacePlateTextures()
    if textureReady then return true end

    local dict = Config.TextureDict or 'mrp_plates_txd'
    local tex = Config.PlateTexture or 'plate01'
    local file = Config.PlateTextureFile or 'textures/plate01.png'

    if not LoadResourceFile(GetCurrentResourceName(), file) then
        print('^1[mrp_plates] Missing textures/plate01.png^7')
        return false
    end

    local txd = CreateRuntimeTxd(dict)
    CreateRuntimeTextureFromImage(txd, tex, file)

    RequestStreamedTextureDict(dict, false)
    local tries = 0
    while not HasStreamedTextureDictLoaded(dict) and tries < 100 do
        Wait(0)
        tries = tries + 1
    end

    local vanillaTex = 'plate02'
    RemoveReplaceTexture('vehshare', vanillaTex)
    AddReplaceTexture('vehshare', vanillaTex, dict, tex)

    textureReady = true
    print('^2[mrp_plates] MRP violet plate texture loaded^7')
    return true
end

local function formatAndSetPlateText(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    local raw = GetVehicleNumberPlateText(vehicle)
    if not raw or raw == '' then return end

    local norm = MRPPlates.Normalize(raw)
    if not MRPPlates.IsValid(norm) then return end

    local render = MRPPlates.FormatForRender(norm, Config.PlateTextPadLeft)
    if render ~= raw then
        SetVehicleNumberPlateText(vehicle, render)
    end
    appliedPlates[vehicle] = norm
end

local function applyPlateStyle(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    if GetEntityType(vehicle) ~= 2 then return end

    local idx = tonumber(Config.DefaultPlateIndex) or 0
    SetVehicleNumberPlateTextIndex(vehicle, idx)
    formatAndSetPlateText(vehicle)
end

exports('ApplyPlateStyle', applyPlateStyle)

CreateThread(function()
    applyPlateTextPatterns()
    replacePlateTextures()

    while true do
        local veh = GetVehiclePedIsIn(PlayerPedId(), false)
        if veh ~= 0 then
            applyPlateStyle(veh)
        end
        Wait(1500)
    end
end)

AddEventHandler('gameEventTriggered', function(name, data)
    if name ~= 'CEventNetworkEntityCreated' then return end
    local entity = data[1]
    if not entity or entity == 0 or GetEntityType(entity) ~= 2 then return end
    CreateThread(function()
        Wait(50)
        if DoesEntityExist(entity) then
            applyPlateStyle(entity)
        end
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    RemoveReplaceTexture('vehshare', 'plate02')
    appliedPlates = {}
end)
