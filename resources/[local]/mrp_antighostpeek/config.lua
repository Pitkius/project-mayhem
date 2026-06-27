Config = {}

Config.Enabled = true

--- Tik PvP — jei nėra žaidėjo taikinio, sistema neįsijungia (galima taikytis į sieną).
Config.MaxTargetDistance = 120.0

--- Papildomas taikinio paieška pagal kamerą (laipsniai).
Config.AimConeDegrees = 9.0

--- Maksimalus raycast atstumas (m).
Config.MaxRayDistance = 150.0

--- Kiek kaulų priešininkas turi matyti pas šaulį, kad būtų laikoma sąžininga kova.
Config.MinShooterBonesVisibleToTarget = 1

--- Šaulio kaulai, kuriuos tikrina priešininkas (matomumas).
Config.ShooterVisibilityBones = {
    31086, -- SKEL_Head
    24818, -- SKEL_Spine3
    11816, -- SKEL_Pelvis
}

--- Taikinio kaulai šūvio trajektorijai.
Config.TargetAimBones = {
    24818, -- chest
    31086, -- head
}

--- Mūsio taškai ant ginklo (Y offset).
Config.WeaponMuzzleOffsets = { 0.82, 0.62, 0.42 }
Config.WeaponOnlyOrigins = true

--- Jei vamzdis < šio atstumo nuo kliūties — laikoma, kad šūvis prasideda sienoje.
Config.MuzzleWallEmbedDistance = 0.14

--- Tolerancija mūsio vs taikinio atstumui (m).
Config.MuzzleHitSlack = 0.45

--- Pranešimas tik kai realiai užblokuotas šūvis.
Config.BlockMessage = 'Ghost Peek apsauga'
Config.NotifyCooldownMs = 2800

--- Mažas ekrano indikatorius (žalias = galima šaudyti, raudonas = blokuojama).
Config.ShowHudIndicator = true
Config.HudUpdateMs = 80
Config.HudOnlyWhenAiming = false

--- Shape test: pasaulis + objektai, be lapų (255 = be IntersectFoliage).
Config.TraceFlags = 255
Config.TraceOptions = 7

Config.RayMaxPasses = 8
Config.PenetrateStep = 0.1
Config.SelfBodyAdvance = 0.45

Config.IgnoreDeadPedHits = true

--- Medžiagos, kurias laikome permatomomis (ne sienu).
Config.PenetrableMaterials = {
    [0x22AD7B72] = true,
    [0x55E5AAEE] = true,
    [0x4F747B87] = true,
    [0xE47A3E41] = true,
    [0xB34E900D] = true,
    [0x8653C6CD] = true,
    [0xC98F5B61] = true,
    [0x92B69883] = true,
    [0xED932E53] = true,
    [0x8DD4EBB9] = true,
    [0x2D6E26CD] = true,
    [0x0781FA34] = true,
    [0xE699F485] = true,
    [0x77E08A22] = true,
    [0x37E12A0B] = true,
    [0x2827CBD9] = true,
    [0xD9B1CDE0] = true,
    [0x7519E5D]  = true,
    [0x1C42F3BC] = true,
    [0x30341454] = true,
    [0x4FFB413F] = true,
    [0x97476A9D] = true,
    [0x76D9AC2F] = true,
    [0xEA3746BD] = true,
    [0xA402C0C0] = true,
}

Config.IgnoredWeapons = {
    [`WEAPON_UNARMED`] = true,
    [`WEAPON_KNIFE`] = true,
    [`WEAPON_NIGHTSTICK`] = true,
    [`WEAPON_HAMMER`] = true,
    [`WEAPON_BAT`] = true,
    [`WEAPON_CROWBAR`] = true,
    [`WEAPON_GOLFCLUB`] = true,
    [`WEAPON_BOTTLE`] = true,
    [`WEAPON_DAGGER`] = true,
    [`WEAPON_HATCHET`] = true,
    [`WEAPON_KNUCKLE`] = true,
    [`WEAPON_MACHETE`] = true,
    [`WEAPON_FLASHLIGHT`] = true,
    [`WEAPON_SWITCHBLADE`] = true,
    [`WEAPON_POOLCUE`] = true,
    [`WEAPON_WRENCH`] = true,
    [`WEAPON_BATTLEAXE`] = true,
    [`WEAPON_STONE_HATCHET`] = true,
    [`WEAPON_STUNGUN`] = true,
    [`WEAPON_PETROLCAN`] = true,
    [`WEAPON_FIREEXTINGUISHER`] = true,
    [`WEAPON_SNOWBALL`] = true,
    [`WEAPON_BALL`] = true,
    [`WEAPON_FLARE`] = true,
    [`WEAPON_GRENADE`] = true,
    [`WEAPON_BZGAS`] = true,
    [`WEAPON_MOLOTOV`] = true,
    [`WEAPON_STICKYBOMB`] = true,
    [`WEAPON_PROXMINE`] = true,
    [`WEAPON_SMOKEGRENADE`] = true,
    [`WEAPON_PIPEBOMB`] = true,
}
