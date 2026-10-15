# Verification — copied original-game adaptation, 16 October 2026

## Passed

- TypeScript checks and production Next.js static export of `/`, `/game/` and `/credits/`.
- **14 offline progression/save tests**: all 1,025 base national species in pools; stats/immunities; evolution thresholds/branches/large EXP; capture retries, exhaustion/no balls and full-party PC overflow; purchase costs/upgrade caps/move compatibility; reward idempotence; checksum recovery/import revision ordering; scaled farming; defeat recovery; simulated primary journey and appropriate early stages.
- **10 original-game adaptation tests**: source-file hash identity for core combat/status/movement/arena systems, effects, camera, animation helper, party portraits and original theme; original directional animation timing and local sheet coverage; real skillshot aim/miss behavior; deterministic original-engine resume with in-flight attacks; original buffs; type immunities; source stats and individual upgrades reaching the engine; checkpoints round-tripping through the save store; regional-form availability/move data; complete source roster preservation.
- Browser verification of copied original Emerald menu and Rustboro arena: actual original-engine Auto battle defeated Roxanne, recorded one badge and awarded EXP/gold/story progression. Reloaded interrupted combat resumed behind an explicit pause screen with preserved combat state. Touch controls and phone layout inspected at 844×390; original desktop sizing assumptions corrected and readable HP panels added.
- Browser capture checks in the copied React interface: failure + immediate reload retained 4 attempts and 14 balls; success + immediate reload produced exactly one Pikachu in PC with a full party. Restored the earlier verified original-game adventure after fixture checks.
- Source-copy manifest records original file hashes. Complete source roster including forms is retained. Secrets, environment files, dependencies, caches and Git history were not copied from the source. Dependencies were installed fresh in the target. No source files were written.
- Signed Android debug APK, package `com.emerald.offline`, version 1.1.0/code 2, minimum API 24/target API 35. APK verification checks every file in `out/` against its bundled bytes, explicitly requires `_next/static` and rejects the old standalone `app.js`. AAPT's underscore exclusion is overridden so the Next.js runtime is bundled. The manifest has no INTERNET permission. Final size/hash/counts are in `build-info.json`.
- Impeccable detector for the adapted interface returned no findings. Original theme/artwork was retained rather than redesigned.

## Device acceptance still pending

ADB was checked again on 16 October: server starts successfully, but `adb devices` lists no connected Android device. No physical installation, airplane-mode first launch, Android process-kill lifecycle, system file picker, cutout behavior or sustained device FPS is claimed as tested. Browser reload/state tests validate the logic but do not replace a device run.

Install the APK on API 24+ with a current System WebView, enable airplane mode before first launch, choose a starter, roam, battle, catch, shop, train and evolve. Test pause/resume, force-stop during a throw, save export/import, full-party PC overflow and a small landscape phone with system navigation insets. A real campaign playthrough is still needed to tune pacing and difficulty; the automated full journey resolves victories directly.

## Scope and limitations

The original source action engine's supported status/buff/heal and move-specific effects are restored. This remains an action-game interpretation of Pokémon, not a full mainline simulator. IV/EV, abilities and breeding are not added; cooldowns stand in for PP. Extra forms are stable source-roster variants encountered in postgame, not canonical temporary transformation mechanics. Evolution relationships are manually curated with external requirements replaced by levels. Existing source runtime art and sounds make this APK larger than the discarded prototype.

Screenshot: `original-battle-landscape.png` shows the copied original battle with the added phone controls and HP panels. Older prototype screenshots are historical evidence only.
