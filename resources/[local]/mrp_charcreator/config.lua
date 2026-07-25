Config = {}

--- Vienas personažas — be multichar kortelių
Config.DefaultNumberOfCharacters = 1
Config.EnableDeleteButton = false
Config.AutoLoginExistingCharacter = true

--- Scena (tik pirmam personažo kūrimui prisijungus) — apšviestas bunkerio kambarys
Config.Interior = vector3(404.9589, -957.7651, -99.0042)
Config.HiddenCoords = vector4(397.0, -965.0, -99.0042, 0.0)
--- w = heading: veikėjas žiūri į kamerą (be papildomo rankinio sukimo)
Config.PedCoords = vector4(404.9589, -957.7651, -99.0042, 180.0)
Config.DefaultSpawn = vector4(-1037.9487, -2738.0669, 20.1693, 330.3262)

--- Rodyklės ← → suka kamerą apie personažą (laipsniai per paspaudimą / kadrą)
Config.CameraRotateSpeed = 2.5

--- Kirpykla: plaukai, barzda, antakiai, makiažas
Config.BarberSteps = { 'hair', 'facedetails' }

--- Tatuiruočių salonas
Config.TattooShopSteps = { 'tattoos' }
Config.TattooShopPrice = 350
Config.TattooZones = {
    { id = 'ZONE_HEAD', label = 'Galva' },
    { id = 'ZONE_TORSO', label = 'Liemuo' },
    { id = 'ZONE_LEFT_ARM', label = 'Kairė ranka' },
    { id = 'ZONE_RIGHT_ARM', label = 'Dešinė ranka' },
    { id = 'ZONE_LEFT_LEG', label = 'Kairė koja' },
    { id = 'ZONE_RIGHT_LEG', label = 'Dešinė koja' },
    { id = 'ZONE_HAIR', label = 'Plaukai' },
}

--- Rūbų parduotuvė: tik drabužiai (be veido / plaukų)
Config.ClothingShopSteps = { 'clothes' }
Config.ClothingShopPrice = 250
Config.ClothingShopItems = {
    { key = 'mask', label = 'Kaukė', maxItem = 200, maxTex = 15 },
    -- gauju_rubai gang kevlar = smuggler accs_009 → component 8 (t-shirt), not vest
    { key = 't-shirt', label = 'Marškinėliai / gaujų liemenės', maxItem = 200, maxTex = 25 },
    { key = 'torso2', label = 'Viršus / striukė', maxItem = 500, maxTex = 15 },
    { key = 'arms', label = 'Rankos', maxItem = 200, maxTex = 10 },
    { key = 'pants', label = 'Kelnės', maxItem = 250, maxTex = 15 },
    { key = 'shoes', label = 'Batai', maxItem = 150, maxTex = 15 },
    { key = 'vest', label = 'Liemenė (šarvai)', maxItem = 100, maxTex = 10 },
    { key = 'bag', label = 'Krepšys', maxItem = 100, maxTex = 10 },
    { key = 'decals', label = 'Lipdukai', maxItem = 150, maxTex = 10 },
    { key = 'accessory', label = 'Aksesuaras (kaklo)', maxItem = 150, maxTex = 10 },
    { key = 'hat', label = 'Skrybėlė', maxItem = 200, maxTex = 15, propMin = -1 },
    { key = 'glass', label = 'Akiniai', maxItem = 80, maxTex = 15, propMin = -1 },
}

--- Pilna apranga personažo kūrime (visi variantai per slankiklius)
Config.CreatorClothingItems = {
    { key = 'mask', label = 'Kaukė', maxItem = 250, maxTex = 15 },
    -- gauju_rubai gang kevlar = smuggler accs_009 → component 8 (t-shirt), not vest
    { key = 't-shirt', label = 'Marškinėliai / gaujų liemenės', maxItem = 250, maxTex = 25 },
    { key = 'torso2', label = 'Viršus / striukė', maxItem = 500, maxTex = 15 },
    { key = 'arms', label = 'Rankos', maxItem = 200, maxTex = 10 },
    { key = 'vest', label = 'Liemenė (šarvai)', maxItem = 100, maxTex = 10 },
    { key = 'decals', label = 'Lipdukai', maxItem = 150, maxTex = 10 },
    { key = 'pants', label = 'Kelnės', maxItem = 250, maxTex = 15 },
    { key = 'shoes', label = 'Batai', maxItem = 150, maxTex = 15 },
    { key = 'bag', label = 'Krepšys', maxItem = 100, maxTex = 10 },
    { key = 'accessory', label = 'Aksesuaras (kaklo)', maxItem = 150, maxTex = 10 },
    { key = 'hat', label = 'Skrybėlė', maxItem = 250, maxTex = 15, propMin = -1 },
    { key = 'glass', label = 'Akiniai', maxItem = 100, maxTex = 15, propMin = -1 },
    { key = 'ear', label = 'Ausų papuošalai', maxItem = 50, maxTex = 15, propMin = -1 },
    { key = 'watch', label = 'Laikrodis', maxItem = 50, maxTex = 15, propMin = -1 },
    { key = 'bracelet', label = 'Apyrankė', maxItem = 30, maxTex = 15, propMin = -1 },
}

--- distance = atstumas nuo ped (mažesnis = arčiau); camHeight / lookAt = Z offset; fov = lauko kampas
--- lateral = teigiamas = personažas ekrane dešiniau (kamera šiek tiek į kairę nuo centro)
Config.Cameras = {
    default = { distance = 2.15, camHeight = 0.48, lookAt = 0.58, fov = 44.0, lateral = 0.42 },
    face = { distance = 1.12, camHeight = 0.64, lookAt = 0.64, fov = 36.0, lateral = 0.28 },
    hair = { distance = 1.22, camHeight = 0.74, lookAt = 0.70, fov = 36.0, lateral = 0.28 },
    body = { distance = 3.15, camHeight = 0.18, lookAt = -0.02, fov = 52.0, lateral = 0.55 },
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
    ['Los Santos'] = vector4(-1037.9487, -2738.0669, 20.1693, 330.3262),
    ['Sandy Shores'] = vector4(1968.7705, 3710.0442, 32.1498, 66.6371),
    ['Paleto Bay'] = vector4(-679.1505, 5834.2915, 17.3313, 133.0065),
    ['Grapeseed'] = vector4(1793.4620, 4595.1646, 37.6829, 183.1981),
}

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
