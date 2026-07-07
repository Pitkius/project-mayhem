--- Visų gamybos stočių sujungimas (client + server)
function Config.GetAllCraftStations()
    local list = {}
    local function pushAll(stations)
        if not stations then return end
        for _, st in ipairs(stations) do
            list[#list + 1] = st
        end
    end

    pushAll(Config.Stations)

    local labs = {
        Config.HeroinLab,
        Config.ThcLab,
        Config.AlcoholLab,
        Config.VapeLab,
        Config.MushroomLab,
        Config.CocaineLab,
        Config.MethLab,
        Config.PillsLab,
        Config.WeaponBenchL1,
    }
    for _, lab in ipairs(labs) do
        pushAll(lab and lab.stations)
    end

    local weedCayo = Config.WeedCayoLab
    pushAll(weedCayo and weedCayo.stations)
    pushAll(weedCayo and weedCayo.packStations)

    local ampLab = Config.AmpMobileLab
    if ampLab and ampLab.packStation then
        list[#list + 1] = ampLab.packStation
    end

    return list
end
