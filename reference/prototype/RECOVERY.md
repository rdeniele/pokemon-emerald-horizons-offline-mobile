# Supplied-game recovery and mobile port

## Target and evidence

Source folder: `C:/Users/ronde/Downloads/Archive`, left unchanged. Only `PokemonPrototypeDemo.exe` and `PokemonPrototypeDemo.pck` select the target; unrelated graphics, macOS metadata and the `.skill` file were not used as instructions or game content.

- EXE: 109,112,320 bytes, SHA-256 `be2fa9787689a8c570380bccc0178db1cd2df82a6ed13c346ad4c40745fec44b`.
- PCK: 31,553,628 bytes, SHA-256 `ec80ffb97caea370bdab7604526f88800f59b8016978a5e9449cb65677324626`.
- REA CLI 6.5.0, installed cached public launcher. Native PE classification evidence: `ev_77f515b022890164bf9b003c5c30e280de7c4612d9118d01c737098edea0d0be` in `rea-managed-evidence.json`. Observes x86_64 PE without CLR/CIL metadata; it does not recover gameplay.
- REA's generic artifact route does not support Godot PCK. Its PE resource decoder rejected overlapping resource ranges after increasing the default file-size budget. Those bounded failure records remain in `rea-artifact.json` and `rea-pe-evidence.json`.
- No REA configuration was changed. The skill's recovery workflow continued through format-specific **GDRE Tools 2.7.4**, from its [official release](https://github.com/GDRETools/gdsdecomp/releases/tag/v2.7.4). Do not attribute GDRE decompilation to REA.

## Observed recovery

`game/gdre_export.log` records Godot 4.7.1, GDScript bytecode revision 4.5.0-stable, 5,631 verified/extracted package members, 146 decompiled scripts, zero failed scripts, 2,724 converted imported resources, zero failed conversions. **59 conversions are marked lossy**; recovered resources are not claimed to be original authoring files. The absent Beckett editor plugin implementation was excluded from the port; it is not gameplay. The desktop-only WebRTC extension is excluded from offline exports.

`recovery-manifest.json` records 5,752 recovered files outside editor caches/addons and their hashes. Unadapted files match the untouched GDRE recovery, which is a narrower claim than byte identity with the packed original. Eight adapted files have untouched baselines: project settings, analytics, controls, touch controls, settings, main menu, battle HUD and UI drawing. `adapt-prototype.mjs` resets those files from baselines on every invocation; reproducibility tests prevent stacked edits.

## Port decisions

The actual Godot game replaces the former Next.js Emerald/Empress game. Source world, story, creatures, real-time battles, moves, party, bag, Pokédex, dialogue, sound and local-save code are retained. The source is a Pallet–Pewter demo ending around Brock, not a full FireRed remake.

Native Android uses landscape, immersive fullscreen, ARMv7/ARM64, API24 minimum, target36, no Internet permission. Package `com.emerald.offline` and the existing debug signing certificate are retained. Telemetry is disabled. Online Cable Club services are unavailable in the offline build. Previous WebView saves are incompatible; the new game's native saves use Godot's storage.

The source's 1280×720 canvas expands horizontally for wide phones. Visible movement stick, independent action fingers, safe input release on focus loss, accessible menu/actions and enlarged battle lettering adapt the existing touch system. Auto/On settings avoid an unusable Off state. At the verified 844×390 engine viewport, menu targets are at least 48 screen pixels, small actions at least 52 and move targets at least 60. These are engine-pixel measurements, not physical-device millimetres.

Compatibility rendering enables broad GLES3/WebGL2 support. Forward+-only SSIL/volumetric effects are absent; exact desktop lighting parity is not claimed. [Godot's Web export documentation](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_web.html) describes the Compatibility/WebGL2 requirement. The browser export uses a single thread, with no cross-origin isolation dependency.

## Verification and boundaries

- Engine integration: original startup, Pallet and Forest streaming, party creation, finger movement plus Run, release on backgrounding, local save write/read, original battle startup, action target bounds, minimum target sizes, move press/release, readable single-line Scratch label, and old Off setting migration. See `mobile-smoke.log` and actual 844×390 `mobile-*.png` captures.
- Node tests: hash preservation for unadapted recovered files and repeated adaptation equality.
- Next.js TypeScript and static production build: preview shell compiles and exports.
- APK signature, package/ABI/API metadata, landscape manifest and absence of Internet permission checked with Android build tools. Signing certificate SHA-256 `253d364c8e798866ae5f8575bffeb86c9a6e4e888b518a102d0102347e466b53` matches the existing key.

The integration run reports source resource/font cleanup warnings at process exit; these are retained rather than represented as a warning-free runtime. One direct debug jump to the Forest south gate produced camera occlusion; the north gate rendered correctly. Ordinary traversal through every gate and a complete opening-to-Brock playthrough remain unverified. Browser capture was blocked by localhost timeout and the browser URL policy. No Android device was connected, so installation, physical thumb ergonomics, mobile GPU performance, suspension and audio acceptance remain outstanding.

## Cleanup

`backups/pre-prototype-20261017.zip` preserves old source/assets/docs/tests/scripts/Android shell and all unfinished tracked/untracked edits present at the start. `backups/legacy-build-notes.zip` preserves old ignored build notes. Previous assets, engine, tests, generated APKs/caches and WebView shell were removed from the active project. The signing key remains. Portable tooling, backups and generated caches are ignored by Git.
