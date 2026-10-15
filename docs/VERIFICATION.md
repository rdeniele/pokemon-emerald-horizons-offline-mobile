# Verification record — 15 October 2026

## Passed

- Node syntax checks for the local engine and app entry point.
- 14 Node test cases: all 1,025 national species in encounter pools; species stats/type immunities; three-stage, two-stage and branching evolution with large EXP rewards; failed/successful capture retries; no-ball handling; six-party PC overflow; costs/caps/compatibility; reward idempotence; save checksum fallback; import revision ordering; scaled farming; defeat recovery; appropriate early trainer stages; simulated 13-stage journey through Champion and postgame.
- Actual browser interactions: starter selection and intro dialogue; world-map rendering; quick-battle entry; joystick/keyboard roaming triggering a random Pansage encounter; Auto toggle; defeat recovery; save import; failed throw and restart preserving 4 attempts / 14 balls; successful throw interrupted by reload preserving exactly one Pikachu in PC.
- Visual inspection: default desktop map, 844×390 landscape battle and 390×844 portrait PC panel. Screenshot: `phone-pc.png`. Touch targets increased to a minimum 44px after first inspection; animated Pokémon image elements are reused between frames.
- Android Java compilation, DEX generation, asset packaging, alignment, signing and APK signature verification. Package `com.emerald.offline`, min API 24, target API 35. Manifest has no network permission; shell rejects off-origin requests. Build identifier/hash in `build-info.json`.
- Impeccable mechanical detector run once; its border-accent warning was addressed by reducing the Pokémon panel separator to 1px.

## Not verified on a device

ADB initially failed under the local socket sandbox. Retried with local socket access: server starts, but `adb devices` returns no connected devices. No Android emulator is installed in the inspected SDK. Therefore Android installation, airplane-mode first launch, process termination/resume through the OS, system save file pickers, physical touch accuracy, cutout behavior and sustained FPS are not claimed as tested. Browser reload and engine snapshot tests exercise the data logic, not the complete Android lifecycle.

## Remaining device acceptance steps

1. Install the APK on Android API 24+ with a current System WebView. Enable airplane mode before first launch; choose a starter and enter a biome.
2. Battle, capture with multiple throws, buy supplies, train, evolve at 16/36 and import/export via the system picker. Fill the party and capture into PC.
3. Background/foreground mid-battle; force-stop during a throw; relaunch and confirm single consumption/ownership. Verify pauses always require Resume.
4. Test a small landscape phone with navigation/cutout insets and a tablet. Measure frame time during rapid projectile/move use. Try system back, rotation and file-picker cancel.
5. Complete the progression with real battle play and tune difficulty/reward pacing. The automated Champion journey validates state transitions by resolving victories directly; it is not a claim of a human playthrough or balanced full campaign.

## Known simplifications

See README: canonical statuses/abilities/PP and regional/battle-only forms are not implemented. Moves use canonical types, power and damage categories, with simplified non-damaging actions. Maps are generated compact decorative trails. Evolution graph is manually curated; external/regional requirements are intentionally replaced. Android runtime and final balancing are pending the device steps above.
