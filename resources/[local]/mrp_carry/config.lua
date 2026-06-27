Config = {}

Config.MaxDistance = 3.0
Config.OfferTimeoutMs = 12000

-- Animacijų rinkiniai iš patikrintų „CarryPeople / PiggyBack / TakeHostage“ (rubbertoe98/FiveM-Scripts).
Config.Variants = {
    [1] = {
        Label = 'Gaisrininko nešimas',
        Description = 'Ant peties (fireman carry)',
        carrier = { dict = 'missfinale_c2mcs_1', anim = 'fin_c2_mcs_1_camman', flag = 49 },
        carried = { dict = 'nm', anim = 'firemans_carry', flag = 33 },
        attach = { x = 0.27, y = 0.15, z = 0.63, rx = 0.5, ry = 0.5, rz = 180.0 },
    },
    [2] = {
        Label = 'Ant nugaros (piggyback)',
        Description = 'Klasikinis „ant nugaros“',
        carrier = { dict = 'anim@arena@celeb@flat@paired@no_props@', anim = 'piggyback_c_player_a', flag = 49 },
        carried = { dict = 'anim@arena@celeb@flat@paired@no_props@', anim = 'piggyback_c_player_b', flag = 33 },
        attach = { x = 0.0, y = -0.07, z = 0.45, rx = 0.5, ry = 0.5, rz = 180.0 },
    },
    [3] = {
        Label = 'Iš priekio (apsikabinimas)',
        Description = 'Stovint arti, animacija kaip „hostage idle“ be ginklo',
        carrier = { dict = 'anim@gangops@hostage@', anim = 'perp_idle', flag = 49 },
        carried = { dict = 'anim@gangops@hostage@', anim = 'victim_idle', flag = 49 },
        attach = { x = -0.24, y = 0.11, z = 0.0, rx = 0.5, ry = 0.5, rz = 0.0 },
    },
}
