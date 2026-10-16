# Emerald Horizons Offline Mobile

Android landscape fan game with Emerald's field world and event scripts, an expanded Generation 1–9 roster, and the existing Empress-inspired action battle engine and Pokémon assets. The app opens directly into the overworld. Separate region, biome, farming and click-to-battle launchers are removed.

The canonical import includes 518 maps, 441 layouts, 1,313 warps, original collision/elevation data, NPCs, dialogue, trainer teams, shops and story flags. Original field scripts suspend for action combat and resume after the committed outcome. The field menu provides progression-gated Pokédex, Pokémon, Bag, PokéNav, trainer card, Save, Option and Exit. New games begin in the truck with an empty party; starters from all nine generations are chosen in Birch's bag event.

## APK

`build/apk/emerald-horizons-debug.apk` requires Android 7.0/API 24 or newer and Android System WebView. The signed development APK bundles all runtime files and assets, has no INTERNET permission, uses landscape orientation and opens without browser chrome. Preserve the existing debug signing key to install updates over previous builds.

Install with Files, or run:

```powershell
D:\android-sdk\platform-tools\adb.exe install -r build\apk\emerald-horizons-debug.apk
```

Movement and facing share one left joystick. Releasing it retains facing. Skills and Dodge are on the right; mouse aiming and its crosshair are removed. Field exploration uses the same joystick, Interact and Run. Running shoes, bikes, HMs and field items follow their source gates.

## Build and checks

```powershell
npm run typecheck
npm test
npm run test:original
npm run build:android
node scripts/verify-apk.mjs
```

The Android packaging script uses the existing SDK at `D:\android-sdk` and JDK 17. Native local saves retain a checksum-valid backup and Android import/export. Battle checkpoints retain the original deterministic engine state.

## Evidence and current limits

[REA evidence](docs/REA-GAMEPLAY-EVIDENCE.md) records the supplied Empress ASAR identity and retained static analysis. [World import](docs/EMERALD-WORLD-IMPORT.md) records exact map/resource coverage. [Progression coverage](docs/EMERALD-PROGRESSION-COVERAGE.md) lists the 21 source story entrypoints checked through Hall of Fame and their test boundaries. The readable local pokeemerald reference matches the supplied ROM's expected identity; no byte-identical source rebuild is claimed. The ROM itself is not bundled.

Gamma's encrypted package supplies bounded scenario references; its exact gameplay and assets have not been decoded. This build is an ongoing source port, not a certified complete Emerald playthrough. Optional contests, Battle Frontier, some postgame native services and complete cinematic presentations remain incomplete. Unsupported native handlers preserve the script checkpoint and report the missing handler. Full opening-to-Champion traversal and physical Android acceptance remain outstanding. Browser QA was blocked by the browser security policy in the latest continuation; source/engine/build checks remain available.

Nintendo, Game Freak, Creatures and sprite contributors are credited in the in-app Credits. Pokémon artwork and names remain their owners' property. See [asset provenance](ASSETS.md).
