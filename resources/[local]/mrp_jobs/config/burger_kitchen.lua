--[[
  Burger Shot — 3D virtuvės receptai, stotys, ingredientų linijos.
  Gaminimas: grilis → surinkimas (padažas/salotos) | fryer | gėrimų fontanas.
]]

Config = Config or {}
Config.BurgerKitchen = Config.BurgerKitchen or {}

Config.BurgerKitchen.enabled = true
Config.BurgerKitchen.sessionTimeoutMs = 120000

--- Stoties tipai (locations.kitchen[].type)
Config.BurgerKitchen.stationTypes = {
    grill = { label = 'Grilis', icon = 'fas fa-fire' },
    fryer = { label = 'Fritiūras', icon = 'fas fa-bacon' },
    assembly = { label = 'Surinkimo stalas', icon = 'fas fa-hamburger' },
    drinks = { label = 'Gėrimų fontanas', icon = 'fas fa-glass-whiskey' },
}

--- Produktų 3D linijos (stages eilės tvarka)
--- stationHint — kurią virtuvės zoną naudoti kaip workspace origin
Config.BurgerKitchen.products = {
    burger_basic = {
        label = 'Paprastas burgeris',
        stationHint = 'grill',
        line = 'burger',
        patty = 'beef',
        sauces = { 'ketchup' },
        toppings = { 'lettuce', 'tomato' },
        cheese = false,
        bacon = false,
        patties = 1,
    },
    burger_double = {
        label = 'Dvigubas burgeris',
        stationHint = 'grill',
        line = 'burger',
        patty = 'beef',
        sauces = { 'ketchup', 'mayo' },
        toppings = { 'lettuce', 'tomato', 'onion' },
        cheese = true,
        bacon = false,
        patties = 2,
    },
    burger_chicken = {
        label = 'Vištienos burgeris',
        stationHint = 'grill',
        line = 'burger',
        patty = 'chicken',
        sauces = { 'mayo' },
        toppings = { 'lettuce' },
        cheese = false,
        bacon = false,
        patties = 1,
    },
    burger_cheese = {
        label = 'Sūrio burgeris',
        stationHint = 'grill',
        line = 'burger',
        patty = 'beef',
        sauces = { 'ketchup' },
        toppings = { 'lettuce' },
        cheese = true,
        bacon = false,
        patties = 1,
    },
    burger_bacon = {
        label = 'Šoninės burgeris',
        stationHint = 'grill',
        line = 'burger',
        patty = 'beef',
        sauces = { 'bbq' },
        toppings = { 'lettuce', 'onion' },
        cheese = true,
        bacon = true,
        patties = 1,
    },
    burger_bbq = {
        label = 'BBQ burgeris',
        stationHint = 'grill',
        line = 'burger',
        patty = 'beef',
        sauces = { 'bbq' },
        toppings = { 'onion' },
        cheese = true,
        bacon = false,
        patties = 1,
    },
    burger_salad = {
        label = 'Salotų burgeris',
        stationHint = 'grill',
        line = 'burger',
        patty = 'chicken',
        sauces = { 'mayo' },
        toppings = { 'lettuce', 'tomato', 'onion' },
        cheese = false,
        bacon = false,
        patties = 1,
        heavySalad = true,
    },
    burger_fries = {
        label = 'Bulvytės',
        stationHint = 'fryer',
        line = 'fries',
    },
    burger_softdrink = {
        label = 'Gėrimas',
        stationHint = 'drinks',
        line = 'drink',
        flavor = 'cola',
    },
    burger_meal = {
        label = 'Burgerio meniu',
        stationHint = 'assembly',
        line = 'meal', --- box: basic + fries + drink shortcut stages
    },
}

--- Propai (vanilla GTA — jei modelio nėra, fallback į kitą)
Config.BurgerKitchen.props = {
    grill = { 'prop_bbq_2', 'prop_bbq_1', 'prop_cooker_03' },
    fryer = { 'prop_cooker_03', 'prop_chip_fryer' },
    board = { 'prop_food_bs_tray_01', 'prop_cs_plate_01' },
    fountain = { 'prop_food_bs_juice01', 'prop_watercooler' },
    patty_raw = { 'prop_cs_steak', 'prop_food_bs_burger2' },
    patty_cooked = { 'prop_cs_steak', 'prop_food_bs_burger2' },
    chicken = { 'prop_food_cb_burg02', 'prop_cs_steak' },
    bun_bot = { 'prop_food_bs_burg3', 'prop_food_bs_burg1' },
    bun_top = { 'prop_food_bs_burg3', 'prop_food_bs_burg1' },
    lettuce = { 'prop_veg_crop_03_cab', 'prop_food_bs_burg1' },
    tomato = { 'prop_veg_crop_03_cab', 'prop_food_bs_burg1' },
    cheese = { 'prop_food_bs_burg1', 'prop_cs_plate_01' },
    bacon = { 'prop_cs_steak', 'prop_food_bs_burg2' },
    sauce = { 'prop_cs_script_bottle', 'prop_plastic_cup_02' },
    fries_raw = { 'prop_food_bs_chips', 'prop_food_chips' },
    fries_done = { 'prop_food_bs_chips', 'prop_food_chips' },
    cup_empty = { 'prop_plastic_cup_02', 'prop_food_bs_juice02' },
    cup_full = { 'prop_food_bs_juice02', 'prop_plastic_cup_02' },
    meal_box = { 'prop_food_bs_bag_01', 'prop_paper_bag_small' },
    finished_burger = { 'prop_food_bs_burg3', 'prop_food_bs_burg1' },
}

Config.BurgerKitchen.anims = {
    flip = { dict = 'amb@prop_human_bbq@male@base', clip = 'base' },
    chop = { dict = 'anim@amb@business@coc@coc_unpack_cut@', clip = 'fullcut_cycle_v1_cokecutter' },
    pour = { dict = 'weapon@w_sp_jerrycan', clip = 'fire' },
    grab = { dict = 'mp_common', clip = 'givetake1_a' },
    fry = { dict = 'amb@prop_human_bbq@male@idle_a', clip = 'idle_b' },
    assemble = { dict = 'anim@heists@prison_heiststation@cop_reactions', clip = 'cop_b_idle' },
}

--- Etapų trukmės / tolerancijos
Config.BurgerKitchen.timing = {
    grillReadyMs = { min = 4500, max = 7000 },
    grillBurnMs = 11000,
    fryReadyMs = { min = 5000, max = 8000 },
    fryBurnMs = 12000,
    pourHoldMs = 2200,
    sauceHoldMs = 1600,
    placeSnapMs = 400,
}
