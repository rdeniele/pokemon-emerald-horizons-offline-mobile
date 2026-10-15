# Emerald Horizons Offline Mobile

A local Android collection adventure with 1,025 national Pokémon, an original Aurora Trail story, eight gyms, four League guardians, Champion Rowan and postgame habitats. Built in the target repository; the source repository is untouched.

## Install

Debug APK: `D:\work\acqron\pokemon-emerald-horizons-offline-mobile\build\apk\emerald-horizons-debug.apk`.
Requires Android 7.0 (API 24) or newer and a current Android System WebView. Copy the APK to your phone, open it in Files, allow installation from that file manager when prompted, and install. Or use:

```powershell
D:\android-sdk\platform-tools\adb.exe install -r build\apk\emerald-horizons-debug.apk
```

Launch **Emerald Horizons**. No login or connection is needed. The APK has no INTERNET permission. Its HTTPS-looking appassets URL is intercepted locally by the shell; it is not a hosted website.

## Play

Choose Treecko, Torchic or Mudkip. Tap numbered map stops for requirements, recommended levels and challenges. Explore one of ten biomes, choose an unlocked tier, and roam with the joystick to trigger weighted random encounters. Wild Pokémon are not selected from a menu.

Combat is real time: move with the joystick, use four move buttons, dodge, switch partners, use items or pause. Attacks aim toward the opponent. Optional Auto uses your strongest available attacks. Desktop preview also supports WASD/arrows, keys 1–4 and Space. Landscape is the Android default; controls and native window insets reserve space for system bars/cutouts.

Defeating a wild Pokémon opens a five-attempt capture phase. Each throw consumes one selected ball; failures allow retries. Chances and inventory counts are shown. Catches retain level, moves and upgrades. Party limit is six; overflow goes to PC storage. Party/PC panels offer evolution, permanent training, move tutoring and Focus Charm equipment. Shops sell three ball grades, potions, revives and the held charm.

Gyms unlock sequentially. Every two milestones unlock another habitat/farming bracket; the 81–100 tier opens after becoming Champion. Legendaries can appear in appropriate high-tier biomes after eight badges. All locations and challenges remain replayable. Losing supplies recovery gold and emergency balls; the center is free.

## Saves

Version 1 saves contain the party, PC, inventory, upgrades, progression, deterministic RNG, capture allowance and battle state. Android writes use AtomicFile in private app storage; a checksum-valid previous revision is retained. Browser preview uses localStorage. Purchases, reward claims, throws and ownership changes commit as one state snapshot. A throw result is saved **before** its animation, preventing double consumption or duplicate ownership after termination. Active battles checkpoint every 750ms and on actions; restart/pause resumes behind a pause screen. An abrupt process kill can rewind up to 750ms of combat, but cannot repeat a completed saved reward.

Saves tab supports system-file export/import, text export/import and previous-revision recovery. Corrupt primary saves fall back to the valid backup. Import replaces the current adventure and retains its previous save for recovery. Export before uninstalling: uninstall removes private saves. Rebuilds reuse the local debug key while `build/debug.keystore` remains present.

## Development and build

No npm dependencies or runtime downloads are needed. Node 24 and JDK 17 were used. Next.js, React, Phaser, authentication, databases and multiplayer are not included in this target build; the source asset roster, sprites, species stats and type chart are reused. A small deterministic local action engine replaces the server-oriented battle integration.

```powershell
npm test
npm run dev
npm run build:android
```

Preview: `http://127.0.0.1:4173`. Build defaults: SDK `D:\android-sdk`, build-tools 36.0.0, android-36 platform and JDK `C:\Program Files\Eclipse Adoptium\jdk-17.0.20.101-hotspot`. Override with `powershell -File scripts/build-android.ps1 -Sdk <path> -Java <jdk-path>`. The script compiles Java, builds DEX, bundles all web assets, aligns and signs the APK, then verifies its signature. No Gradle downloads are required. The generated key is development-only, ignored by Git and not suitable for production signing.

Data regeneration is optional: `node scripts/inspect-reference.mjs` then `node scripts/import-data.mjs` with the original source/reference paths available. Already-generated data and assets are committed in this target, so normal builds do not need either source directory.

## Verification and limitations

See `docs/VERIFICATION.md`, `docs/PROGRESSION.md`, `docs/REFERENCE-INSPECTION.md` and `docs/roster-audit.json`.

All 1,025 national species have local data/sprites and participate in at least one encounter pool. Regional, Mega and Gigantamax variants are excluded. Evolution relationships are manually curated (481 edges), including level-based replacements for external requirements; regional-exclusive evolutions are offered from the base species. Full canonical evolution/form parity is not independently verified. Missing source catch rates use 45; rare guardians have a separate capture factor.

This is a compact original implementation, not full mainline Pokémon mechanics: no breeding, abilities, IV/EV system or online features. Move power, type and physical/special split are preserved; non-damaging moves currently provide a small recovery action rather than canonical status effects. PP is replaced by cooldowns. Biome maps are compact generated trails with decorative terrain; no seamless world or collision puzzle system. Ball effects are short CSS effects. Trainers use reused local pixel assets rather than unique portraits for every leader. Only throw/victory audio is bundled and played.

A signed APK was built and inspected. Automated engine checks and browser interactions passed; **physical Android installation, first-launch airplane-mode behavior, lifecycle file-picker behavior and device FPS remain unverified because no device/emulator was connected**. Do not interpret packaging success as device certification.

Unofficial fan project. Pokémon and related assets belong to their respective owners. Retained contributor metadata is in `web/assets/credits.json`; see `docs/ASSETS.md`. Do not assume the bundled reference assets grant redistribution rights.
