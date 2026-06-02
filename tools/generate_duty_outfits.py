#!/usr/bin/env python3
"""Parse Durty Cloth shop.meta files and emit Config.DutyOutfits Lua tables."""

from __future__ import annotations

import re
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
EXTRACT = ROOT / "_clothing_extract"

COMP_MAP = {
    "PV_COMP_LOWR": 4,
    "PV_COMP_FEET": 6,
    "PV_COMP_JBIB": 11,
    "PV_COMP_ACCS": 8,
    "PV_COMP_UPPR": 3,
    "PV_COMP_TASK": 9,
    "PV_COMP_TEEF": 7,
    "PV_COMP_DECL": 10,
    "PV_COMP_BERD": 1,
    "PV_COMP_HAND": 5,
    "PV_COMP_HAIR": 2,
    "PV_COMP_HEAD": 0,
}

UNIFORM_PARTS = {3, 4, 6, 7, 8, 11}
VEST_PART = 9

TEX_LETTERS = "abcdefghijklmnopqrstuvwxyz"


def parse_shop_meta(path: Path) -> tuple[str, list[dict[str, Any]]]:
    text = path.read_text(encoding="utf-8", errors="replace")
    dlc_match = re.search(r"<dlcName>([^<]+)</dlcName>", text)
    dlc = dlc_match.group(1).strip() if dlc_match else path.stem

    items: list[dict[str, Any]] = []
    for block in re.findall(r"<Item>(.*?)</Item>", text, re.DOTALL):
        comment = ""
        m = re.search(r"<!--\s*(.*?)\s*-->", block)
        if m:
            comment = m.group(1).strip()

        def tag(name: str, default: str = "0") -> str:
            m2 = re.search(rf"<{name}\s+value=\"([^\"]*)\"", block)
            return m2.group(1) if m2 else default

        def tag_text(name: str, default: str = "") -> str:
            m3 = re.search(rf"<{name}>([^<]*)</{name}>", block)
            return m3.group(1).strip() if m3 else default

        comp_type = tag_text("eCompType", "") or tag("eCompType", "")
        if comp_type not in COMP_MAP:
            continue

        items.append(
            {
                "comp": COMP_MAP[comp_type],
                "draw": int(tag("localDrawableIndex", "0")),
                "tex": int(tag("textureIndex", "0")),
                "comment": comment,
            }
        )
    return dlc, items


def tex_label(tex: int) -> str:
    if tex < len(TEX_LETTERS):
        return TEX_LETTERS[tex].upper()
    return str(tex + 1)


def pick_lowr_tex(lowr_items: list[dict], tex: int) -> tuple[int, int]:
    same = [i for i in lowr_items if i["draw"] == 0 and i["tex"] == tex]
    if same:
        return 0, tex
    if lowr_items:
        first = sorted(lowr_items, key=lambda x: (x["draw"], x["tex"]))[0]
        return first["draw"], first["tex"]
    return 0, 0


def pick_feet(feet_items: list[dict]) -> tuple[int, int]:
    if feet_items:
        f = sorted(feet_items, key=lambda x: (x["draw"], x["tex"]))[0]
        return f["draw"], f["tex"]
    return 0, 0


def pick_accs(accs_items: list[dict], tex: int) -> tuple[int, int] | None:
    same = [i for i in accs_items if i["draw"] == 0 and i["tex"] == tex]
    if same:
        return 0, tex
    if accs_items:
        a = sorted(accs_items, key=lambda x: (x["draw"], x["tex"]))[0]
        return a["draw"], a["tex"]
    return None


def build_pack_outfits(pack_label: str, dlc: str, items: list[dict], gender: str) -> list[dict]:
    by_comp: dict[int, list[dict]] = {}
    for it in items:
        by_comp.setdefault(it["comp"], []).append(it)

    outfits: list[dict] = []
    jbib_items = sorted(by_comp.get(11, []), key=lambda x: (x["draw"], x["tex"]))
    lowr_items = by_comp.get(4, [])
    feet_items = by_comp.get(6, [])
    accs_items = by_comp.get(8, [])
    uppr_items = by_comp.get(3, [])
    task_items = sorted(by_comp.get(9, []), key=lambda x: (x["draw"], x["tex"]))
    teef_items = sorted(by_comp.get(7, []), key=lambda x: (x["draw"], x["tex"]))

    def comp_entry(draw: int, tex: int) -> dict:
        return {"collection": dlc, "draw": draw, "tex": tex}

    def make_components(spec: dict[int, tuple[int, int]]) -> dict:
        out = {}
        for comp_id, (d, t) in spec.items():
            out[comp_id] = comp_entry(d, t)
        return out

    seen_uniform: set[str] = set()
    for j in jbib_items:
        ld, lt = pick_lowr_tex(lowr_items, j["tex"])
        fd, ft = pick_feet(feet_items)
        spec: dict[int, tuple[int, int]] = {11: (j["draw"], j["tex"]), 4: (ld, lt), 6: (fd, ft)}
        acc = pick_accs(accs_items, j["tex"])
        if acc:
            spec[8] = acc
        if uppr_items:
            u = sorted(uppr_items, key=lambda x: (x["draw"], x["tex"]))[0]
            spec[3] = (u["draw"], u["tex"])
        key = f"u-j-{j['draw']}-{j['tex']}-{ld}-{lt}"
        if key in seen_uniform:
            continue
        seen_uniform.add(key)
        outfits.append(
            {
                "label": f"{pack_label} uniforma – viršus #{j['draw'] + 1} ({tex_label(j['tex'])})",
                "description": f"{gender} · be liemenės",
                "category": "uniform",
                "minGrade": 0,
                "armour": 0,
                "components": make_components(spec),
            }
        )

    for l in sorted(lowr_items, key=lambda x: (x["draw"], x["tex"])):
        if not jbib_items:
            continue
        j0 = sorted(jbib_items, key=lambda x: (x["draw"], x["tex"]))[0]
        fd, ft = pick_feet(feet_items)
        spec = {11: (j0["draw"], j0["tex"]), 4: (l["draw"], l["tex"]), 6: (fd, ft)}
        acc = pick_accs(accs_items, j0["tex"])
        if acc:
            spec[8] = acc
        key = f"u-l-{l['draw']}-{l['tex']}"
        if key in seen_uniform:
            continue
        seen_uniform.add(key)
        outfits.append(
            {
                "label": f"{pack_label} uniforma – kelnės #{l['draw'] + 1} ({tex_label(l['tex'])})",
                "description": f"{gender} · be liemenės",
                "category": "uniform",
                "minGrade": 0,
                "armour": 0,
                "components": make_components(spec),
            }
        )

    for a in sorted(accs_items, key=lambda x: (x["draw"], x["tex"])):
        if not jbib_items:
            continue
        j0 = sorted(jbib_items, key=lambda x: (x["draw"], x["tex"]))[0]
        ld, lt = pick_lowr_tex(lowr_items, j0["tex"])
        fd, ft = pick_feet(feet_items)
        spec = {11: (j0["draw"], j0["tex"]), 4: (ld, lt), 6: (fd, ft), 8: (a["draw"], a["tex"])}
        key = f"u-a-{a['draw']}-{a['tex']}"
        if key in seen_uniform:
            continue
        seen_uniform.add(key)
        outfits.append(
            {
                "label": f"{pack_label} uniforma – marškinėliai #{a['draw'] + 1} ({tex_label(a['tex'])})",
                "description": f"{gender} · be liemenės",
                "category": "uniform",
                "minGrade": 0,
                "armour": 0,
                "components": make_components(spec),
            }
        )

    for t in teef_items:
        if not jbib_items:
            continue
        j0 = sorted(jbib_items, key=lambda x: (x["draw"], x["tex"]))[0]
        ld, lt = pick_lowr_tex(lowr_items, j0["tex"])
        fd, ft = pick_feet(feet_items)
        spec = {11: (j0["draw"], j0["tex"]), 4: (ld, lt), 6: (fd, ft), 7: (t["draw"], t["tex"])}
        key = f"u-t-{t['draw']}-{t['tex']}"
        if key in seen_uniform:
            continue
        seen_uniform.add(key)
        outfits.append(
            {
                "label": f"{pack_label} uniforma – aksesuaras #{t['draw'] + 1} ({tex_label(t['tex'])})",
                "description": f"{gender} · be liemenės",
                "category": "uniform",
                "minGrade": 0,
                "armour": 0,
                "components": make_components(spec),
            }
        )

    for v in task_items:
        outfits.append(
            {
                "label": f"{pack_label} liemenė #{v['draw'] + 1} ({tex_label(v['tex'])})",
                "description": f"{gender} · balistinė liemenė (uždėk ant uniformos)",
                "category": "vest",
                "minGrade": 0,
                "armour": 100,
                "components": make_components({9: (v["draw"], v["tex"])}),
            }
        )

    return outfits


def merge_gender_outfits(packs: list[tuple[str, Path, str]]) -> list[dict]:
    """packs: (label, meta_path, gender_key male|female)"""
    merged: dict[str, dict] = {}
    for pack_label, meta_path, gender in packs:
        if not meta_path.exists():
            continue
        dlc, items = parse_shop_meta(meta_path)
        for o in build_pack_outfits(pack_label, dlc, items, gender):
            sig = f"{gender}|{o['category']}|{o['label']}"
            if sig not in merged:
                merged[sig] = {
                    "label": o["label"],
                    "description": o.get("description", ""),
                    "category": o["category"],
                    "minGrade": 0,
                    "armour": o.get("armour", 0),
                    "male": None,
                    "female": None,
                }
            merged[sig][gender] = o["components"]

    result = list(merged.values())
    result.sort(key=lambda x: (0 if x["category"] == "uniform" else 1, x["label"]))
    return result


def lua_components_table(comps: dict) -> str:
    lines = ["            components = {"]
    for comp_id in sorted(comps.keys()):
        c = comps[comp_id]
        lines.append(
            f"                [{comp_id}] = {{ collection = '{c['collection']}', draw = {c['draw']}, tex = {c['tex']} }},"
        )
    lines.append("            },")
    return "\n".join(lines)


def emit_lua(outfits: list[dict], var_name: str = "Config.DutyOutfits") -> str:
    lines = [
        "--- Tarnybinė apranga (addon kolekcijos – keisti tik per generate_duty_outfits.py)",
        f"{var_name} = {{",
    ]
    for o in outfits:
        has_m = o.get("male") is not None
        has_f = o.get("female") is not None
        if not has_m and not has_f:
            continue
        lines.append("    {")
        lines.append(f"        label = {lua_str(o['label'])},")
        if o.get("description"):
            lines.append(f"        description = {lua_str(o['description'])},")
        lines.append(f"        category = {lua_str(o['category'])},")
        lines.append("        minGrade = 0,")
        lines.append(f"        armour = {int(o.get('armour') or 0)},")
        if has_m:
            lines.append("        male = {")
            lines.append(lua_components_table(o["male"]))
            lines.append("        },")
        if has_f:
            lines.append("        female = {")
            lines.append(lua_components_table(o["female"]))
            lines.append("        },")
        lines.append("    },")
    lines.append("}")
    return "\n".join(lines)


def lua_str(s: str) -> str:
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'") + "'"


def main() -> None:
    pd_packs_m = [
        ("PD V2", EXTRACT / "pdv2" / "PDV2" / "mp_m_freemode_01_mp_m_pdv2_shop.meta", "male"),
        ("PD Vyrai", EXTRACT / "pdvyrai" / "pdvyrai" / "mp_m_freemode_01_mp_m_pdvyrai_shop.meta", "male"),
    ]
    pd_packs_f = [
        ("PD V2", EXTRACT / "pdv2" / "PDV2" / "mp_f_freemode_01_mp_f_pdv2_shop.meta", "female"),
        ("PD Vyrai", EXTRACT / "pdvyrai" / "pdvyrai" / "mp_f_freemode_01_mp_f_pdvyrai_shop.meta", "female"),
        ("PD Moterys", EXTRACT / "pdmot" / "pdmot" / "mp_f_freemode_01_mp_f_pdmot_shop.meta", "female"),
    ]
    gmp_packs_m = [
        ("GMP", EXTRACT / "gmp" / "medikai" / "mp_m_freemode_01_mp_m_eimas25medikai_shop.meta", "male"),
    ]
    gmp_packs_f = [
        ("GMP", EXTRACT / "gmp" / "medikai" / "mp_f_freemode_01_mp_f_eimas25medikai_shop.meta", "female"),
    ]

    pd_outfits = merge_gender_outfits(pd_packs_m + pd_packs_f)
    gmp_outfits = merge_gender_outfits(gmp_packs_m + gmp_packs_f)

    pd_lua = emit_lua(pd_outfits)
    gmp_lua = emit_lua(gmp_outfits)

    pd_cfg = ROOT / "resources" / "[local]" / "fivempro_ltpd" / "config_duty_outfits.lua"
    gmp_cfg = ROOT / "resources" / "[local]" / "fivempro_ambulance" / "config_duty_outfits.lua"
    pd_cfg.write_text(pd_lua + "\n", encoding="utf-8")
    gmp_cfg.write_text(gmp_lua + "\n", encoding="utf-8")

    print(f"PD outfits: {len(pd_outfits)} -> {pd_cfg}")
    print(f"GMP outfits: {len(gmp_outfits)} -> {gmp_cfg}")
    u_pd = sum(1 for o in pd_outfits if o["category"] == "uniform")
    v_pd = sum(1 for o in pd_outfits if o["category"] == "vest")
    u_gmp = sum(1 for o in gmp_outfits if o["category"] == "uniform")
    v_gmp = sum(1 for o in gmp_outfits if o["category"] == "vest")
    print(f"  PD uniform={u_pd} vest={v_pd}")
    print(f"  GMP uniform={u_gmp} vest={v_gmp}")


if __name__ == "__main__":
    main()
