# Canonical Emerald world import

`scripts/import-emerald-world.py` adapts the original project's `scripts/import_pret_maps.py` to import the complete local `third-party/pokeemerald` checkout, instead of its small configured opening subset. The original source checkout is read only. No ROM emulation or turn based battle renderer is introduced.

Run with Python and Pillow:

```powershell
python scripts/import-emerald-world.py D:/work/acqron/pokemon-emerald-horizons/third-party/pokeemerald
```

The output is `src/data/emerald-world.generated.json` and `public/assets/emerald-world/`. Map identifiers are canonical `MAP_*` constants. Tile coordinates are integer metatiles, 16 pixels each.

## Import coverage

- 518 maps, including indoor rooms, routes, caves, islands, underwater maps, gyms, League rooms, secret bases and Battle Frontier locations.
- All 441 canonical layouts are indexed; maps sharing a layout retain their independent events.
- 2,776 object events, 1,313 warps, 720 background events and 375 coordinate events.
- 239 fixed object graphics symbols resolved to RGBA sprite sheets, including trainers, item balls, boulders, Birch's bag, boats and decoration objects.
- 1,036 baked map layers, about 14 MB including sprite sheets.

Every original map header field and the raw `object_events`, `warp_events`, `bg_events` and `coord_events` arrays are retained. No flagged objects, trainer types, berry trees, item balls or scripts are filtered out. `scripts` contains each map's own raw script body; globally shared script definitions are supplied separately by the event importer.

## Runtime schema

The root contains `maps`, `sprites`, `atlases`, `behaviorNames`, `start` and `audit`. Each map additionally provides:

- `width`, `height`, `rawCells` (exact little endian layout words), `behaviors`, `collision` and `elevations`. Numeric cell arrays are row major.
- `tiles`: convenience strings using `_` for ordinary floor, `#` for blocking/ledges, `W` for water and `"` for encounter grass. Precise movement must consult behavior and elevation arrays, especially directional ledges, bridges, currents and special floors.
- `warps`: original fields plus `to`, destination `tx`/`ty` and `dynamic`. All 45 dynamic or nonstatic warp targets remain marked for runtime resolution; they are not fabricated as ordinary room exits.
- `connections`: original fields plus `dir` and `to`.
- `npcs`: every raw object plus a one based `localId`, stable `id`, `pretScript`, facing hint and sprite descriptor. The original `object_events` array remains authoritative.
- `render`: paths to transparent `under` and `over` PNG layers baked from canonical metatile graphics, palettes, flip bits and layer attributes.
- `render.atlasUnder`, `render.atlasOver`, `render.atlasId`: the paired metatile atlas for script driven `setmetatile` changes. Each atlas is 512 by 512 pixels, 32 columns of 16 pixel tiles; metatile `id` has source rectangle `(id % 32 * 16, floor(id / 32) * 16, 16, 16)`. `atlases[atlasId].attributes[id]` holds the original metatile attributes, or null for an unallocated slot. Unallocated slots are transparent instead of being replaced with another tile.
- `layoutData`: the complete canonical layout descriptor.

The 16 `OBJ_EVENT_GFX_VAR_*` symbols require script assigned graphics at runtime. They are explicitly listed in `audit.dynamicSpriteSymbols`; no fixed graphics symbols are missing. Berry growth stage/type, palette changes, animated map tiles, weather, object movement and script driven metatile edits remain runtime responsibilities. Baked layers represent the authored base layout, not every animated or script modified state.

`audit.tilesetExceptions` explicitly lists graphic slots referenced beyond the available source PNG data: eight Petalburg slots and thirteen Mauville Gym atlas slots. Those slots are transparent; no colors or graphic tiles are invented. No canonical map cell references an invalid metatile, and no palette files are missing. Connections preserve the canonical `up`, `down`, `left` and `right` direction names.

## Verification

Checked all 518 output maps against the local checkout: every raw header/event field matched, every `rawCells` word matched the canonical binary layout, and both PNG layers had the exact expected dimensions. The importer fails on an unresolved tileset rather than dropping a map. Secret base variants resolve their nested graphics directories and shared metatile tables explicitly.

Nintendo/Game Freak map and sprite material is included at the owner's request for the personal offline fan project; attribution remains in the app Credits.
