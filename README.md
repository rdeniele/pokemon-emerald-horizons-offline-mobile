# Emerald Horizons Offline Mobile

This version copies and adapts the original game from `D:\work\acqron\pokemon-emerald-horizons`. It keeps the original deterministic action engine, directional Pokémon animations, move effects and clashes, arena obstacles, music, sounds, Emerald paper menus, party portraits, nine regional routes and original Hoenn leaders. Offline progression is added to that game rather than replacing combat with a newly written substitute.

The earlier standalone prototype remains in Git history. Its substitute interface has been removed from the current checkout. Only its useful local progression/economy/save module (`web/engine.js`) and generation data are reused by the copied app through `src/offline/model.ts`. Its standalone `web/app.js` interface and combat loop are not bundled in this APK. The actual game is the statically exported Next.js app in `src/`.

See [the mobile campaign notes](docs/MOBILE-CAMPAIGN.md) for the exploration flow, controls, reference evidence and validation limits.

## Install

APK: `D:\work\acqron\pokemon-emerald-horizons-offline-mobile\build\apk\emerald-horizons-debug.apk`.

Requires Android 7.0 (API 24) or newer with a current Android System WebView. Copy the APK to your phone, open it in Files, permit installation from that file manager when prompted, and launch **Emerald Horizons**. Or:

```powershell
D:\android-sdk\platform-tools\adb.exe install -r build\apk\emerald-horizons-debug.apk
```

The app has no INTERNET permission. Its `appassets.androidplatform.net` requests are served directly from the APK, including Next.js scripts, sprites, directional sheets, music, fonts and map artwork. No Next.js server runs on the phone. Authentication, Supabase, databases and multiplayer have been removed from this build.

## What is preserved and added

The source battle simulation and rendering remain the foundation: real skillshots, beams, clashes, dodges, switches, status/buff effects, move-specific timing, authored animation anchors and camera motion. The original source appearance is retained. A SHA-256 copy manifest at `docs/source-copy-manifest.json` records the imported source and assets. Tests verify that core combat systems, rendering helpers and the source theme remain identical to those copied files.

Added: independent left movement/aim sticks and a right four-skill/Dodge cluster, visible trainers outside combat, short ball send-out/recall effects, pause/resume, durable battle checkpoints, 34 connected Hoenn locations with NPC interactions, story flags and trainer battles, ten roaming biomes, random encounters, six progression tiers, EXP to 100, custom branching level evolutions, five capture attempts, three ball grades, party/PC overflow, gold, supplies, compatible move teaching, capped stat upgrades, held Focus Charms and repeatable farming. Existing source regional challenges remain available as extra battles after eight Hoenn badges.

Primary journey: connected towns and routes follow the Hoenn leaders Roxanne, Brawly, Wattson, Flannery, Norman, Winona, Tate & Liza, Juan, then Sidney, Phoebe, Glacia, Drake and Wallace. Devon, Peeko, Steven’s letter, the museum, rival encounters, Aqua/Magma and the ancient Pokémon crisis connect the milestones. New levels and generation-diverse teams replace the old fixed-stat battles. Additional regions retain source trainer rosters.

## Play and controls

Choose one of the source game's 27 starters. Use Gym challenge to select a numbered milestone, Explore biomes to enter a random-encounter trail, Quick battle to farm, and Town shop to buy supplies. Completed challenges remain replayable.

Combat: separate movement and manual angle sticks on the left; four move buttons and Dodge on the right. Party portraits switch Pokémon; Items, Pause and optional Auto remain available. Manual aim retains its direction as the Pokémon moves. Desktop keys remain WASD, Q/E/R/X, Space and 1–6, with mouse aiming. Items pause combat. Resume is required after a restart or Android backgrounding.

Wild victory opens a capture phase with five throws. Every throw consumes exactly one selected ball; failure permits another attempt. The estimated chance and remaining inventory are visible. Success joins the party or PC if the six slots are full. Party/PC training provides permanent upgrades and compatible move tutoring. Evolution choices appear at the custom level thresholds, including branching choices.

Losing gives emergency gold and at least three Poké Balls. Every new battle starts with the party healed, so the player cannot become stranded without recovery. The highest tier unlocks after Champion; legendary encounters become possible in high-tier matching biomes after eight badges.

## Save system

Checksummed, versioned local snapshots retain ownership, EXP, moves, upgrades, currency, inventory, rewards, RNG, capture attempts and combat state. Android storage uses AtomicFile and keeps a valid previous revision. Import/export uses the Android system file picker or text. Browser preview uses localStorage.

The **original engine** now checkpoints its full deterministic state: combatants/reserves, statuses, cooldowns, in-flight attacks/clashes, RNG, AI plans, controlled sides and pending hits. It saves every 750ms, on actions and on pause. A sudden process kill can rewind up to 750ms of combat; completed rewards and captures commit as one save and cannot be claimed twice. Imports keep monotonic revision ordering. Saves from the earlier prototype retain party/progression; an old prototype battle without an original-engine checkpoint restarts that encounter in the original engine behind a pause screen.

Export before uninstalling: uninstall deletes private saves. Keep `build/debug.keystore` locally if you want subsequent debug APKs to update the installed app without uninstalling. The signing key is ignored by Git.

## Development and build

The installed Next.js static-export documentation was read before adapting the app. Next.js 16.3.8 and React 19.2.8 are retained. Install dependencies normally; no source dependencies or build caches were copied.

```powershell
npm ci
npm run typecheck
npm test
npm run test:original
npm run build
node scripts/serve.mjs
```

Static preview: `http://127.0.0.1:4173`. `npm run dev` runs the original Next.js app on that port instead; use only one preview server at a time.

```powershell
npm run build:android
node scripts/verify-apk.mjs
```

The Android build bundles `out/`, not `web/`. Default SDK is `D:\android-sdk` with build-tools 36.0.0 and android-36; JDK 17 is at `C:\Program Files\Eclipse Adoptium\jdk-17.0.20.101-hotspot`. The build script supports `-Sdk` and `-Java` overrides. Java compilation, DEX, asset packaging, alignment and APK signing do not require Gradle downloads. The static export needs development dependencies, but the installed APK needs no npm, server or downloads.

Source-copy/import scripts are provenance tools, not part of a normal build. Do not rerun `scripts/copy-original.mjs` over adapted files: it deliberately copies the unmodified originals. It never copies source secrets, `.env.local`, dependencies, build caches or Git history. Source repository remains untouched.

## Coverage and known limitations

All 1,025 base national species are available in local encounter pools across Generations 1–9. Every additional source roster entry, including regional, Mega and Gigantamax variants, is also retained with its source stats, sprites and compatible move sets. These variants can appear rarely in unlocked postgame habitats; additional regional trainer teams retain their original forms. Evolution relationships are manually curated (481 edges); external requirements become levels, and regional-exclusive branches are offered from base species. Full canonical evolution/form parity has not been independently verified. Missing source catch rates default to 45, with a separate legendary factor.

This retains the source's action-game interpretation of moves, statuses and buffs rather than implementing the entire mainline ruleset. Abilities, breeding and IV/EV systems are not added; PP remains represented by move cooldowns. The 34-location Hoenn journey is a Gamma-inspired adaptation with authored later chapters; exact Gamma geometry and dialogue were not recovered. Compact biome maps remain separately available. Combat HP uses the source's 10× multiplier to suit real-time action. See `docs/PROGRESSION.md` for formulas.

TypeScript, static export, engine tests, provenance tests, asset checks and browser checks are recorded in `docs/VERIFICATION.md`. Physical Android installation, airplane-mode first launch, system-picker lifecycle, cutout behavior and sustained device FPS remain unverified without a connected device. Full campaign difficulty still requires a real playthrough.

Unofficial fan game. Pokémon belongs to its respective owners. Original contributor metadata is retained; see `/credits/`, `public/assets/empress/credits.json` and `docs/ASSETS.md`. Local availability of reference artwork does not itself establish redistribution rights.
