"""
Imports every map from the owner's readable pret/pokeemerald checkout.
Adapted from the original project's scripts/import_pret_maps.py, with no source changes.
Generated output (Nintendo/Game Freak IP, included by owner request):
  public/assets/emerald-world/maps/<MAP_ID>.under.png / .over.png
  public/assets/emerald-world/sprites/<name>.png
  src/data/emerald-world.generated.json

  python scripts/import-emerald-world.py [path/to/pokeemerald]

Layer rules come from pokeemerald's field_camera.c DrawMetatile():
  NORMAL  (0): bottom layer under sprites, top layer over sprites
  COVERED (1): both layers under sprites
  SPLIT   (2): bottom under, top over
"""
import json
import os
import re
import struct
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = Path(sys.argv[1]) if len(sys.argv)>1 else ROOT.parent / "pokemon-emerald-horizons" / "third-party" / "pokeemerald"
OUT_ASSETS = ROOT / "public" / "assets" / "emerald-world"
OUT_JSON = ROOT / "src" / "data" / "emerald-world.generated.json"


NUM_TILES_PRIMARY = 512
NUM_METATILES_PRIMARY = 512
NUM_PALS_PRIMARY = 6
TILE = 16


def read(path):
    return (SRC / path).read_text(encoding="utf8")


# ---------------------------------------------------------------- behaviors
def load_behaviors():
    names = {}
    body = re.search(r"enum\s*\{(.*?)\};", read("include/constants/metatile_behaviors.h"), re.S).group(1)
    value = -1
    for line in body.splitlines():
        line = line.split("//")[0].strip().rstrip(",")
        if not line.startswith("MB_"):
            continue
        if "=" in line:
            name, v = [x.strip() for x in line.split("=")]
            value = int(v, 0)
        else:
            name = line
            value += 1
        names[value] = name
    return names


BEHAVIORS = load_behaviors()


def classify(behavior):
    """-> grid char: '_' walkable, '"' tall grass (encounters), '#' solid, 'W' water"""
    name = BEHAVIORS.get(behavior, "MB_NORMAL")
    if name in ("MB_TALL_GRASS", "MB_LONG_GRASS", "MB_LONG_GRASS_SOUTH_EDGE", "MB_ASHGRASS"):
        return '"'
    if "WATER" in name and "DOOR" not in name and "ARROW" not in name:
        return "W"
    if name.startswith(("MB_IMPASSABLE", "MB_JUMP", "MB_WATERFALL")) or name in ("MB_SECRET_BASE_WALL",):
        return "#"
    return "_"


# ---------------------------------------------------------------- tilesets
def snake(name):
    return re.sub(r"(?<!^)(?=[A-Z])", "_", name).lower()


def find_tileset_dir(sym):
    base = snake(sym.replace("gTileset_", ""))
    for kind in ("primary", "secondary"):
        p = SRC / "data" / "tilesets" / kind / base
        if p.exists():
            return p
    if base.startswith("secret_base_"):
        p = SRC / "data/tilesets/secondary/secret_base" / base.removeprefix("secret_base_")
        if p.exists(): return p
    raise FileNotFoundError(sym)


def read_pal(path):
    lines = path.read_text().split()
    n = int(lines[2])
    nums = list(map(int, lines[3 : 3 + n * 3]))
    return [(nums[i], nums[i + 1], nums[i + 2]) for i in range(0, len(nums), 3)]


class Tileset:
    _cache = {}

    def __init__(self, sym):
        d = find_tileset_dir(sym)
        self.tiles = Image.open(d / "tiles.png")
        assert self.tiles.mode == "P", (sym, self.tiles.mode)
        self.tile_px = list(self.tiles.getdata())
        self.tiles_w = self.tiles.size[0]
        self.missing_palettes = [i for i in range(16) if not (d / "palettes" / f"{i:02d}.pal").exists()]
        self.palettes = [read_pal(d / "palettes" / f"{i:02d}.pal") if (d / "palettes" / f"{i:02d}.pal").exists() else [(0,0,0)] * 16 for i in range(16)]
        meta_dir = d if (d / "metatiles.bin").exists() else d.parent
        raw = (meta_dir / "metatiles.bin").read_bytes()
        n = len(raw) // 16
        self.metatiles = [struct.unpack_from("<8H", raw, i * 16) for i in range(n)]
        attrs = (meta_dir / "metatile_attributes.bin").read_bytes()
        self.attrs = list(struct.unpack(f"<{len(attrs) // 2}H", attrs))

    @classmethod
    def get(cls, sym):
        if sym not in cls._cache:
            cls._cache[sym] = Tileset(sym)
        return cls._cache[sym]


class TilesetPair:
    def __init__(self, primary, secondary):
        self.p = Tileset.get(primary)
        self.s = Tileset.get(secondary)
        self.cache = {}
        self.invalid_metatiles = set()
        self.transparent_tile_slots = set()

    def draw_tile(self, img, ox, oy, entry):
        idx = entry & 0x3FF
        hflip, vflip, pal = (entry >> 10) & 1, (entry >> 11) & 1, (entry >> 12) & 0xF
        ts, ti = (self.p, idx) if idx < NUM_TILES_PRIMARY else (self.s, idx - NUM_TILES_PRIMARY)
        palette = (self.p if pal < NUM_PALS_PRIMARY else self.s).palettes[pal]
        per_row = ts.tiles_w // 8
        tx, ty = (ti % per_row) * 8, (ti // per_row) * 8
        px = ts.tile_px
        if (ty + 7) * ts.tiles_w + tx + 7 >= len(px):
            self.transparent_tile_slots.add(idx)
            return  # tile index beyond the image (unused slot): leave transparent
        for y in range(8):
            for x in range(8):
                c = px[(ty + y) * ts.tiles_w + tx + x]
                if c == 0:
                    continue
                sx = 7 - x if hflip else x
                sy = 7 - y if vflip else y
                r, g, b = palette[c]
                img.putpixel((ox + sx, oy + sy), (r, g, b, 255))

    def metatile(self, mid):
        """-> (under RGBA 16x16, over RGBA 16x16, behavior)"""
        if mid in self.cache:
            return self.cache[mid]
        if mid >= NUM_METATILES_PRIMARY:
            ts, local = self.s, mid - NUM_METATILES_PRIMARY
        else:
            ts, local = self.p, mid
        if local >= len(ts.metatiles):
            self.invalid_metatiles.add(mid)
            ts, local = self.p, 0
        entries = ts.metatiles[local]
        attr = ts.attrs[local] if local < len(ts.attrs) else 0
        layer, behavior = (attr >> 12) & 0xF, attr & 0xFF
        bottom = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
        top = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
        for i, (ox, oy) in enumerate(((0, 0), (8, 0), (0, 8), (8, 8))):
            self.draw_tile(bottom, ox, oy, entries[i])
            self.draw_tile(top, ox, oy, entries[4 + i])
        empty = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
        if layer == 1:  # COVERED
            under = bottom.copy()
            under.alpha_composite(top)
            result = (under, empty, behavior)
        else:  # NORMAL / SPLIT
            result = (bottom, top, behavior)
        self.cache[mid] = result
        return result


def rgba_sheet(path, dest):
    im = Image.open(path)
    if im.mode == "P":
        im.info["transparency"] = 0
    im.convert("RGBA").save(dest)
    return im.size


def main():
    (OUT_ASSETS / "maps").mkdir(parents=True, exist_ok=True)
    (OUT_ASSETS / "sprites").mkdir(parents=True, exist_ok=True)
    (OUT_ASSETS / "atlases").mkdir(parents=True, exist_ok=True)
    maps = {}
    raw_maps = [json.loads(p.read_text()) for p in sorted((SRC / "data/maps").glob("*/map.json"))]
    by_id = {m["id"]: m for m in raw_maps}
    layouts = {l["id"]: l for l in json.loads(read("data/layouts/layouts.json"))["layouts"]}
    pointers = dict(re.findall(r'\[(OBJ_EVENT_GFX_\w+)\]\s*=\s*&gObjectEventGraphicsInfo_(\w+)', read("src/data/object_events/object_event_graphics_info_pointers.h")))
    infos = dict(re.findall(r'gObjectEventGraphicsInfo_(\w+)\s*=\s*\{(.*?)\};', read("src/data/object_events/object_event_graphics_info.h"), re.S))
    pics = dict(re.findall(r'sPicTable_(\w+)\[\]\s*=\s*\{(.*?)\};', read("src/data/object_events/object_event_pic_tables.h") + read("src/data/object_events/berry_tree_graphics_tables.h"), re.S))
    graphics = dict(re.findall(r'gObjectEventPic_(\w+)\[\].*?INCGFX_\w+\("([^"]+)"', read("src/data/object_events/object_event_graphics.h")))
    sprites, missing_sprites = {}, set()
    for gfx, info_id in pointers.items():
        info = infos.get(info_id, "")
        table = re.search(r'\.images\s*=\s*sPicTable_(\w+)', info)
        pic_body = pics.get(table.group(1), "") if table else ""
        pic = re.search(r'(?:overworld_frame|obj_frame_tiles)\(gObjectEventPic_(\w+)', pic_body)
        if "BERRY_TREE" in gfx:
            target_pic = "BerryTreeSprout" if gfx.endswith("EARLY_STAGES") else "PechaBerryTree"
            pic = re.search(r'overworld_frame\(gObjectEventPic_(' + target_pic + r')', pic_body)
        if not pic or pic.group(1) not in graphics:
            missing_sprites.add(gfx)
            continue
        path = SRC / graphics[pic.group(1)]
        if not path.exists():
            missing_sprites.add(gfx)
            continue
        name = gfx.removeprefix("OBJ_EVENT_GFX_").lower()
        width, height = rgba_sheet(path, OUT_ASSETS / "sprites" / f"{name}.png")
        frame_width = int(re.search(r'\.width\s*=\s*(\d+)', info).group(1))
        frame_height = int(re.search(r'\.height\s*=\s*(\d+)', info).group(1))
        if "BERRY_TREE" in gfx and not gfx.endswith("EARLY_STAGES"):
            frame_height = 32
        sprites[gfx] = {"id": name, "src": f"/assets/emerald-world/sprites/{name}.png", "frameWidth": frame_width, "frameHeight": frame_height, "width": width, "height": height}
    rgba_sheet(SRC / "graphics/object_events/pics/people/brendan/walking.png", OUT_ASSETS / "sprites/player.png")
    pairs = {}
    atlases = {}
    unresolved = []
    for mj in raw_maps:
        key = mj["id"]
        lay = layouts[mj["layout"]]
        width, height = lay["width"], lay["height"]
        pair_key = (lay["primary_tileset"], lay["secondary_tileset"])
        if pair_key not in pairs:
            pairs[pair_key] = TilesetPair(*pair_key)
            atlas_id = "__".join(pair_key)
            ap = pairs[pair_key]
            au, ao = Image.new("RGBA", (512,512)), Image.new("RGBA", (512,512))
            attr_table = [None] * 1024
            for mid in range(1024):
                ts, local = (ap.p, mid) if mid < 512 else (ap.s, mid-512)
                if local >= len(ts.metatiles): continue
                u,o,_ = ap.metatile(mid)
                au.alpha_composite(u, ((mid%32)*16,(mid//32)*16))
                ao.alpha_composite(o, ((mid%32)*16,(mid//32)*16))
                attr_table[mid] = ts.attrs[local] if local < len(ts.attrs) else 0
            au.save(OUT_ASSETS / "atlases" / f"{atlas_id}.under.png", optimize=True)
            ao.save(OUT_ASSETS / "atlases" / f"{atlas_id}.over.png", optimize=True)
            atlases[atlas_id] = {"under": f"/assets/emerald-world/atlases/{atlas_id}.under.png", "over": f"/assets/emerald-world/atlases/{atlas_id}.over.png", "columns":32,"tileSize":16,"attributes":attr_table}
        pair = pairs[pair_key]
        atlas_id = "__".join(pair_key)
        raw = (SRC / lay["blockdata_filepath"]).read_bytes()
        cells = list(struct.unpack(f"<{width*height}H", raw))
        under = Image.new("RGBA", (width*16, height*16))
        over = Image.new("RGBA", under.size)
        rows, behaviors, collisions, elevations = [], [], [], []
        for y in range(height):
            row = ""
            for x in range(width):
                value = cells[y*width+x]
                mid, collision = value & 1023, (value >> 10) & 3
                u, o, behavior = pair.metatile(mid)
                under.alpha_composite(u, (x*16, y*16))
                over.alpha_composite(o, (x*16, y*16))
                ch = classify(behavior)
                if collision and ch == "_": ch = "#"
                row += ch
                behaviors.append(behavior)
                collisions.append(collision)
                elevations.append(value >> 12)
            rows.append(row)
        warps = []
        for w in mj.get("warp_events", []):
            dest = by_id.get(w["dest_map"])
            try: dw = dest["warp_events"][int(w["dest_warp_id"])] if dest else None
            except (ValueError, IndexError): dw = None
            warps.append({**w, "to": w["dest_map"], "tx": dw["x"] if dw else 0, "ty": dw["y"] if dw else 0, "dynamic": dw is None})
            if dw is None: unresolved.append({"map": key, **w})
            if 0 <= w["y"] < height and 0 <= w["x"] < width:
                r = rows[w["y"]]
                rows[w["y"]] = r[:w["x"]] + "_" + r[w["x"]+1:]
        under.save(OUT_ASSETS / "maps" / f"{key}.under.png", optimize=True)
        over.save(OUT_ASSETS / "maps" / f"{key}.over.png", optimize=True)
        script_path = SRC / "data/maps" / mj["name"] / "scripts.inc"
        maps[key] = {**mj, "width": width, "height": height, "tiles": rows, "rawCells": cells, "behaviors": behaviors, "collision": collisions, "elevations": elevations,
            "warps": warps, "connections": [{**c, "dir": c["direction"], "to": c["map"]} for c in (mj.get("connections") or [])],
            "npcs": [{**o, "id": f"{key}_{i+1}", "localId": i+1, "pretScript": o.get("script", "0"), "sprite": sprites.get(o["graphics_id"]), "facing": o.get("movement_type", "").removeprefix("MOVEMENT_TYPE_FACE_").lower()} for i,o in enumerate(mj.get("object_events", []))],
            "scripts": script_path.read_text(encoding="utf8") if script_path.exists() else "", "layoutData": lay,
            "render": {"under": f"/assets/emerald-world/maps/{key}.under.png", "over": f"/assets/emerald-world/maps/{key}.over.png", "atlasUnder": atlases[atlas_id]["under"], "atlasOver":atlases[atlas_id]["over"], "atlasId":atlas_id}}
    audit = {"maps": len(maps), "layouts": len(layouts), "sprites": len(sprites), "missingSpriteSymbols": sorted(missing_sprites), "dynamicWarps": unresolved,
        "objects": sum(len(m.get("object_events", [])) for m in maps.values()), "warps": sum(len(m["warps"]) for m in maps.values()),
        "bgEvents": sum(len(m.get("bg_events", [])) for m in maps.values()), "coordEvents": sum(len(m.get("coord_events", [])) for m in maps.values()),
        "dynamicSpriteSymbols": sorted({o["graphics_id"] for m in maps.values() for o in m.get("object_events", []) if o["graphics_id"] not in sprites}),
        "tilesetExceptions": [{"primary": k[0], "secondary": k[1], "invalidMetatiles": sorted(p.invalid_metatiles), "transparentTileSlots": sorted(p.transparent_tile_slots), "missingPrimaryPalettes": p.p.missing_palettes, "missingSecondaryPalettes": p.s.missing_palettes} for k,p in pairs.items() if p.invalid_metatiles or p.transparent_tile_slots or p.p.missing_palettes or p.s.missing_palettes]}
    output = {"version": 1, "tileSize": 16, "maps": maps, "sprites": sprites, "atlases":atlases, "behaviorNames": BEHAVIORS, "start": {"map": "MAP_LITTLEROOT_TOWN", "x": 6, "y": 8, "facing": "down"}, "audit": audit}
    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUT_JSON.write_text(json.dumps(output, ensure_ascii=False, separators=(",", ":")), encoding="utf8")
    print(json.dumps({k:v for k,v in audit.items() if k != "dynamicWarps"}, indent=2))


if __name__ == "__main__":
    main()
