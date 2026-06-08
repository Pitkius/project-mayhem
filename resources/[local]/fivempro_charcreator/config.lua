Config = {}

--- Vienas personažas — be multichar kortelių
Config.DefaultNumberOfCharacters = 1
Config.EnableDeleteButton = false
Config.AutoLoginExistingCharacter = true

--- Scena (tik pirmam personažo kūrimui prisijungus)
Config.Interior = vector3(-763.28, 330.04, 199.49)
Config.HiddenCoords = vector4(-779.02, 326.18, 196.09, 91.0)
Config.PedCoords = vector4(-763.28, 330.04, 199.49, 177.79)
Config.DefaultSpawn = vector4(-1037.89, -2737.68, 20.17, 328.89)

--- Rodyklės ← → suka kamerą apie personažą (laipsniai per paspaudimą / kadrą)
Config.CameraRotateSpeed = 2.5

--- Kirpykla: plaukai, barzda, antakiai, makiažas
Config.BarberSteps = { 'hair', 'facedetails' }

--- Rūbų parduotuvė: tik drabužiai (be veido / plaukų)
Config.ClothingShopSteps = { 'clothes' }
Config.ClothingShopItems = {
    { key = 't-shirt', label = 'Marškinėliai', maxItem = 200, maxTex = 15 },
    { key = 'torso2', label = 'Viršus / striukė', maxItem = 400, maxTex = 15 },
    { key = 'arms', label = 'Rankos', maxItem = 120, maxTex = 10 },
    { key = 'pants', label = 'Kelnės', maxItem = 200, maxTex = 15 },
    { key = 'shoes', label = 'Batai', maxItem = 120, maxTex = 15 },
    { key = 'vest', label = 'Liemenė', maxItem = 80, maxTex = 10 },
    { key = 'bag', label = 'Krepšys', maxItem = 80, maxTex = 10 },
    { key = 'decals', label = 'Lipdukai', maxItem = 120, maxTex = 10 },
    { key = 'accessory', label = 'Aksesuaras (kaklo)', maxItem = 120, maxTex = 10 },
}

--- Pilna apranga personažo kūrime (visi variantai per slankiklius)
Config.CreatorClothingItems = {
    { key = 'mask', label = 'Kaukė', maxItem = 200, maxTex = 15 },
    { key = 't-shirt', label = 'Marškinėliai', maxItem = 200, maxTex = 15 },
    { key = 'torso2', label = 'Viršus / striukė', maxItem = 400, maxTex = 15 },
    { key = 'arms', label = 'Rankos', maxItem = 120, maxTex = 10 },
    { key = 'vest', label = 'Liemenė', maxItem = 80, maxTex = 10 },
    { key = 'decals', label = 'Lipdukai', maxItem = 120, maxTex = 10 },
    { key = 'pants', label = 'Kelnės', maxItem = 200, maxTex = 15 },
    { key = 'shoes', label = 'Batai', maxItem = 120, maxTex = 15 },
    { key = 'bag', label = 'Krepšys', maxItem = 80, maxTex = 10 },
    { key = 'accessory', label = 'Aksesuaras (kaklo)', maxItem = 120, maxTex = 10 },
    { key = 'hat', label = 'Skrybėlė', maxItem = 200, maxTex = 15, propMin = -1 },
    { key = 'glass', label = 'Akiniai', maxItem = 80, maxTex = 15, propMin = -1 },
    { key = 'ear', label = 'Ausų papuošalai', maxItem = 40, maxTex = 15, propMin = -1 },
    { key = 'watch', label = 'Laikrodis', maxItem = 40, maxTex = 15, propMin = -1 },
    { key = 'bracelet', label = 'Apyrankė', maxItem = 20, maxTex = 15, propMin = -1 },
}

Config.Cameras = {
    default = { offset = vector3(0.0, 2.35, 0.35), point = vector3(0.0, 0.0, 0.55), fov = 42.0 },
    face = { offset = vector3(0.0, 0.85, 0.68), point = vector3(0.0, 0.0, 0.68), fov = 28.0 },
    eyes = { offset = vector3(0.0, 0.55, 0.72), point = vector3(0.0, 0.0, 0.70), fov = 18.0 },
    hair = { offset = vector3(0.0, 0.95, 0.82), point = vector3(0.0, 0.0, 0.78), fov = 32.0 },
    body = { offset = vector3(0.0, 3.1, 0.15), point = vector3(0.0, 0.0, 0.35), fov = 48.0 },
    clothes = { offset = vector3(0.0, 2.8, 0.2), point = vector3(0.0, 0.0, 0.4), fov = 45.0 },
}

--- Pilietybės — visas sąrašas iš shared/countries.lua
Config.Nationalities = Countries

--- GTA 5 lore miestai
Config.OriginCities = {
    { id = 'Los Santos', label = 'Los Santos', hint = 'Oro uostas' },
    { id = 'Sandy Shores', label = 'Sandy Shores', hint = 'Prie policijos' },
    { id = 'Paleto Bay', label = 'Paleto Bay', hint = 'Ant tilto' },
    { id = 'Grapeseed', label = 'Grapeseed', hint = 'LS oro uostas' },
}

--- Spawn pagal pasirinktą miestą (naujam personažui)
Config.CitySpawns = {
    ['Los Santos'] = vector4(-1037.89, -2737.68, 20.17, 328.89),
    ['Sandy Shores'] = vector4(1853.24, 3689.83, 34.27, 210.0),
    ['Paleto Bay'] = vector4(-288.55, 6637.45, 7.52, 225.0),
    ['Grapeseed'] = vector4(-1037.89, -2737.68, 20.17, 328.89),
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

--- Motinos / tėvo veidai (head blend shape ids)
Config.ParentFaces = {
    male = { min = 0, max = 45 },
    female = { min = 0, max = 45 },
}
