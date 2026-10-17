# Gen 1–9 extension

The existing Godot game now contains **1,025 base National Dex species**. Counts by generation: 151 / 100 / 135 / 107 / 156 / 72 / 88 / 96 / 120. This does not add every regional form or transformation mechanic.

## Sources

- Supplied `C:/Users/ronde/Downloads/Empress-Pokemon-2D-win/resources/app.asar`, SHA-256 `5e71a4b11c35b01512772445e981ab5fe5299dc3f315cbb50530fc0a7ba97e91`.
- REA static JavaScript application analysis: complete record remains locally in ignored `rea-evidence.json`; compact identity is in `rea-summary.json`. The initial sandbox worker-transfer error was resolved by allowing the worker's normal temporary files. The packaged game was not executed.
- `client/data/catalog.json` and `movement.json` supply species stats, typing, artwork paths, cry paths, animation timing/geometry/anchors and authors. Packaged Showdown Pokédex/learnset modules were parsed as inert TypeScript AST data; no module code was evaluated.
- [PokeAPI species CSV](https://github.com/PokeAPI/pokeapi/blob/master/data/v2/csv/pokemon_species.csv), [Pokémon CSV](https://github.com/PokeAPI/pokeapi/blob/master/data/v2/csv/pokemon.csv), and [stat/effort CSV](https://github.com/PokeAPI/pokeapi/blob/master/data/v2/csv/pokemon_stats.csv) supply capture rates, growth groups, gender ratios, experience yields and EV rewards. Snapshots are retained alongside the import reports.

## Assets and preservation

The original 51 species directories remain byte-identical. Added 974 species use their own packaged artwork: **931 directional animation sets**, including nine source walk fallbacks, and **43 static artwork fallbacks**. All 7,448 imported animation entries were checked against PNG dimensions and source frame metadata. Added 974 MP3 cries preserve the existing native cries. No substitute creature art was generated. Metadata for all imported artists is in `game/data/national-asset-credits.json`; 79 credited artists appear in the in-game Credits.

The original source JSON remains unchanged. National species/move/type/ability/encounter files extend it at runtime. Seven recovered runtime scripts changed explicitly: Dex loading, encounter mixing, storage, Pokédex, sprite slug resolution, cries and Credits. Their original/current hashes are recorded in `runtime-changes.json`; the original recovery manifest is retained unchanged. Existing mobile adaptation baselines remain reproducible.

## Gameplay

Every species appears in the original or additional encounter pools across 13 existing land tables. Native residents retain half the pool weight; visiting Pokémon share the other half. Legendary/mythical visitors have a tenth of an ordinary visitor's weight. Local encounter levels and story gates remain unchanged. Storage increases from 30 to 1,200. New data uses modern typing, including Fairy and modern Steel resistances.

Collection icons load cropped previews instead of full animation sets. The full actor-animation cache keeps at most32 recent species; active creatures keep their own references. This prevents opening a large collection from retaining every species' battle animations. Physical memory/performance acceptance still requires a phone.

The original 79 action move definitions are preserved. Another 113 damaging moves map to the engine's existing arc/projectile/area attack kinds; their base power/type/PP/accuracy are retained, with supported status effects. These are real-time adaptations, not a full modern battle simulator. Some low-level visitor kits receive a supported starter attack to stay playable; those cases are enumerated in `data-import.json`. Abilities remain display-only. Source-supported ordinary level evolutions are imported; species with unsupported special evolution conditions are directly encounterable instead. The map and story still end around the supplied demo's Pewter/Brock boundary.

## Verification

`national_runtime_test.gd` checks all 1,025 monsters' creation, moves, learnsets, asset presence, save serialization and encounter availability. Representatives from every generation are checked for actual texture loading, capture, Pokédex and storage roundtrips. Modern Fairy/Steel matchups are checked. `national_battle_smoke.gd` runs a Sprigatito–Fuecoco battle at 844×390 and checks directional animation and touch move targets. Node tests also verify complete numbering, metadata, assets, availability, explicit runtime changes and preservation of other recovered files.

Native APK remains landscape, offline, ARMv7/ARM64, signed with the existing development key. Version code6 / 0.2.0-national. Physical-device performance, a full collection playthrough and every move/evolution interaction remain unverified. Static fallback species have no authored directional movement; this is an asset limitation, not complete animation coverage.

## Re-import and build

With the supplied ASAR still at its original path and the retained CSV snapshots present:

```powershell
npm run import:national
node scripts/record-national-runtime.mjs
npm test
npm run build:game
npm run build
```

Generated sprites/data are retained in the project so ordinary builds do not require the source archive or network access. Complete REA output and large extraction caches remain local and ignored.
