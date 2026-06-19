Config = {}

Config.MaxInvoiceAmount = 25000

--- Bendras satelitinio žemėlapio homografija (tas pats kaip LTPD MDT)
Config.MdtMap = {
    projection = 'homography',
    coordSpace = 'pixel',
    gameMin = { x = -4000.0, y = -4000.0 },
    gameMax = { x = 4500.0, y = 6625.0 },
    coordMin = { x = -4000.0, y = -4000.0 },
    coordMax = { x = 4500.0, y = 6625.0 },
    viewMin = { x = -4000.0, y = -4000.0 },
    viewMax = { x = 4500.0, y = 6625.0 },
    offsetX = 0.0,
    offsetY = 0.0,
    scaleX = 1.0,
    scaleY = 1.0,
    flipY = false,
    imageFile = 'nui://fivempro_ltpd/html/mdt/asset/gtav_satellite_2048.png',
    imageWidth = 2048,
    imageHeight = 2048,
    calibration = {
        { gx = -448.15,  gy = 6012.0,   u = 0.4585, v = 0.1099 },
        { gx = 450.77,   gy = 5566.86,  u = 0.5352, v = 0.1426 },
        { gx = 1853.2,   gy = 3686.5,   u = 0.6460, v = 0.2881 },
        { gx = 1695.0,   gy = 4785.0,   u = 0.6616, v = 0.1904 },
        { gx = 611.0,    gy = 2745.0,   u = 0.5156, v = 0.3901 },
        { gx = -2360.0,  gy = 3249.0,   u = 0.2261, v = 0.3896 },
        { gx = -3192.0,  gy = 1100.0,   u = 0.1025, v = 0.5894 },
        { gx = -1520.0,  gy = -440.0,   u = 0.2593, v = 0.6978 },
        { gx = -1098.0,  gy = -808.0,   u = 0.3022, v = 0.7280 },
        { gx = 441.84,   gy = -982.05,  u = 0.4487, v = 0.7383 },
        { gx = 195.0,    gy = -933.0,   u = 0.4092, v = 0.7446 },
        { gx = 311.0,    gy = -590.0,   u = 0.4136, v = 0.6953 },
        { gx = 379.39,   gy = -1591.37, u = 0.4390, v = 0.8008 },
        { gx = 85.0,     gy = -1958.0,  u = 0.3989, v = 0.8276 },
        { gx = -1037.0,  gy = -2737.0,  u = 0.2827, v = 0.9175 },
        { gx = 1206.24,  gy = -3157.06, u = 0.4688, v = 0.9116 },
        { gx = 293.0,    gy = 180.0,    u = 0.4395, v = 0.6274 },
        { gx = -800.0,   gy = 180.0,    u = 0.3472, v = 0.6489 },
        { gx = 981.69,   gy = -102.8,   u = 0.5078, v = 0.6528 },
        { gx = 2452.28,  gy = 4969.7,   u = 0.7065, v = 0.1758 },
        { gx = 826.0,    gy = -1290.0,  u = 0.4727, v = 0.7417 },
        { gx = -75.0,    gy = -818.0,   u = 0.4009, v = 0.7231 },
    },
}

--- EMS / mechanikų MDT profiliai
Config.Services = {
    ems = {
        label = 'EMS MDT',
        brand = 'EMS',
        accent = '#f87171',
        jobs = { 'ambulance' },
        invoiceMinGrade = 0,
        invoicePresets = {
            { code = 'treat_basic', label = 'Pirmoji pagalba', defaultAmount = 350 },
            { code = 'treat_adv', label = 'Skubi pagalba / važtaraštis', defaultAmount = 750 },
            { code = 'transport', label = 'Gydymo transportas', defaultAmount = 500 },
            { code = 'supplies', label = 'Medicininės priemonės', defaultAmount = 150 },
        },
        unitLabel = 'Medikas',
        enableCrews = true,
    },
    mechanic = {
        label = 'Mechanikų MDT',
        brand = 'MECH',
        accent = '#fbbf24',
        jobs = { 'mechanic' },
        invoiceMinGrade = 0,
        enableCrews = false,
        invoicePresets = {
            { code = 'repair_basic', label = 'Remontas (bazinis)', defaultAmount = 400 },
            { code = 'repair_engine', label = 'Variklio remontas', defaultAmount = 1200 },
            { code = 'bodywork', label = 'Kėbulo darbai', defaultAmount = 800 },
            { code = 'towing', label = 'Transporto nutempimas', defaultAmount = 600 },
            { code = 'tuning', label = 'Tuningas / dalys', defaultAmount = 1500 },
        },
        unitLabel = 'Mechanikas',
    },
}
