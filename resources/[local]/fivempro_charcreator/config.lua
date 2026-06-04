Config = {}

Config.DefaultNumberOfCharacters = 5
Config.EnableDeleteButton = true

--- Scena (Gabz stiliaus interjeras – kaip qb-multicharacter)
Config.Interior = vector3(-763.28, 330.04, 199.49)
Config.HiddenCoords = vector4(-779.02, 326.18, 196.09, 91.0)
Config.PedCoords = vector4(-763.28, 330.04, 199.49, 177.79)
Config.DefaultSpawn = vector4(-1035.71, -2731.87, 12.86, 0.0)

Config.Cameras = {
    default = { offset = vector3(0.0, 2.35, 0.35), point = vector3(0.0, 0.0, 0.55), fov = 42.0 },
    face = { offset = vector3(0.0, 0.85, 0.68), point = vector3(0.0, 0.0, 0.68), fov = 28.0 },
    eyes = { offset = vector3(0.0, 0.55, 0.72), point = vector3(0.0, 0.0, 0.70), fov = 18.0 },
    hair = { offset = vector3(0.0, 0.95, 0.82), point = vector3(0.0, 0.0, 0.78), fov = 32.0 },
    body = { offset = vector3(0.0, 3.1, 0.15), point = vector3(0.0, 0.0, 0.35), fov = 48.0 },
    clothes = { offset = vector3(0.0, 2.8, 0.2), point = vector3(0.0, 0.0, 0.4), fov = 45.0 },
}

Config.Nationalities = {
    'Lietuvos', 'Latvijos', 'Lenkijos', 'Vokietijos', 'JAV', 'JK', 'Prancūzijos', 'Norvegijos', 'Švedijos', 'Kita',
}

Config.OriginCities = {
    'Vilnius', 'Kaunas', 'Klaipėda', 'Šiauliai', 'Panevėžys', 'Los Santos', 'Sandy Shores', 'Paleto Bay',
}

Config.BloodTypes = { 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', '0+', '0-' }

Config.EyeColors = {
    { id = 0, label = 'Ruda' },
    { id = 1, label = 'Mėlyna' },
    { id = 2, label = 'Žalia' },
    { id = 3, label = 'Pilka' },
    { id = 4, label = 'Juoda' },
    { id = 5, label = 'Hazel' },
}

Config.VoicePresets = {
    { id = 'male_mature', label = 'Vyriškas (brandus)' },
    { id = 'male_young', label = 'Vyriškas (jaunas)' },
    { id = 'female_mature', label = 'Moteriškas (brandi)' },
    { id = 'female_young', label = 'Moteriškas (jauna)' },
}

--- Pradinė apranga (komponentai freemode)
Config.Outfits = {
    male = {
        casual = { torso2 = 15, tshirt = 15, arms = 15, pants = 1, shoes = 1 },
        street = { torso2 = 237, tshirt = 15, arms = 85, pants = 98, shoes = 68 },
        business = { torso2 = 4, tshirt = 31, arms = 4, pants = 10, shoes = 10 },
        sport = { torso2 = 5, tshirt = 15, arms = 5, pants = 5, shoes = 9 },
    },
    female = {
        casual = { torso2 = 18, tshirt = 14, arms = 15, pants = 1, shoes = 1 },
        street = { torso2 = 226, tshirt = 14, arms = 9, pants = 99, shoes = 66 },
        business = { torso2 = 7, tshirt = 23, arms = 3, pants = 6, shoes = 6 },
        sport = { torso2 = 5, tshirt = 14, arms = 5, pants = 2, shoes = 2 },
    },
}

--- Motinos / tėvo veidai (head blend shape ids)
Config.ParentFaces = {
    male = { min = 0, max = 45 },
    female = { min = 0, max = 45 },
}
