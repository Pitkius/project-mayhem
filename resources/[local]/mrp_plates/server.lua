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

local function normalizePlate(plate)
    plate = tostring(plate or ''):upper()
    plate = plate:gsub('%s+', ' ')
    return plate:match('^%s*(.-)%s*$') or plate
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
        local plate = normalizePlate(generatePlateText())
        if isPlateFree(plate) then
            return plate
        end
    end
    return normalizePlate(generatePlateText())
end

local function buildVehicleProps(hash, plate, colorIdx)
    local props = {
        model = hash,
        plate = plate,
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
exports('GenerateText', generatePlateText)
exports('Normalize', normalizePlate)
exports('BuildVehicleProps', buildVehicleProps)
exports('GetDefaultPlateIndex', function()
    return tonumber(Config.DefaultPlateIndex) or 0
end)
