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
   [mlo_pack_1] — MRPD, Pillbox, Tuners, Davis, Cat Cafe, Bennys, Hayes, Diner...
   [mlo_pack_2] — Park Ranger, Paleto/Sandy PD, Pacific, Hub, Prison, Pink Cage...

5. Po įkėlimo (2026-05-24 iš Downloads):
   - [mlo_pack_3]/druglabs
   - [mlo_pack_3]/c-hunting_shop
   - [mlo_pack_3]/dynasty8
   - [mlo_pack_3]/sc_secret_drug
   - Restart serveris arba: ensure [mlo]
   - Parašyk Cursor / dev'ui MLO aplankų pavadinimus (pvz. cfx-gabz-prison)
   - Tada bus pridėti blip'ai (fivempro_gabz_blips) ir NPC koordinatės (jobs, outdoors).

Struktūros pavyzdys:
   resources/[mlo]/[mlo_pack_1]/cfx-gabz-mrpd/fxmanifest.lua
   resources/[mlo]/[mlo_pack_3]/tavo-naujas-mlo/fxmanifest.lua
