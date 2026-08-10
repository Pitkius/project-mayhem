Config = Config or {}

--[[
  Surface-aware handling layer (on top of VehiclePerf baseline).
  Covers ALL driveable vehicles: vanilla, REH/custom, PD fleet — via Shared.Vehicles
  + GetVehicleClass() fallback when model is not in QB shared.
]]

Config.SurfaceHandling = {
    Enabled = true,
    TickMs = 750,
    IdleTickMs = 1200,

    --- GTA material hashes → logical surface (extend as needed)
    MaterialToSurface = {
        -- asphalt / tarmac family (common)
        [0] = 'asphalt',
        [1] = 'asphalt',
        [2] = 'concrete',
        [3] = 'concrete',
        [4] = 'concrete',
        [5] = 'gravel',
        [6] = 'gravel',
        [9] = 'sand',
        [10] = 'sand',
        [11] = 'sand',
        [12] = 'rock',
        [13] = 'rock',
        [14] = 'rock',
        [15] = 'grass',
        [16] = 'grass',
        [17] = 'grass',
        [18] = 'mud',
        [19] = 'mud',
        [20] = 'mud',
        [21] = 'forest',
        [22] = 'forest',
        [23] = 'gravel',
        [27] = 'sand',
        [28] = 'sand',
        [31] = 'gravel',
        [32] = 'asphalt',
        [35] = 'concrete',
        [36] = 'concrete',
        [46] = 'mud',
        [47] = 'mud',
        [48] = 'grass',
        [55] = 'forest',
        [64] = 'asphalt',
        [65] = 'asphalt',
        [66] = 'concrete',
        [70] = 'sand',
        [71] = 'sand',
        [72] = 'sand',
        [73] = 'sand',
        [75] = 'rock',
        [76] = 'rock',
        [78] = 'gravel',
        [79] = 'gravel',
        [80] = 'grass',
        [81] = 'grass',
        [82] = 'grass',
        [83] = 'mud',
        [84] = 'mud',
        [85] = 'mud',
        [86] = 'forest',
        [87] = 'forest',
    },

    DefaultSurface = 'asphalt',

    --- Per surface feel multipliers applied to baseline (1.0 = no change).
    --- Keys: traction, accel, brake, steer, drag, lowSpeedLoss
    SurfaceFeel = {
        asphalt = { traction = 1.00, accel = 1.00, brake = 1.00, steer = 1.00, drag = 1.00, lowSpeedLoss = 1.00 },
        concrete = { traction = 0.98, accel = 0.99, brake = 0.99, steer = 0.99, drag = 1.00, lowSpeedLoss = 1.02 },
        gravel = { traction = 0.78, accel = 0.88, brake = 0.85, steer = 0.90, drag = 1.06, lowSpeedLoss = 1.18 },
        sand = { traction = 0.55, accel = 0.72, brake = 0.70, steer = 0.82, drag = 1.18, lowSpeedLoss = 1.35 },
        grass = { traction = 0.62, accel = 0.80, brake = 0.78, steer = 0.86, drag = 1.10, lowSpeedLoss = 1.25 },
        mud = { traction = 0.48, accel = 0.65, brake = 0.62, steer = 0.78, drag = 1.22, lowSpeedLoss = 1.45 },
        forest = { traction = 0.58, accel = 0.74, brake = 0.72, steer = 0.84, drag = 1.14, lowSpeedLoss = 1.30 },
        rock = { traction = 0.70, accel = 0.82, brake = 0.80, steer = 0.88, drag = 1.08, lowSpeedLoss = 1.20 },
    },

    --- Class multipliers vs surface grip (multiply with SurfaceFeel.traction etc.).
    --- Lower = worse off-road. Asphalt usually ~1.0 for all.
    Classes = {
        Hyper = {
            asphalt = 1.00, concrete = 0.97, gravel = 0.55, sand = 0.42, grass = 0.48,
            mud = 0.35, forest = 0.45, rock = 0.50,
        },
        Super = {
            asphalt = 1.00, concrete = 0.97, gravel = 0.60, sand = 0.45, grass = 0.52,
            mud = 0.38, forest = 0.48, rock = 0.55,
        },
        Sport = {
            asphalt = 1.00, concrete = 0.98, gravel = 0.70, sand = 0.55, grass = 0.60,
            mud = 0.48, forest = 0.58, rock = 0.62,
        },
        Muscle = {
            asphalt = 1.00, concrete = 0.98, gravel = 0.72, sand = 0.58, grass = 0.64,
            mud = 0.50, forest = 0.60, rock = 0.65,
        },
        Sedan = {
            asphalt = 1.00, concrete = 0.99, gravel = 0.82, sand = 0.68, grass = 0.74,
            mud = 0.60, forest = 0.70, rock = 0.75,
        },
        SUV = {
            asphalt = 0.98, concrete = 0.98, gravel = 0.90, sand = 0.82, grass = 0.85,
            mud = 0.78, forest = 0.84, rock = 0.86,
        },
        Offroad = {
            asphalt = 0.96, concrete = 0.96, gravel = 1.00, sand = 0.95, grass = 0.96,
            mud = 0.95, forest = 0.97, rock = 0.94,
        },
        Pickup = {
            asphalt = 0.97, concrete = 0.97, gravel = 0.92, sand = 0.86, grass = 0.88,
            mud = 0.84, forest = 0.87, rock = 0.88,
        },
        Emergency = {
            asphalt = 1.00, concrete = 0.99, gravel = 0.80, sand = 0.65, grass = 0.72,
            mud = 0.58, forest = 0.68, rock = 0.72,
        },
        Motorcycle = {
            asphalt = 1.00, concrete = 0.98, gravel = 0.55, sand = 0.40, grass = 0.45,
            mud = 0.35, forest = 0.42, rock = 0.48,
        },
    },

    --- Extra class for dirt bikes (better off-road than Motorcycle)
    MotorcycleDirt = {
        asphalt = 0.92, concrete = 0.92, gravel = 1.00, sand = 0.90, grass = 0.95,
        mud = 0.92, forest = 0.96, rock = 0.88,
    },
    MotorcycleStreet = {
        asphalt = 1.00, concrete = 0.99, gravel = 0.50, sand = 0.35, grass = 0.40,
        mud = 0.30, forest = 0.38, rock = 0.45,
    },

    --- Map QB / GTA categories → surface class
    CategoryMap = {
        super = 'Super',
        sports = 'Sport',
        sportsclassics = 'Sport',
        coupes = 'Sport',
        muscle = 'Muscle',
        sedans = 'Sedan',
        compacts = 'Sedan',
        wagons = 'Sedan',
        suvs = 'SUV',
        offroad = 'Offroad',
        utility = 'Pickup',
        vans = 'Pickup',
        service = 'Emergency',
        emergency = 'Emergency',
        motorcycles = 'Motorcycle',
        industrial = 'Pickup',
        commercial = 'Pickup',
        military = 'Offroad',
        openwheel = 'Hyper',
    },

    --- Model overrides (lowercase). PD + custom + specials.
    ModelClass = {
        -- hyper from VehiclePerf still wins via HyperCars check in code
        dubsta = 'Offroad',
        dubsta2 = 'Offroad',
        dubsta3 = 'Offroad',
        brawler = 'Offroad',
        kamacho = 'Offroad',
        rancherxl = 'Offroad',
        sandking = 'Offroad',
        sandking2 = 'Offroad',
        bifta = 'Offroad',
        trophytruck = 'Offroad',
        trophytruck2 = 'Offroad',
        caracara = 'Offroad',
        caracara2 = 'Offroad',
        everon = 'Offroad',
        hellion = 'Offroad',
        outlaw = 'Offroad',
        vagrant = 'Offroad',
        -- dirt bikes
        sanchez = 'MotorcycleDirt',
        sanchez2 = 'MotorcycleDirt',
        manchez = 'MotorcycleDirt',
        manchez2 = 'MotorcycleDirt',
        bf400 = 'MotorcycleDirt',
        esskey = 'MotorcycleDirt',
        cliffhanger = 'MotorcycleDirt',
        enduro = 'MotorcycleDirt',
        -- street bikes
        bati = 'MotorcycleStreet',
        bati2 = 'MotorcycleStreet',
        akuma = 'MotorcycleStreet',
        double = 'MotorcycleStreet',
        hakuchou = 'MotorcycleStreet',
        hakuchou2 = 'MotorcycleStreet',
        carbonrs = 'MotorcycleStreet',
        defiler = 'MotorcycleStreet',
        shotaro = 'MotorcycleStreet',
        -- PD fleet (all packs)
        mrpd1 = 'Emergency', mrpd2 = 'Emergency', mrpd3 = 'Emergency', mrpd4 = 'Emergency',
        mrpd5 = 'Emergency', mrpd6 = 'Emergency', mrpd7 = 'Emergency', mrpd8 = 'Emergency',
        mrpd9 = 'Emergency', mrpd10 = 'Emergency', mrpd11 = 'Emergency', mrpd12 = 'Emergency',
        mrpd13 = 'Emergency', mrpd14 = 'Emergency', mrpd15 = 'Emergency', mrpd16 = 'Emergency',
        mrpd17 = 'Emergency', mrpd18 = 'Emergency', mrpd19 = 'Emergency', mrpd20 = 'Offroad',
        mrpd21 = 'Emergency', mrpd22 = 'Emergency', mrpd23 = 'Emergency', mrpd24 = 'Emergency',
        mrpd25 = 'Emergency', mrpd26 = 'Emergency', mrpd27 = 'Emergency',
        mrpd28 = 'Emergency', mrpd29 = 'Emergency', mrpd30 = 'Emergency',
        mrpd31 = 'Emergency', mrpd32 = 'Emergency',
    },

    --- High-ride bonus models (extra off-road forgiveness)
    SpecialModels = {
        dubsta = true, dubsta2 = true, dubsta3 = true,
        brawler = true, kamacho = true, rancherxl = true,
        sandking = true, sandking2 = true, caracara = true, caracara2 = true,
        everon = true, hellion = true, bifta = true,
    },
    SpecialBonus = 0.08, -- added to class surface mult on loose surfaces

    Suspension = {
        --- GetVehicleMod(15): higher index = lower. Treat last 2 levels as "Low".
        LowExtraDebuff = {
            Hyper = 0.22, Super = 0.20, Sport = 0.16, Muscle = 0.14,
            Sedan = 0.10, SUV = 0.15, Offroad = 0.08, Pickup = 0.10,
            Emergency = 0.12, Motorcycle = 0.05, MotorcycleDirt = 0.04, MotorcycleStreet = 0.06,
        },
    },

    --- Wheel type 4 = OFFROAD in GTA
    OffroadTires = {
        --- How much of the *penalty* (1-mult) is removed
        gravel = 0.40, sand = 0.25, grass = 0.30, mud = 0.28, forest = 0.30, rock = 0.22,
    },

    --- Handling fields we temporarily scale (never touch max flat vel as primary debuff)
    Fields = {
        tractionMax = 'fTractionCurveMax',
        tractionMin = 'fTractionCurveMin',
        lowSpeedLoss = 'fLowSpeedTractionLossMult',
        driveForce = 'fInitialDriveForce',
        inertia = 'fDriveInertia',
        brake = 'fBrakeForce',
        steer = 'fSteeringLock',
        drag = 'fInitialDragCoeff',
    },
}
