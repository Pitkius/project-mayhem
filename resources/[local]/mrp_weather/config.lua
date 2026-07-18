Config = Config or {}

--- Deterministinė orų prognozė pagal žaidimo laiką (sinchronizuota su qb-weathersync).
Config.Weather = {
    --- Fiksuotas seed — keisk tik norėdamas visiškai naują prognozės ciklą.
    Seed = 58291,
    ForecastDays = 7,

    Regions = {
        {
            id = 'los_santos',
            label = 'Los Santos',
            hint = 'Miesto centras',
            center = { x = -200.0, y = -900.0 },
            radius = 4200.0,
        },
        {
            id = 'sandy_shores',
            label = 'Sandy Shores',
            hint = 'Dykrų regionas',
            center = { x = 1850.0, y = 3700.0 },
            radius = 2800.0,
        },
        {
            id = 'paleto_bay',
            label = 'Paleto Bay',
            hint = 'Šiaurinis miestelis',
            center = { x = -200.0, y = 6400.0 },
            radius = 2400.0,
        },
    },

    --- Klimato svoriai pagal regioną (deterministinis pseudo-atsitiktinumas).
    RegionWeights = {
        los_santos = {
            EXTRASUNNY = 16, CLEAR = 20, CLOUDS = 18, OVERCAST = 12,
            FOGGY = 6, CLEARING = 8, RAIN = 12, THUNDER = 4, SMOG = 10,
        },
        sandy_shores = {
            EXTRASUNNY = 34, CLEAR = 28, CLOUDS = 14, OVERCAST = 8,
            FOGGY = 2, CLEARING = 6, RAIN = 4, THUNDER = 2, SMOG = 2,
        },
        paleto_bay = {
            EXTRASUNNY = 8, CLEAR = 14, CLOUDS = 22, OVERCAST = 18,
            FOGGY = 14, CLEARING = 10, RAIN = 10, THUNDER = 2, SMOG = 2,
        },
    },

    BaseTempC = {
        los_santos = 22,
        sandy_shores = 31,
        paleto_bay = 13,
    },

    TempModifier = {
        EXTRASUNNY = 4, CLEAR = 2, CLOUDS = 0, OVERCAST = -1, FOGGY = -3,
        CLEARING = 0, RAIN = -4, THUNDER = -5, SMOG = 1, NEUTRAL = 0,
        SNOW = -8, BLIZZARD = -10, SNOWLIGHT = -5, XMAS = -6, HALLOWEEN = 0,
    },

    Labels = {
        EXTRASUNNY = 'Labai saulėta',
        CLEAR = 'Giedra',
        CLOUDS = 'Debesuota',
        OVERCAST = 'Pilka',
        FOGGY = 'Rūkas',
        CLEARING = 'Giedrėja',
        RAIN = 'Lietus',
        THUNDER = 'Audra',
        SMOG = 'Smogas',
        NEUTRAL = 'Neutralu',
        SNOW = 'Sniegas',
        BLIZZARD = 'Pūga',
        SNOWLIGHT = 'Lengvas sniegas',
        XMAS = 'Žiemos orai',
        HALLOWEEN = 'Helovinas',
    },

    Icons = {
        EXTRASUNNY = 'sun',
        CLEAR = 'sun',
        CLOUDS = 'cloud',
        OVERCAST = 'cloud',
        FOGGY = 'fog',
        CLEARING = 'partly',
        RAIN = 'rain',
        THUNDER = 'storm',
        SMOG = 'smog',
        NEUTRAL = 'cloud',
        SNOW = 'snow',
        BLIZZARD = 'snow',
        SNOWLIGHT = 'snow',
        XMAS = 'snow',
        HALLOWEEN = 'cloud',
    },

    --- Perėjimas tarp orų tipų (sek.). Ilgesnis = mažiau „šuolių“.
    TransitionSeconds = 45.0,
    --- Kiek žaidimo valandų laikyti tą patį orą (3 ≈ ~6 realios min. su qb-weathersync tempu).
    WeatherBlockHours = 3,
    --- Kiek sekundžių „prilipti“ prie regiono pasienyje (mažiau mirgėjimo LS↔Sandy).
    RegionStickSeconds = 12.0,
    --- Išjungti qb-weathersync atsitiktinį orų keitimą — prognozė valdo realybę.
    DisableDynamicWeather = true,
}
