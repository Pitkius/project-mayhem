Config = {}

Config.Enabled = true

--- Kiek toliau kamera „mato“ nei ginklo spindulys — laikoma ghost peek.
Config.DistanceThreshold = 0.35

--- Maksimalus raycast atstumas (metrai).
Config.MaxRayDistance = 120.0

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
