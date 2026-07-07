#!/usr/bin/env python3
"""Perrašo QBShared.Items label ir description į lietuvių kalbą."""
import re
from pathlib import Path

ITEMS_PATH = Path(__file__).resolve().parents[1] / "resources" / "[qb]" / "qb-core" / "shared" / "items.lua"

# Raktažodis -> (label, description)
LT = {
    # Melee
    "weapon_unarmed": ("Kumščiai", "Tuščios rankos."),
    "weapon_dagger": ("Durklas", "Trumpas peilis su aštriu ašmeniu."),
    "weapon_bat": ("Beisbolo lazda", "Naudojama sportui arba… kitiems tikslams."),
    "weapon_bottle": ("Sudaužta butelis", "Aštrus stiklo gabalas."),
    "weapon_crowbar": ("Laužtuvas", "Metalinis svirties įrankis."),
    "weapon_flashlight": ("Žibintuvėlis", "Nešiojamas baterijinis šviesos šaltinis."),
    "weapon_golfclub": ("Golfo lazda", "Klubas kamuoliui mušti."),
    "weapon_hammer": ("Plaktukas", "Įrankis vinių kalimui ir daiktų laužymui."),
    "weapon_hatchet": ("Kirvis", "Mažas kirvis vienai rankai."),
    "weapon_knuckle": ("Kastetas", "Metalinė apsauga ant kumščių."),
    "weapon_knife": ("Peilis", "Aštrus peilis su rankena."),
    "weapon_machete": ("Mačetė", "Platus ir sunkus peilis."),
    "weapon_switchblade": ("Spyruoklinis peilis", "Peilis su iššokančiu ašmeniu."),
    "weapon_nightstick": ("Policininko lazda", "Tarnybinė gumine lazda."),
    "weapon_wrench": ("Veržliaraktis", "Įrankis veržlių sukimui."),
    "weapon_battleaxe": ("Mūšio kirvis", "Didelis karo kirvis."),
    "weapon_poolcue": ("Biliardo lazda", "Lazda kamuoliui mušti."),
    "weapon_briefcase": ("Portfelis", "Dokumentams nešioti."),
    "weapon_briefcase_02": ("Lagaminas", "Kelionės lagaminas."),
    "weapon_garbagebag": ("Šiukšlių maišas", "Plastikinis maišas."),
    "weapon_handcuffs": ("Antrankiai", "Metaliniai antrankiai sulaikymui."),
    "weapon_bread": ("Baigetė", "Ilga duonos kepalas."),
    "weapon_stone_hatchet": ("Akmeninis kirvis", "Pirmykštis kirvis."),
    "weapon_candycane": ("Kalėdinis saldainis", "Saldus lazdelės formos saldainis."),
    # Handguns
    "weapon_pistol": ("Pistoletas Walther P99", "Kompaktiškas pistoletas."),
    "weapon_pistol_mk2": ("Pistoletas Mk II", "Patobulintas pistoletas."),
    "weapon_combatpistol": ("Kovinis pistoletas", "Taktinis pistoletas tarnybai."),
    "weapon_appistol": ("AP pistoletas", "Automatinis pistoletas."),
    "weapon_stungun": ("Elektros šokas", "Nešiojamas elektros šoko įtaisas."),
    "weapon_pistol50": ("Pistoletas .50", "Galingas kalibro pistoletas."),
    "weapon_snspistol": ("SNS pistoletas", "Mažas, lengvai paslėpti pistoletas."),
    "weapon_heavypistol": ("Sunkusis pistoletas", "Stiprus, sunkus pistoletas."),
    "weapon_vintagepistol": ("Senovinis pistoletas", "Kolekcinis pistoletas."),
    "weapon_flaregun": ("Signalinis pistoletas", "Šūviams į orą signalizuoti."),
    "weapon_marksmanpistol": ("Taikliojo šaulio pistoletas", "Labai tikslus pistoletas."),
    "weapon_revolver": ("Revolveris", "Su besisukančiu būgneliu."),
    "weapon_revolver_mk2": ("Revolveris Mk II", "Patobulintas revolveris."),
    "weapon_doubleaction": ("Dvigubo veikimo revolveris", "Greitai paleidžiamas revolveris."),
    "weapon_snspistol_mk2": ("SNS pistoletas Mk II", "Patobulintas SNS pistoletas."),
    "weapon_raypistol": ("Up-n-Atomizer", "Eksperimentinis energijos pistoletas."),
    "weapon_ceramicpistol": ("Keramikinis pistoletas", "Lengvas keramikinis pistoletas."),
    "weapon_navyrevolver": ("Laivyno revolveris", "Klasikinis revolveris."),
    "weapon_gadgetpistol": ("Perico pistoletas", "Paslėptas mini pistoletas."),
    "weapon_pistolxm3": ("Pistoletas XM3", "Modernus taktinis pistoletas."),
    # SMG
    "weapon_microsmg": ("Mikro SMG", "Kompaktiškas automatinis ginklas."),
    "weapon_smg": ("SMG", "Lengvas automatinis ginklas."),
    "weapon_smg_mk2": ("SMG Mk II", "Patobulintas SMG."),
    "weapon_assaultsmg": ("Šturminis SMG", "Agresyvesnis SMG variantas."),
    "weapon_combatpdw": ("Kovinis PDW", "Asmeninis gynybos ginklas."),
    "weapon_machinepistol": ("Tec-9", "Automatinis pistoletas."),
    "weapon_minismg": ("Mini SMG", "Labai kompaktiškas SMG."),
    "weapon_raycarbine": ("Unholy Hellbringer", "Eksperimentinis energijos karabinas."),
    # Shotguns
    "weapon_pumpshotgun": ("Pompinis šratinis", "Lygiavamzdinis šratinis."),
    "weapon_sawnoffshotgun": ("Nupjautvamzdis šratinis", "Trumpas vamzdis."),
    "weapon_assaultshotgun": ("Šturminis šratinis", "Automatinis šratinis."),
    "weapon_bullpupshotgun": ("Bullpup šratinis", "Kompaktiškas šratinis."),
    "weapon_musket": ("Muškieta", "Senovinis lygiavamzdis šautuvas."),
    "weapon_heavyshotgun": ("Sunkusis šratinis", "Galingas šratinis."),
    "weapon_dbshotgun": ("Dvivamzdis šratinis", "Du lygiagretūs vamzdžiai."),
    "weapon_autoshotgun": ("Automatinis šratinis", "Greito šaudymo šratinis."),
    "weapon_pumpshotgun_mk2": ("Pompinis šratinis Mk II", "Patobulintas pompinis šratinis."),
    "weapon_combatshotgun": ("Kovinis šratinis", "Taktinis šratinis."),
    # Rifles
    "weapon_assaultrifle": ("Šturminis šautuvas", "Automatinis šautuvas."),
    "weapon_assaultrifle_mk2": ("Šturminis šautuvas Mk II", "Patobulintas šturminis šautuvas."),
    "weapon_carbinerifle": ("Karabinas", "Lengvas automatinis šautuvas."),
    "weapon_carbinerifle_mk2": ("Karabinas Mk II", "Patobulintas karabinas."),
    "weapon_advancedrifle": ("Pažangus šautuvas", "Modernus automatinis šautuvas."),
    "weapon_specialcarbine": ("Specialus karabinas", "Universalus kovinis šautuvas."),
    "weapon_bullpuprifle": ("Bullpup šautuvas", "Kompaktiškas automatinis šautuvas."),
    "weapon_compactrifle": ("Kompaktiškas šautuvas", "Sumažintas šturminis šautuvas."),
    "weapon_specialcarbine_mk2": ("Specialus karabinas Mk II", "Patobulintas karabinas."),
    "weapon_bullpuprifle_mk2": ("Bullpup šautuvas Mk II", "Patobulintas bullpup šautuvas."),
    "weapon_militaryrifle": ("Karinis šautuvas", "Karinis automatinis šautuvas."),
    # MG
    "weapon_mg": ("Kulkosvaidis", "Automatinis kulkosvaidis."),
    "weapon_combatmg": ("Kovinis kulkosvaidis", "Taktinis kulkosvaidis."),
    "weapon_gusenberg": ("Thompson SMG", "Klasikinis automatinis šautuvas."),
    "weapon_combatmg_mk2": ("Kovinis kulkosvaidis Mk II", "Patobulintas kulkosvaidis."),
    # Sniper
    "weapon_sniperrifle": ("Snaiperio šautuvas", "Tikslus tolimo nuotolio šautuvas."),
    "weapon_heavysniper": ("Sunkusis snaiperis", "Labai galingas snaiperio šautuvas."),
    "weapon_marksmanrifle": ("Taikliojo šaulio šautuvas", "Tikslus pusiau automatinis šautuvas."),
    "weapon_remotesniper": ("Nuotolinis snaiperis", "Valdomas snaiperio šautuvas."),
    "weapon_heavysniper_mk2": ("Sunkusis snaiperis Mk II", "Patobulintas snaiperis."),
    "weapon_marksmanrifle_mk2": ("Taikliojo šaulio šautuvas Mk II", "Patobulintas taikliojo šaulio šautuvas."),
    # Heavy
    "weapon_rpg": ("Granatsvaidis RPG", "Raketinis granatsvaidis."),
    "weapon_grenadelauncher": ("Granatsvaidis", "Granatų paleidimo įtaisas."),
    "weapon_grenadelauncher_smoke": ("Dūminis granatsvaidis", "Dūminių granatų paleidiklis."),
    "weapon_minigun": ("Miniganas", "Daugiavamzdis kulkosvaidis."),
    "weapon_firework": ("Fejerverkų paleidiklis", "Fejerverkų šaudymo įtaisas."),
    "weapon_railgun": ("Relinis patranka", "Elektromagnetinis ginklas."),
    "weapon_railgunxm3": ("Relinis patranka XM3", "Eksperimentinė relinė patranka."),
    "weapon_hominglauncher": ("Nukreipiamasis raketinis", "Raketa seka taikinį."),
    "weapon_compactlauncher": ("Kompaktiškas granatsvaidis", "Mažas granatų paleidiklis."),
    "weapon_rayminigun": ("Widowmaker", "Eksperimentinis energijos miniganas."),
    # Throwables
    "weapon_grenade": ("Granata", "Rankinė sprogstamoji granata."),
    "weapon_bzgas": ("BZ dujos", "Nesąmoningumą sukeliančios dujos."),
    "weapon_molotov": ("Molotovo kokteilis", "Degusis butelis su dagtimi."),
    "weapon_stickybomb": ("C4", "Priklijuojamasis sprogmuo."),
    "weapon_proxmine": ("Artumo mina", "Sprogsta priartėjus."),
    "weapon_snowball": ("Sniego gniūžtė", "Sniego kamuoliukas."),
    "weapon_pipebomb": ("Vamzdžio bomba", "Laisvai pagaminta bomba."),
    "weapon_ball": ("Kamuolys", "Sportinis kamuolys."),
    "weapon_smokegrenade": ("Dūminė granata", "Dūmų granata maskavimui."),
    "weapon_flare": ("Signalinė raketa", "Šviesos ir signalizavimo priemonė."),
    # Misc weapons
    "weapon_petrolcan": ("Benzino kanistras", "Metalinis degalų kanistras."),
    "weapon_fireextinguisher": ("Gesintuvas", "Nešiojamas gaisro gesintuvas."),
    "weapon_hazardcan": ("Pavojingų medžiagų kanistras", "Specialus cheminių medžiagų indas."),
    # Attachments - generic pattern handled below
    "clip_attachment": ("Dėtuvė", "Papildoma ginklo dėtuvė."),
    "drum_attachment": ("Būgninė dėtuvė", "Didelės talpos būgninė dėtuvė."),
    "flashlight_attachment": ("Ginklo žibintuvėlis", "Taktinis žibintuvėlis ant ginklo."),
    "suppressor_attachment": ("Aušintuvas", "Ginklo garso slopintuvas."),
    "smallscope_attachment": ("Mažas taikiklis", "Optinis taikiklis trumpam nuotoliui."),
    "medscope_attachment": ("Vidutinis taikiklis", "Optinis taikiklis vidutiniam nuotoliui."),
    "largescope_attachment": ("Didelis taikiklis", "Optinis taikiklis tolimam šaudymui."),
    "holoscope_attachment": ("Holo taikiklis", "Holografinis taikiklis."),
    "advscope_attachment": ("Pažangus taikiklis", "Patobulintas optinis taikiklis."),
    "nvscope_attachment": ("Naktinio matymo taikiklis", "Taikiklis su naktiniu matymu."),
    "thermalscope_attachment": ("Termovizorinis taikiklis", "Šilumos vaizdo taikiklis."),
    "barrel_attachment": ("Vamzdis", "Pakeičiamas ginklo vamzdis."),
    "grip_attachment": ("Rankena", "Ergonominė ginklo rankena."),
    "comp_attachment": ("Kompensatorius", "Atatrankos kompensatorius."),
    "luxuryfinish_attachment": ("Prabangus apdailos rinkinys", "Dekoratyvi ginklo apdaila."),
    # Ammo
    "pistol_ammo": ("Pistoletų kulkos", "Kulkos pistoletams."),
    "pistolammo": ("Pistoletų kulkos (senas)", "Suderinamumas su senesniais skriptais."),
    "rifle_ammo": ("Šautuvų kulkos", "Kulkos šautuvams."),
    "rifleammo": ("Šautuvų kulkos (senas)", "Suderinamumas su senesniais skriptais."),
    "smg_ammo": ("SMG kulkos", "Kulkos automatiniais ginklams."),
    "smgammo": ("SMG kulkos (senas)", "Suderinamumas su senesniais skriptais."),
    "shotgun_ammo": ("Šratinio kulkos", "Kulkos šratiniams."),
    "mg_ammo": ("Kulkosvaidžio kulkos", "Kulkos kulkosvaidžiams."),
    "snp_ammo": ("Snaiperio kulkos", "Kulkos snaiperio šautuvams."),
    "emp_ammo": ("EMP kulkos", "Kulkos EMP paleidikliui."),
    # Cards
    "id_card": ("Asmens tapatybės kortelė", "Oficialus asmens dokumentas."),
    "driver_license": ("Vairuotojo pažymėjimas (EN)", "Leidimas vairuoti transportą."),
    "lawyerpass": ("Advokato pažymėjimas", "Leidimas atstovauti klientą teisme."),
    "weaponlicense": ("Ginklo licencija", "Leidimas turėti ginklą."),
    "bank_card": ("Banko kortelė", "Prieiga prie bankomato."),
    "security_card_01": ("Apsaugos kortelė A", "Prieigos kortelė."),
    "security_card_02": ("Apsaugos kortelė B", "Prieigos kortelė."),
    # Alcohol
    "beer": ("Alus", "Šaltas alus."),
    "whiskey": ("Viskis", "Stiprus alkoholinis gėrimas."),
    "vodka": ("Vodka", "Stiprus spiritinis gėrimas."),
    "grape": ("Vynuogės", "Šviežios vynuogės."),
    "wine": ("Vynas", "Vynas vakariniam vakarėliui."),
    "grapejuice": ("Vynuogių sultys", "Natūralios vynuogių sultys."),
    # Drugs (legacy QB)
    "joint": ("Suktinė", "Sukta kanapės cigarete."),
    "cokebaggy": ("Kokaino maišelis", "Mažas kokaino pakelis."),
    "crack_baggy": ("Krako maišelis", "Mažas krako pakelis."),
    "xtcbaggy": ("Ekstazi maišelis", "Tablečių pakelis."),
    "coke_brick": ("Kokaino plyta", "Didelis kokaino blokas."),
    "weed_brick": ("Kanapių plyta", "1 kg kanapių blokas."),
    "coke_small_brick": ("Kokaino paketas", "Mažesnis kokaino paketas."),
    "oxy": ("Receptiniai oksikodonai", "Nurašytas vaistų pakuotės etiketė."),
    "meth": ("Metamfetamino maišelis", "Mažas metamfetamino pakelis."),
    "rolling_paper": ("Sukimo popierius", "Popierius tabakui ar kanapėms sukti."),
    "weed_whitewidow": ("White Widow 2 g", "2 g White Widow kanapių."),
    "weed_skunk": ("Skunk 2 g", "2 g Skunk kanapių."),
    "weed_purplehaze": ("Purple Haze 2 g", "2 g Purple Haze kanapių."),
    "weed_ogkush": ("OG Kush 2 g", "2 g OG Kush kanapių."),
    "weed_amnesia": ("Amnesia 2 g", "2 g Amnesia kanapių."),
    "weed_ak47": ("AK-47 2 g", "2 g AK-47 kanapių."),
    "weed_whitewidow_seed": ("White Widow sėkla", "Kanapių sėkla."),
    "weed_skunk_seed": ("Skunk sėkla", "Kanapių sėkla."),
    "weed_purplehaze_seed": ("Purple Haze sėkla", "Kanapių sėkla."),
    "weed_ogkush_seed": ("OG Kush sėkla", "Kanapių sėkla."),
    "weed_amnesia_seed": ("Amnesia sėkla", "Kanapių sėkla."),
    "weed_ak47_seed": ("AK-47 sėkla", "Kanapių sėkla."),
    "empty_weed_bag": ("Tuščias maišelis", "Mažas tuščias pakavimo maišelis."),
    "weed_nutrition": ("Augalų trąšos", "Trąšos augalams."),
    # Materials
    "plastic": ("Plastikas", "Perdirbamas plastiko granulės."),
    "metalscrap": ("Metalo laužas", "Metalo fragmentai perdirbimui."),
    "copper": ("Varis", "Vario gabalas."),
    "aluminum": ("Aliuminis", "Aliuminio gabalas."),
    "aluminumoxide": ("Aliuminio milteliai", "Smulkus aliuminio miltelis."),
    "iron": ("Geležis", "Geležies gabalas."),
    "ironoxide": ("Geležies milteliai", "Smulkus geležies miltelis."),
    # Tools
    "lockpick": ("Visraktis", "Durų ar spynų atidarymui."),
    "advancedlockpick": ("Pažangus visraktis", "Sudėtingesnėms spynoms."),
    "electronickit": ("Elektronikos rinkinys", "Komponentai elektronikai."),
    "gatecrack": ("Vartų įsilaužimo programa", "Programinė įranga tvoroms."),
    "thermite": ("Termitas", "Labai karštas degantis mišinys."),
    "trojan_usb": ("Trojos arklio USB", "Kenkėjiška programinė įranga."),
    "screwdriverset": ("Įrankių rinkinys", "Atsuktuvų ir įrankių komplektas."),
    "drill": ("Grąžtas", "Elektrinis grąžtas."),
    "tow_chain": ("Vilkimo grandinė", "Sunki grandinė tempimui."),
    "basic_tablet": ("Paprastas įsilaužimo planšetė", "Pradinio lygio įsilaužimo įrenginys."),
    "advanced_tablet": ("Pažangus įsilaužimo planšetė", "Patobulintas įsilaužimo įrenginys."),
    "military_tablet": ("Karinis įsilaužimo planšetė", "Karinės klasės įrenginys."),
    "basic_flashdrive": ("Paprasta USB atmintinė", "Duomenų laikmena."),
    "encrypted_flashdrive": ("Šifruota USB atmintinė", "Apsaugota duomenų laikmena."),
    "military_flashdrive": ("Karinė USB atmintinė", "Didelės talpos saugi laikmena."),
    "spray_can": ("Purškimo balionėlis", "Grafičio purškimui."),
    "graffiti_cleaner": ("Grafičio valiklis", "Nuvalo gatvės piešinius."),
    # Vehicle
    "nitrous": ("Azoto oksidas (NOS)", "Pagreičio sistema transportui."),
    "repairkit": ("Remonto rinkinys", "Įrankiai transporto remontui."),
    "advancedrepairkit": ("Pažangus remonto rinkinys", "Pilnesnis remonto komplektas."),
    "cleaningkit": ("Valymo rinkinys", "Transporto išorės valymui."),
    "tunerlaptop": ("Tiuningo nešiojamasis", "Variklio valdymo kompiuteris."),
    "harness": ("Lenktynių diržai", "Saugos diržai lenktynėms."),
    "jerry_can": ("Kanistras 20 l", "Kanistras su degalais."),
    "tirerepairkit": ("Padangų remonto rinkinys", "Įrankiai padangoms taisyti."),
    "veh_toolbox": ("Įrankių dėžė", "Transporto būklės tikrinimui."),
    "veh_armor": ("Šarvai", "Transporto šarvinimas."),
    "veh_brakes": ("Stabdžiai", "Stabdžių patobulinimas."),
    "veh_engine": ("Variklis", "Variklio patobulinimas."),
    "veh_suspension": ("Pakaba", "Pakabos patobulinimas."),
    "veh_transmission": ("Pavarų dėžė", "Pavarų dėžės patobulinimas."),
    "veh_turbo": ("Turbo", "Turbo kompresoriaus montavimas."),
    "veh_interior": ("Salonas", "Salono patobulinimas."),
    "veh_exterior": ("Eksterjeras", "Išorės patobulinimas."),
    "veh_wheels": ("Ratai", "Ratų patobulinimas."),
    "veh_neons": ("Neonai", "Neoninių šviesų montavimas."),
    "veh_xenons": ("Ksenonai", "Ksenoninių žibintų montavimas."),
    "veh_tint": ("Tamsinimas", "Langų tamsinimo plėvelė."),
    "veh_plates": ("Numeriai", "Registracijos numeriai."),
    "engine_kit": ("Variklio patobulinimo rinkinys", "Meistrų pagamintas variklio komplektas."),
    "brakes_kit": ("Stabdžių patobulinimo rinkinys", "Meistrų pagamintas stabdžių komplektas."),
    "transmission_kit": ("Pavarų dėžės patobulinimo rinkinys", "Meistrų pagamintas pavarų komplektas."),
    "suspension_kit": ("Pakabos patobulinimo rinkinys", "Meistrų pagamintas pakabos komplektas."),
    "armor_kit": ("Šarvų patobulinimo rinkinys", "Meistrų pagamintas šarvų komplektas."),
    "turbo_kit": ("Turbo patobulinimo rinkinys", "Meistrų pagamintas turbo komplektas."),
    # Medication
    "firstaid": ("Pirmosios pagalbos rinkinys", "Pagalba sužeistam asmeniui."),
    "bandage": ("Tvarstis", "Žaizdos aptvarstymui."),
    "ifaks": ("Individualus medicininis rinkinys", "Gydymui ir streso mažinimui."),
    "painkillers": ("Nuskausminamieji", "Vaistai nuo skausmo."),
    "walkstick": ("Lazda", "Pagalbinė vaikščiojimo lazda."),
    # Communication
    "phone": ("Telefonas", "Išmanusis telefonas."),
    "radio": ("Radijas", "Ryšio radijo stotelė."),
    "iphone": ("iPhone", "Brangus išmanusis telefonas."),
    "samsungphone": ("Samsung S10", "Brangus išmanusis telefonas."),
    "laptop": ("Nešiojamasis kompiuteris", "Brangus nešiojamasis kompiuteris."),
    "tablet": ("Planšetė", "Brangi planšetė."),
    "gang_tablet": ("Gaujos planšetė", "Gaujų valdymo įrenginys."),
    "fitbit": ("Fitbit", "Veiklos stebėjimo apyrankė."),
    "radioscanner": ("Radijo skeneris", "Policijos dažnių klausymui."),
    "pinger": ("Lokatorius", "Vietos nustatymo įtaisas."),
    "cryptostick": ("Kripto atmintinė", "Skaitmeninės valiutos laikmena."),
    # Jewelry
    "rolex": ("Auksinis laikrodis", "Brangus auksinis laikrodis."),
    "diamond_ring": ("Deimantinis žiedas", "Brangus deimantinis žiedas."),
    "goldchain": ("Auksinė grandinėlė", "Brangi auksinė grandinėlė."),
    "tenkgoldchain": ("10K auksinė grandinėlė", "10 karatų auksinė grandinėlė."),
    "goldbar": ("Aukso luitas", "Brangus aukso luitas."),
    # Police
    "handcuffs": ("Antrankiai", "Asmenų sulaikymui."),
    "police_stormram": ("Avarinis taranas", "Durų pramušimui."),
    "empty_evidence_bag": ("Tuščias įrodymų maišelis", "Įrodymams saugoti."),
    "filled_evidence_bag": ("Įrodymų maišelis", "Užpildytas įrodymų maišelis."),
    # Fireworks
    "firework1": ("Fejerverkas 2Brothers", "Fejerverkas."),
    "firework2": ("Fejerverkas Poppelers", "Fejerverkas."),
    "firework3": ("Fejerverkas WipeOut", "Fejerverkas."),
    "firework4": ("Fejerverkas Weeping Willow", "Fejerverkas."),
    # Sea
    "dendrogyra_coral": ("Koralas Dendrogyra", "Piliarinis koralas."),
    "antipatharia_coral": ("Koralas Antipatharia", "Juodasis koralas."),
    "diving_gear": ("Nardymo įranga", "Deguonies balionas ir rebreather."),
    "diving_fill": ("Nardymo balionas", "Deguonies baliono pildymas."),
    # Other
    "casinochips": ("Kazino žetonai", "Žetonai lošimams kazino."),
    "stickynote": ("Lipni užrašų lapelis", "Trumpiems užrašams."),
    "moneybag": ("Pinigų maišas", "Maišas su grynaisiais."),
    "cash": ("Pinigai", "Grynieji pinigai. 1 vnt. = $1, sinchronizuota su pinigine."),
    "parachute": ("Parašiutas", "Šuoliui iš aukščio."),
    "binoculars": ("Žiūronai", "Toli matymui."),
    "lighter": ("Žiebtuvėlis", "Ugniai uždegti."),
    "certificate": ("Sertifikatas", "Nuosavybės ar kvalifikacijos įrodymas."),
    "markedbills": ("Pažymėti pinigai", "Įtartinos kilmės banknotai."),
    "labkey": ("Raktas", "Raktas nuo spynos."),
    "printerdocument": ("Dokumentas", "Atspausdintas dokumentas."),
    "newscam": ("Naujienų kamera", "Kamera reportažams."),
    "newsmic": ("Naujienų mikrofonas", "Mikrofonas reportažams."),
    "newsbmic": ("Garso malūnas", "Kryptinis mikrofonas reportažams."),
    "item_bench": ("Darbo stalas", "Stalas daiktams gaminti."),
    "attachment_bench": ("Priedų darbo stalas", "Stalas ginklų priedams gaminti."),
    "fish_clean": ("Žuvis (filė)", "Apdorota žuvis pardavimui."),
}

# Camo / muzzle / tint attachments - pattern translations
CAMO_LABELS = {
    "digicamo_attachment": ("Skaitmeninis kamufliažas", "Skaitmeninio kamufliažo danga ginklui."),
    "brushcamo_attachment": ("Teptuko kamufliažas", "Teptuko rašto kamufliažo danga."),
    "woodcamo_attachment": ("Miško kamufliažas", "Miškinio kamufliažo danga."),
    "skullcamo_attachment": ("Kaukolės kamufliažas", "Kaukolės rašto danga."),
    "sessantacamo_attachment": ("Sessanta Nove kamufliažas", "Sessanta Nove rašto danga."),
    "perseuscamo_attachment": ("Perseus kamufliažas", "Perseus rašto danga."),
    "leopardcamo_attachment": ("Leopardo kamufliažas", "Leopardo rašto danga."),
    "zebracamo_attachment": ("Zebro kamufliažas", "Zebro rašto danga."),
    "geocamo_attachment": ("Geometrinis kamufliažas", "Geometrinio rašto danga."),
    "boomcamo_attachment": ("Boom kamufliažas", "Boom rašto danga."),
    "patriotcamo_attachment": ("Patriot kamufliažas", "Patriot rašto danga."),
}
LT.update(CAMO_LABELS)

MUZZLE_LABELS = {
    "flat_muzzle_brake": ("Plokščias stabdiklis", "Plokščias vamzdžio stabdiklis."),
    "tactical_muzzle_brake": ("Taktinis stabdiklis", "Taktinis vamzdžio stabdiklis."),
    "fat_end_muzzle_brake": ("Storas stabdiklis", "Storo galo stabdiklis."),
    "precision_muzzle_brake": ("Tikslumo stabdiklis", "Tikslumo vamzdžio stabdiklis."),
    "heavy_duty_muzzle_brake": ("Sunkusis stabdiklis", "Sunkios klasės stabdiklis."),
    "slanted_muzzle_brake": ("Pasviręs stabdiklis", "Pasviręs vamzdžio stabdiklis."),
    "split_end_muzzle_brake": ("Skaldytas stabdiklis", "Skaldyto galo stabdiklis."),
    "squared_muzzle_brake": ("Kvadratinis stabdiklis", "Kvadratinio galo stabdiklis."),
    "bellend_muzzle_brake": ("Varpinis stabdiklis", "Varpinio galo stabdiklis."),
}
LT.update(MUZZLE_LABELS)

TINT_BASE = {
    0: ("Standartinė spalva", "Juoda / standartinė ginklo spalva."),
    1: ("Žalia spalva", "Žalias ginklo dažymas."),
    2: ("Auksinė spalva", "Auksinis ginklo dažymas."),
    3: ("Rožinė spalva", "Rožinis ginklo dažymas."),
    4: ("Karinė spalva", "Karinio stiliaus dažymas."),
    5: ("LSPD spalva", "Policijos departamento dažymas."),
    6: ("Oranžinė spalva", "Oranžinis ginklo dažymas."),
    7: ("Platinos spalva", "Platininis ginklo dažymas."),
}

MK2_TINT_NAMES = [
    "Klasikinė juoda", "Klasikinė pilka", "Klasikinė dvispalvė", "Klasikinė balta",
    "Klasikinė smėlio", "Klasikinė žalia", "Klasikinė mėlyna", "Klasikinė žemės",
    "Klasikinė ruda ir juoda", "Raudonas kontrastas", "Mėlynas kontrastas",
    "Geltonas kontrastas", "Oranžinis kontrastas", "Ryški rožinė", "Ryški violetinė ir geltona",
    "Ryškiai oranžinė", "Ryški žalia ir violetinė", "Ryškūs raudoni akcentai",
    "Ryškūs žali akcentai", "Ryškūs žydri akcentai", "Ryškūs geltoni akcentai",
    "Ryški raudona ir balta", "Ryški mėlyna ir balta", "Metalinė auksinė",
    "Metalinė platina", "Metalinė pilka ir alyvinė", "Metalinė violetinė ir žalia",
    "Metalinė raudona", "Metalinė žalia", "Metalinė mėlyna", "Metalinė balta ir žydra",
    "Metalinė oranžinė ir geltona", "Metalinė raudona ir geltona",
]

UPGRADE_TIERS = {
    "engine_upgrade_": ("Variklio patobulinimas", "Variklio patobulinimo dalis."),
    "brakes_upgrade_": ("Stabdžių patobulinimas", "Stabdžių patobulinimo dalis."),
    "transmission_upgrade_": ("Pavarų dėžės patobulinimas", "Pavarų dėžės patobulinimo dalis."),
    "suspension_upgrade_": ("Pakabos patobulinimas", "Pakabos patobulinimo dalis."),
    "armor_upgrade_": ("Šarvų patobulinimas", "Šarvų patobulinimo dalis."),
}

ROMAN = {1: "I", 2: "II", 3: "III", 4: "IV", 5: "V"}


def roman_tier(key: str) -> str | None:
    for prefix, (base, _) in UPGRADE_TIERS.items():
        if key.startswith(prefix):
            num = key.replace(prefix, "")
            if num.isdigit():
                return f"{base} {ROMAN.get(int(num), num)}"
    return None


def tint_translation(key: str):
    m = re.match(r"weapontint_mk2_(\d+)", key)
    if m:
        idx = int(m.group(1))
        name = MK2_TINT_NAMES[idx] if idx < len(MK2_TINT_NAMES) else f"Mk II dažymas {idx}"
        return (f"{name} spalva", f"{name} — Mk II ginklų dažymas.")
    m = re.match(r"weapontint_(\d+)", key)
    if m:
        idx = int(m.group(1))
        label, desc = TINT_BASE.get(idx, ("Spalva", "Ginklo dažymas."))
        return (label, desc)
    return None


def fix_fish_clean():
    return ("Žuvis (filė)", "Apdorota žuvis pardavimui.")


def apply():
    text = ITEMS_PATH.read_text(encoding="utf-8")
    changed = 0

    def repl_block(m):
        nonlocal changed
        key = m.group(1)
        block = m.group(0)
        if key in LT:
            label, desc = LT[key]
        elif (t := tint_translation(key)):
            label, desc = t
        elif (tier := roman_tier(key)):
            label = tier
            desc = UPGRADE_TIERS[[p for p in UPGRADE_TIERS if key.startswith(p)][0]][1]
        else:
            return block

        new_block = re.sub(r"label = '[^']*'", f"label = '{label}'", block, count=1)
        new_block = re.sub(r'description = \'[^\']*\'', f"description = '{desc}'", new_block, count=1)
        if new_block != block:
            changed += 1
        return new_block

    pattern = re.compile(
        r"^\s*(?:\['([^']+)'\]|(\w+))\s*=\s*\{[^}]*?description = '[^']*'[^}]*?\},?",
        re.M | re.S,
    )

    def repl_line(m):
        nonlocal changed
        key = m.group(1) or m.group(2)
        block = m.group(0)
        if key in LT:
            label, desc = LT[key]
        elif (t := tint_translation(key)):
            label, desc = t
        elif (tier := roman_tier(key)):
            label = tier
            prefix = [p for p in UPGRADE_TIERS if key.startswith(p)][0]
            desc = UPGRADE_TIERS[prefix][1]
        else:
            return block
        new_block = re.sub(r"label = '[^']*'", f"label = '{label}'", block, count=1)
        new_block = re.sub(r"description = '[^']*'", f"description = '{desc}'", new_block, count=1)
        if new_block != block:
            changed += 1
        return new_block

    # Line-by-line safer for this lua file structure
    lines = text.splitlines(keepends=True)
    out = []
    i = 0
    while i < len(lines):
        line = lines[i]
        km = re.match(r"^\s*(?:\['([^']+)'\]|(\w+))\s*=\s*\{", line)
        if km:
            key = km.group(1) or km.group(2)
            block_lines = [line]
            i += 1
            while i < len(lines) and not lines[i].strip().endswith("},") and not (lines[i].strip().endswith("}") and "description" in "".join(block_lines)):
                block_lines.append(lines[i])
                i += 1
            if i < len(lines):
                block_lines.append(lines[i])
                i += 1
            block = "".join(block_lines)
            if key in LT or tint_translation(key) or roman_tier(key):
                if key in LT:
                    label, desc = LT[key]
                elif (t := tint_translation(key)):
                    label, desc = t
                else:
                    label = roman_tier(key)
                    prefix = [p for p in UPGRADE_TIERS if key.startswith(p)][0]
                    desc = UPGRADE_TIERS[prefix][1]
                nb = re.sub(r"label = '[^']*'", f"label = '{label}'", block, count=1)
                nb = re.sub(r'label = "[^"]*"', f'label = "{label}"', nb, count=1)
                nb = re.sub(r"description = '[^']*'", f"description = '{desc}'", nb, count=1)
                nb = re.sub(r'description = "[^"]*"', f'description = "{desc}"', nb, count=1)
                if nb != block:
                    changed += 1
                out.append(nb)
                continue
        out.append(line)
        i += 1

    ITEMS_PATH.write_text("".join(out), encoding="utf-8")
    print(f"Updated {changed} items in {ITEMS_PATH}")


if __name__ == "__main__":
    apply()
