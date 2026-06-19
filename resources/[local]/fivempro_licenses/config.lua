Config = {}

Config.ServerName = 'MRP'
Config.ServerSubtitle = 'Los Santos RP'
Config.ShowRadius = 3.0

--- Item pavadinimai (driver_license = senas QBCore pavadinimas)
Config.Items = {
    id = 'id_card',
    driving = { 'driving_license', 'driver_license' },
    fishing = 'fishing_license',
    hunting = 'hunting_license',
}

Config.DrivingCategories = {
    { key = 'driver_a', letter = 'A', label = 'Motociklai' },
    { key = 'driver_b', letter = 'B', label = 'Lengvieji automobiliai', altKeys = { 'driver' } },
    { key = 'driver_c', letter = 'C', label = 'Sunkvežimiai' },
}

Config.LicenseValidityYears = 2
Config.DefaultNationality = 'Lietuva'

Config.Outdoors = {
    fishing = {
        licenseType = 'Žvejybos licencija',
        allowed = 'Valstybiniai vandenys, pakrantė',
    },
    hunting = {
        licenseType = 'Medžioklės licencija',
        allowed = 'Laukinių zonų medžioklė',
    },
}
