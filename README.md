# Pokémon Prototype Mobile

The game supplied in `C:/Users/ronde/Downloads/Archive/PokemonPrototypeDemo.pck`, recovered and adapted in its original Godot engine. This replaces the previous Emerald/Empress implementation. Original HD-2D scenery, sprites, music, story, party, inventory, real-time combat and local saves are retained. The supplied demo covers Pallet Town through Pewter/Brock; no later regions are claimed.

The National Dex expansion adds all **1,025 base species from Generations 1–9**. Additional Pokémon share the existing 13 encounter areas with native residents; rare legendary/mythical visitors have lower weights. Storage holds 1,200 Pokémon. Modern typing includes Fairy. The source's 79 action moves remain intact, with 113 additional damaging moves adapted to its existing battle actions. Modern abilities remain display-only; special evolutions are available as direct encounters.

Assets come from the supplied `Empress-Pokemon-2D-win/resources/app.asar`: 931 added directional sprite sets, nine of those using source walk fallbacks, 43 static species sprites, and 974 cries. The 51 original species' assets remain unchanged. Original artist attribution is retained in Credits and `game/data/national-asset-credits.json`. See [National Dex import](reference/empress/NATIONAL-DEX.md).

## Play

Install [the Android APK](build/apk/pokemon-prototype-mobile.apk). Android 7.0+, ARMv7/ARM64, landscape, immersive fullscreen, no Internet permission. Existing package name and signing key retained. Previous WebView-game saves are incompatible with this different game.

Drag the left stick to move; hold B to run; A talks/interacts. The upper-right menu opens the original party, bag, Pokédex, save and options. Combat retains four move buttons, jump, sprint, items and party selection. Multiple fingers work together. Backgrounding releases controls. Original keyboard/gamepad support remains.

`npm run dev` serves the browser preview at http://localhost:4173. It opens directly into Godot. Portrait phones show a rotate prompt; fullscreen requests landscape where supported. Native Android is the primary mobile deliverable.

## Build

`game/` is the recovered Godot 4.7.1 project. `reference/prototype/baseline/` retains untouched originals of the eight adapted files. `scripts/adapt-prototype.mjs` reapplies modifications reproducibly. `src/app/` is only the browser preview shell.

Portable Godot and selected official export templates are in ignored `tools/`. Self-contained editor settings use the existing Android SDK and JDK17. Preserve `build/debug.keystore` for updates.

```powershell
node scripts/adapt-prototype.mjs
npm run build:game     # Web + signed debug APK
npm run build         # static Next.js preview
npm run typecheck
npm test
```

Integration test:

```powershell
& tools/godot/Godot_v4.7.1-stable_win64_console.exe --path game --script res://mobile_smoke.gd --resolution 844x390 -- --touch
```

The previous source, assets, tests and unfinished edits are in `backups/pre-prototype-20261017.zip`. Downloads is untouched. Old generated outputs were removed; backup, signing key and new builds remain.

See [recovery and verification](reference/prototype/RECOVERY.md). Physical-device performance and a full start-to-Brock playthrough remain acceptance work. Original credits remain in the game. This APK is development-signed.
