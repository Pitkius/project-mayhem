MLO folder structure (single repository):

- [mlo_pack_1] -> first MLO group
- [mlo_pack_2] -> second MLO group

Place each MLO resource as its own folder (with fxmanifest.lua/__resource.lua) inside one of these groups.

Example:
resources/[mlo]/[mlo_pack_1]/cfx-gabz-mrpd/fxmanifest.lua
resources/[mlo]/[mlo_pack_2]/my_custom_mlo/fxmanifest.lua

Server cfg uses:
ensure [mlo]

