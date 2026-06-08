CharAppearance = CharAppearance or {}

local currentSkin = nil
local previewPed = 0

local function deepCopy(t)
    local o = {}
    for k, v in pairs(t) do
        if type(v) == 'table' then o[k] = deepCopy(v) else o[k] = v end
    end
    return o
end

function CharAppearance.defaultSkin(gender)
    local female = gender == 1 or gender == 'female'
    local s = {
        face = { item = female and 21 or 0, texture = 0 },
        face2 = { item = female and 25 or 0, texture = 0 },
        facemix = { shapeMix = 0.5, skinMix = 0.5 },
        hair = { item = 0, texture = 0 },
        eyebrows = { item = 0, texture = 0 },
        beard = { item = female and -1 or 0, texture = 0 },
        blush = { item = -1, texture = 0 },
        lipstick = { item = female and 0 or -1, texture = 0 },
        makeup = { item = -1, texture = 0 },
        ageing = { item = -1, texture = 0 },
        moles = { item = 0, texture = 0 },
        eye_color = { item = 0, texture = 0 },
        arms = { item = 15, texture = 0 },
        ['t-shirt'] = { item = 15, texture = 0 },
        torso2 = { item = 15, texture = 0 },
        vest = { item = 0, texture = 0 },
        bag = { item = 0, texture = 0 },
        shoes = { item = 1, texture = 0 },
        mask = { item = 0, texture = 0 },
        hat = { item = -1, texture = 0 },
        glass = { item = -1, texture = 0 },
        ear = { item = -1, texture = 0 },
        watch = { item = -1, texture = 0 },
        bracelet = { item = -1, texture = 0 },
        accessory = { item = 0, texture = 0 },
        decals = { item = 0, texture = 0 },
        pants = { item = 0, texture = 0 },
    }
    for i = 0, 19 do
        local key = ({
            [0] = 'nose_0', [1] = 'nose_1', [2] = 'nose_2', [3] = 'nose_3', [4] = 'nose_4', [5] = 'nose_5',
            [6] = 'eyebrown_high', [7] = 'eyebrown_forward', [8] = 'cheek_1', [9] = 'cheek_2',
            [10] = 'cheek_3', [11] = 'eye_opening', [12] = 'lips_thickness', [13] = 'jaw_bone_width',
            [14] = 'jaw_bone_back_lenght', [15] = 'chimp_bone_lowering', [16] = 'chimp_bone_lenght',
            [17] = 'chimp_bone_width', [18] = 'chimp_hole', [19] = 'neck_thikness',
        })[i]
        if key then s[key] = { item = 0.0, texture = 0 } end
    end
    return s
end

function CharAppearance.getSkin()
    return currentSkin
end

function CharAppearance.setPreviewPed(ped)
    previewPed = ped
end

function CharAppearance.applyToPed(ped, skin)
    if not ped or ped == 0 or not skin then return end
    TriggerEvent('qb-clothing:client:loadPlayerClothing', skin, ped)
end

function CharAppearance.setGender(gender)
    local female = gender == 1 or gender == 'female'
    currentSkin = CharAppearance.defaultSkin(female and 1 or 0)
    local model = female and `mp_f_freemode_01` or `mp_m_freemode_01`
    return model, currentSkin
end

function CharAppearance.mergePatch(patch)
    if not currentSkin or type(patch) ~= 'table' then return end
    for k, v in pairs(patch) do
        if type(v) == 'table' and type(currentSkin[k]) == 'table' then
            for fk, fv in pairs(v) do
                currentSkin[k][fk] = fv
            end
        else
            currentSkin[k] = v
        end
    end
end

function CharAppearance.applyPatch(patch)
    CharAppearance.mergePatch(patch)
    if previewPed and previewPed ~= 0 then
        CharAppearance.applyToPed(previewPed, currentSkin)
    end
end

local VARIATION_IDS = {
    mask = 1, arms = 3, pants = 4, bag = 5, shoes = 6, accessory = 7,
    ['t-shirt'] = 8, vest = 9, decals = 10, torso2 = 11,
}
local PROP_IDS = {
    hat = 0, glass = 1, ear = 2, watch = 6, bracelet = 7,
}

function CharAppearance.setComponent(skinKey, item, texture)
    if not currentSkin then return end
    if not currentSkin[skinKey] then
        currentSkin[skinKey] = { item = 0, texture = 0 }
    end
    currentSkin[skinKey].item = math.floor(item or 0)
    currentSkin[skinKey].texture = math.floor(texture or 0)
    if previewPed and previewPed ~= 0 then
        CharAppearance.applyToPed(previewPed, currentSkin)
    end
end

function CharAppearance.getClothingLimits(ped, items)
    ped = ped or previewPed
    local out = {}
    for _, cfg in ipairs(items or {}) do
        local maxItem = cfg.maxItem or 100
        local maxTex = cfg.maxTex or 15
        local minItem = cfg.propMin
        if ped and ped ~= 0 and DoesEntityExist(ped) then
            local varId = VARIATION_IDS[cfg.key]
            if varId then
                local n = GetNumberOfPedDrawableVariations(ped, varId)
                if n and n > 0 then maxItem = n - 1 end
                local cur = currentSkin and currentSkin[cfg.key] and currentSkin[cfg.key].item or 0
                if cur < 0 then cur = 0 end
                local texN = GetNumberOfPedTextureVariations(ped, varId, cur)
                if texN and texN > 0 then maxTex = texN - 1 end
            end
            local propId = PROP_IDS[cfg.key]
            if propId then
                local n = GetNumberOfPedPropDrawableVariations(ped, propId)
                if n and n > 0 then maxItem = n - 1 end
                local cur = currentSkin and currentSkin[cfg.key] and currentSkin[cfg.key].item or -1
                if cur < 0 then cur = 0 end
                local texN = GetNumberOfPedPropTextureVariations(ped, propId, cur)
                if texN and texN > 0 then maxTex = texN - 1 end
                if minItem == nil then minItem = -1 end
            end
        end
        out[#out + 1] = {
            key = cfg.key,
            label = cfg.label,
            maxItem = maxItem,
            maxTex = maxTex,
            minItem = minItem,
        }
    end
    return out
end

function CharAppearance.applyOutfit(outfitKey, gender)
    if not currentSkin then return end
    local g = (gender == 1 or gender == 'female') and 'female' or 'male'
    local o = Config.Outfits and Config.Outfits[g] and Config.Outfits[g][outfitKey]
    if not o then return end
    if o.torso2 then currentSkin.torso2.item = o.torso2 end
    if o.tshirt then currentSkin['t-shirt'].item = o.tshirt end
    if o.arms then currentSkin.arms.item = o.arms end
    if o.pants then currentSkin.pants.item = o.pants end
    if o.shoes then currentSkin.shoes.item = o.shoes end
    CharAppearance.applyToPed(previewPed, currentSkin)
end

function CharAppearance.randomize(gender)
    local female = gender == 1 or gender == 'female'
    currentSkin = CharAppearance.defaultSkin(female and 1 or 0)
    local pf = Config.ParentFaces or {}
    local r = pf.male or { min = 0, max = 45 }
    currentSkin.face.item = math.random(r.min, r.max)
    currentSkin.face2.item = math.random(r.min, r.max)
    currentSkin.facemix.shapeMix = math.random() * 0.85 + 0.1
    currentSkin.facemix.skinMix = math.random() * 0.85 + 0.1
    currentSkin.hair.item = math.random(0, female and 80 or 75)
    currentSkin.hair.texture = math.random(0, 63)
    currentSkin.eye_color.item = math.random(0, 5)
    for _, key in ipairs({
        'nose_0', 'nose_1', 'nose_2', 'cheek_1', 'cheek_2', 'jaw_bone_width', 'lips_thickness', 'eye_opening',
    }) do
        if currentSkin[key] then
            currentSkin[key].item = (math.random() - 0.5) * 1.6
        end
    end
    CharAppearance.applyToPed(previewPed, currentSkin)
    return currentSkin
end

function CharAppearance.loadFromJson(skinJson)
    if not skinJson then return end
    local ok, data = pcall(json.decode, skinJson)
    if ok and type(data) == 'table' then
        currentSkin = data
        CharAppearance.applyToPed(previewPed, currentSkin)
    end
end

function CharAppearance.init(gender)
    local model, skin = CharAppearance.setGender(gender or 0)
    currentSkin = skin
    return model, skin
end

function CharAppearance.exportForSave()
    return deepCopy(currentSkin)
end

function CharAppearance.modelHash(gender)
    local female = gender == 1 or gender == 'female'
    return female and `mp_f_freemode_01` or `mp_m_freemode_01`
end
