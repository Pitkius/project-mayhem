Config = {}

Config.Enabled = true

--- Bazinė tolerancija (m) — kiek artesnė kliūtis vis dar laikoma „tas pats taškas“.
Config.DistanceThreshold = 0.35

--- Papildoma tolerancija pagal atstumą (m per 1 m atstumo). Toli sumažina klaidingus blokavimus.
Config.DistanceThresholdScale = 0.011

--- Maksimali tolerancija (m) — viršutinė riba toliems šūviams.
Config.MaxDistanceThreshold = 1.85

--- Minimalus atstumas iki taikinio — per arti nevertiname (m).
Config.MinAimDistance = 2.0

--- Maksimalus raycast atstumas (m).
Config.MaxRayDistance = 150.0

--- Kiek šūvio krypčių turi būti laisvos, kad leistų šaudyti (mažiau klaidingų „siena“).
Config.MinClearPaths = 2

--- Kiek kartų leisti praskrodyti minkštą medžiagą vienu spinduliu.
Config.RayMaxPasses = 5

--- Žingsnis praskrodžiant minkštą paviršių (m).
Config.PenetrateStep = 0.1

--- Shape test: be lapų/krumų (511 - 256 IntersectFoliage).
Config.TraceFlags = 255

--- Ignoruoja stiklą, permatomus ir no-collision paviršius.
Config.TraceOptions = 7

--- Medžiagos, kurias laikome „ne sienu“ (krūmai, žolė, tinkleliai, plonas stiklas ir pan.).
Config.PenetrableMaterials = {
    [0x22AD7B72] = true, -- Bushes
    [0x55E5AAEE] = true, -- BushesNoinst
    [0x4F747B87] = true, -- Grass
    [0xE47A3E41] = true, -- GrassLong
    [0xB34E900D] = true, -- GrassShort
    [0x8653C6CD] = true, -- Leaves
    [0xC98F5B61] = true, -- Twigs
    [0x92B69883] = true, -- Hay
    [0xED932E53] = true, -- Woodchips
    [0x8DD4EBB9] = true, -- TreeBark
    [0x2D6E26CD] = true, -- MetalChainLinkSmall
    [0x0781FA34] = true, -- MetalChainLinkLarge
    [0xE699F485] = true, -- MetalGrille
    [0x77E08A22] = true, -- WoodLattice
    [0x37E12A0B] = true, -- GlassShootThrough
    [0x2827CBD9] = true, -- SlattedBlinds
    [0xD9B1CDE0] = true, -- Tarpaulin
    [0x7519E5D]  = true, -- Cloth
    [0x1C42F3BC] = true, -- Paper
    [0x30341454] = true, -- Foam
    [0x4FFB413F] = true, -- FeatherPillow
    [0x97476A9D] = true, -- Polystyrene
    [0x76D9AC2F] = true, -- WoodHollowSmall
    [0xEA3746BD] = true, -- WoodHollowMedium
    [0xA402C0C0] = true, -- PhysBarbedWire
}

--- Nerodyti ant šių ginklų (melee, granatos ir pan.).
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
