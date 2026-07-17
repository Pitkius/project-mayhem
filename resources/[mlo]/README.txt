MLO folder structure (FIVEMPROJEKTAS)
=====================================

Server cfg jau turi:  ensure [mlo]
(Nereikia kiekvieno MLO rašyti atskirai į server.cfg.)

KUR DĖTI NAUJUS MLO (atsisiųstus)
---------------------------------

1) Sukurk aplanką (rekomenduojama naujiems Gabz / custom):

   resources/[mlo]/[mlo_pack_3]/

   Pilnas kelias Windows:

   C:\Users\pytka\Desktop\FIVEMPROJEKTAS\resources\[mlo]\[mlo_pack_3]\

2) Kiekvienas MLO = ATSKIRAS aplankas su fxmanifest.lua (arba __resource.lua):

   Pvz.:
   resources/[mlo]/[mlo_pack_3]/cfx-gabz-xxx/
       fxmanifest.lua   (arba __resource.lua)
       stream/          ( .ymap .ydr .ybn ... )

   NEDĖK taip (klaida — dvigubas aplankas):
   .../cfx-gabz-xxx/cfx-gabz-xxx/stream/

3) Gabz MLO paketai:
   - Jei dar nėra — būtinas cfx-gabz-mapdata (jau yra [mlo_pack_2]).
   - mapdata turi užsikrauti PIRMAS (FiveM dažnai loadina pagal abėcėlę;
     jei mapdata neveikia — pervadink į 00-cfx-gabz-mapdata arba ensure atskirai).

4) Seni pack'ai (jau projekte):
   [mlo_pack_1] — Pillbox, Tuners, Davis, Bennys, Hayes, Diner... (MRPD → dt_19_mrpd pack_3)
   [mlo_pack_2] — Park Ranger, Paleto/Sandy PD, Pacific, Hub, Prison, Pink Cage...
   [mlo_pack_3] — dt_19_mrpd (Mission Row PD), druglabs, dynasty8, weapon_warehouse...

5. Po įkėlimo (2026-05-24 iš Downloads):
   - [mlo_pack_3]/druglabs
   - [mlo_pack_3]/c-hunting_shop
   - [mlo_pack_3]/dynasty8
   - [mlo_pack_3]/sc_secret_drug
   - [mlo_pack_3]/sc1_29_motel (Davis Motel + 24/7)
   - [mlo_pack_3]/hid_weed_lab (Hidden Weed Lab — Davis id1_29; žolės supakavimas Cayo)
   - [mlo_pack_3]/dt_19_mrpd (Mission Row PD — pakeitė cfx-gabz-mrpd)
   - [mlo_pack_3]/weapon_warehouse (Ginklų sandėlis — Grapeseed/Paleto kelias ~-1143, 4944)
   - [mlo_pack_3]/diamond-casino-exterior + diamond-casino-interior (Diamond Casino MLO)
   - [mlo_pack_3]/jrbLa_Fuente_Blanca (La Fuente Blanca ranch interior — jrbMods)
   - Restart serveris arba: ensure [mlo]
   - Parašyk Cursor / dev'ui MLO aplankų pavadinimus (pvz. cfx-gabz-prison)
   - Tada bus pridėti blip'ai (mrp_gabz_blips) ir NPC koordinatės (jobs, outdoors).

Struktūros pavyzdys:
   resources/[mlo]/[mlo_pack_1]/cfx-gabz-mrpd/fxmanifest.lua
   resources/[mlo]/[mlo_pack_3]/tavo-naujas-mlo/fxmanifest.lua
