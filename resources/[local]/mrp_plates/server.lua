local excludedLetters = {}

local function buildExcludedLetters()
    excludedLetters = {}
    for _, ch in ipairs(Config.ExcludedLetters or { 'I', 'O', 'Q' }) do
        excludedLetters[string.upper(tostring(ch))] = true
    end
end

buildExcludedLetters()

local function randomDigit()
    return tostring(math.random(0, 9))
end

local function randomLetter()
    for _ = 1, 12 do
        local ch = string.char(math.random(65, 90))
        if not excludedLetters[ch] then
            return ch
        end
    end
    return 'Z'
end

local function generatePlateText()
    return randomDigit() .. randomDigit() .. randomDigit() .. ' ' .. randomLetter() .. randomLetter() .. randomLetter()
end

local function isPlateFree(plate)
    local row = MySQL.scalar.await('SELECT plate FROM player_vehicles WHERE plate = ? LIMIT 1', { plate })
    return not row
end

local function getUniquePlate()
    for _ = 1, 40 do
        local plate = MRPPlates.Normalize(generatePlateText())
        if MRPPlates.IsValid(plate) and isPlateFree(plate) then
            return plate
        end
    end
    return MRPPlates.Normalize(generatePlateText())
end

local function buildVehicleProps(hash, plate, colorIdx)
    local props = {
        model = hash,
        plate = MRPPlates.Normalize(plate),
        plateIndex = tonumber(Config.DefaultPlateIndex) or 0,
    }
    local c = tonumber(colorIdx)
    if c then
        props.color1 = c
        props.color2 = c
        props.pearlescentColor = 0
        props.wheelColor = 0
    end
    return props
end

exports('GenerateUnique', getUniquePlate)
exports('GenerateText', function()
    return MRPPlates.Normalize(generatePlateText())
end)
exports('Normalize', function(plate)
    return MRPPlates.Normalize(plate)
end)
exports('FormatForRender', function(plate)
    return MRPPlates.FormatForRender(plate, Config.PlateTextPadLeft)
end)
exports('BuildVehicleProps', buildVehicleProps)
exports('GetDefaultPlateIndex', function()
    return tonumber(Config.DefaultPlateIndex) or 0
end)
