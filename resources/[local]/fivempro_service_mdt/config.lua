Config = {}

Config.MaxInvoiceAmount = 25000

--- Bendras satelitinio žemėlapio IDW (tas pats kaip LTPD MDT)
Config.MdtMap = {
    projection = 'idw',
    idwPower = 2.0,
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
        { gx = -448.15,  gy = 6012.0,   u = 0.4492, v = 0.0874 },
        { gx = 450.77,   gy = 5566.86,  u = 0.4854, v = 0.1299 },
        { gx = 1853.2,   gy = 3686.5,   u = 0.6934, v = 0.3315 },
        { gx = 1695.0,   gy = 4785.0,   u = 0.6719, v = 0.1924 },
        { gx = 611.0,    gy = 2745.0,   u = 0.5420, v = 0.3584 },
        { gx = -2360.0,  gy = 3249.0,   u = 0.1709, v = 0.3984 },
        { gx = -3192.0,  gy = 1100.0,   u = 0.0977, v = 0.5762 },
        { gx = -1520.0,  gy = -440.0,   u = 0.2539, v = 0.6699 },
        { gx = -1098.0,  gy = -808.0,   u = 0.3311, v = 0.7363 },
        { gx = 441.84,   gy = -982.05,  u = 0.4067, v = 0.7539 },
        { gx = 195.0,    gy = -933.0,   u = 0.4053, v = 0.7451 },
        { gx = 311.0,    gy = -590.0,   u = 0.4502, v = 0.7402 },
        { gx = 379.39,   gy = -1591.37, u = 0.3828, v = 0.7773 },
        { gx = 85.0,     gy = -1958.0,  u = 0.4033, v = 0.8262 },
        { gx = -1037.0,  gy = -2737.0,  u = 0.2734, v = 0.8604 },
        { gx = 1206.24,  gy = -3157.06, u = 0.5029, v = 0.8652 },
        { gx = 293.0,    gy = 180.0,    u = 0.4473, v = 0.5986 },
        { gx = -800.0,   gy = 180.0,    u = 0.2754, v = 0.6455 },
        { gx = 981.69,   gy = -102.8,   u = 0.4912, v = 0.6777 },
        { gx = 2452.28,  gy = 4969.7,   u = 0.7510, v = 0.1221 },
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
    },
    mechanic = {
        label = 'Mechanikų MDT',
        brand = 'MECH',
        accent = '#fbbf24',
        jobs = { 'mechanic' },
        invoiceMinGrade = 0,
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
