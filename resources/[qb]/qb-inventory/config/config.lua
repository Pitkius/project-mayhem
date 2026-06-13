Config = {
    UseTarget = GetConvar('UseTarget', 'false') == 'true',

    MaxWeight = 120000,
    MaxSlots = 40,

    StashSize = {
        maxweight = 2000000,
        slots = 100
    },

    DropSize = {
        maxweight = 1000000,
        slots = 50
    },

    Keybinds = {
        Open = 'F2',
        Hotbar = 'Z',
    },

    --- F2 inventoriaus atidarymo / uždarymo animacijos (ped + optional kuprinės prop)
    InventoryAnimation = {
        enabled = true,
        disableInVehicle = true,
        useProp = true,
        propModel = `p_michael_backpack_s`,
        propBone = 57005,
        propOffset = { 0.14, -0.02, -0.03, 175.0, 120.0, 0.0 },
        open = { dict = 'pickup_object', anim = 'pickup_low', durationMs = 850 },
        idle = { dict = 'clothingshirt', anim = 'try_shirt_positive_a', flag = 49 },
        close = { dict = 'pickup_object', anim = 'putdown_low', durationMs = 900 },
    },

    CleanupDropTime = 15,    -- in minutes
    CleanupDropInterval = 1, -- in minutes

    ItemDropObject = `bkr_prop_duffel_bag_01a`,
    ItemDropObjectBone = 28422,
    ItemDropObjectOffset = {
        vector3(0.260000, 0.040000, 0.000000),
        vector3(90.000000, 0.000000, -78.989998),
    },

    VendingObjects = {
        'prop_vend_soda_01',
        'prop_vend_soda_02',
        'prop_vend_water_01',
        'prop_vend_coffe_01',
    },

    VendingItems = {
        { name = 'kurkakola',    price = 4, amount = 50 },
        { name = 'water_bottle', price = 4, amount = 50 },
    },
}
