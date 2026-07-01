Config = {}

Config.MaxDistance = 2.5

Config.Search = {
    progressMs = 4200,
    label = 'Apieškoma…',
    anim = { dict = 'mini@repair', clip = 'fixing_a_player', flag = 49 },
    loopAnim = { dict = 'mini@repair', clip = 'fixing_a_player', flag = 49 },
}

--- Surakinimo tipai
Config.Restraints = {
    handcuffs = {
        item = 'handcuffs',
        label = 'Antrankiai',
        applyLabel = 'Dedami antrankiai…',
        removeLabel = 'Nuimami antrankiai…',
        progressMs = 3500,
        returnOnRemove = true,
        pdDutyBypassItem = false,
        applyAnim = { dict = 'mp_arrest_paired', clip = 'cop_p2_back_right', flag = 49 },
    },
    ziptie = {
        item = 'ziptie',
        label = 'Plastikiniai dirželiai',
        applyLabel = 'Veržiami dirželiai…',
        removeLabel = 'Kerpami dirželiai…',
        progressMs = 2800,
        consumeOnApply = true,
        removeRequiresItem = 'screwdriverset',
        applyAnim = { dict = 'mp_arrest_paired', clip = 'cop_p2_back_right', flag = 49 },
    },
    rope = {
        item = 'rope',
        label = 'Virvė',
        applyLabel = 'Surišama virve…',
        removeLabel = 'Atrišama virvė…',
        progressMs = 4000,
        consumeOnApply = true,
        removeRequiresItem = nil,
        applyAnim = { dict = 'mp_arrest_paired', clip = 'cop_p2_back_right', flag = 49 },
    },
}

--- PD tarnyboje gali naudoti antrankius be item tik jei turi teisę (fallback — dažniau naudoja item)
Config.PoliceJob = 'police'
Config.RangerJob = 'ranger'
