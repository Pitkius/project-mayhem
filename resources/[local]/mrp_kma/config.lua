Config = Config or {}

Config.Kma = {
    fee = 5000,
    targetSize = vec3(2.2, 2.2, 2.2),
    targetDistance = 2.5,
    --- Žemėlapio legendoje grupė (tas pats skaičius visiems KMA taškams), pvz. kaip parduotuvės blipai.
    --- 0 = FiveM numatyta kategorija; pakeisk jei nori kitą grupę pause žemėlapyje.
    mapBlipCategory = 135,
    blipSprite = 225,
    blipColor = 1,
    blipScale = 0.9,
    blipLabel = 'KMA',
    locations = {
        { id = 'city_impound', label = 'KMA · Mission Row', coords = vector3(408.76, -1623.44, 29.29), heading = 50.0, preview = vector4(415.32, -1636.11, 29.29, 228.0), spawn = vector4(411.84, -1638.42, 29.29, 228.0), defaultGarage = 'pillboxgarage' },
        { id = 'city_casino', label = 'KMA · Casino', coords = vector3(922.54, -58.57, 78.76), heading = 239.0, preview = vector4(909.10, -6.90, 78.76, 147.0), spawn = vector4(909.10, -6.90, 78.76, 147.0), defaultGarage = 'casino' },
        { id = 'city_west', label = 'KMA · Del Perro', coords = vector3(-1222.77, -1489.41, 4.37), heading = 126.0, preview = vector4(-1188.40, -1498.30, 4.37, 124.0), spawn = vector4(-1188.40, -1498.30, 4.37, 124.0), defaultGarage = 'delperro' },
        { id = 'sandy', label = 'KMA · Sandy Shores', coords = vector3(1740.15, 3708.34, 34.14), heading = 20.0, preview = vector4(1722.90, 3713.90, 34.20, 20.0), spawn = vector4(1722.90, 3713.90, 34.20, 20.0), defaultGarage = 'sandy' },
        { id = 'grapeseed', label = 'KMA · Grapeseed', coords = vector3(1706.95, 4943.95, 42.15), heading = 55.0, preview = vector4(1718.66, 4933.22, 42.08, 146.0), spawn = vector4(1718.66, 4933.22, 42.08, 146.0), defaultGarage = 'grapeseed' },
        { id = 'paleto', label = 'KMA · Paleto Bay', coords = vector3(101.85, 6613.34, 32.44), heading = 225.0, preview = vector4(128.60, 6621.60, 31.78, 225.0), spawn = vector4(128.60, 6621.60, 31.78, 225.0), defaultGarage = 'paleto' },
    }
}
