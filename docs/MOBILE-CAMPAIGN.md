# Landscape mobile campaign

Version 1.2.0 adds a connected Hoenn adventure to the copied original game. It is an adaptation, not an exact port of either Windows executable. The original source repository remains untouched.

## Exploration and story

The main adventure contains 34 connected locations. Walk with the left stick, approach a marked NPC and tap the right interaction button. North and south exits connect locations; dialogue explains locked exits. Camera movement, terrain collision, tall-grass encounters and position checkpoints run locally. Rustboro has grass for training before Roxanne. Party, shop and the other game modes remain accessible from the world.

The journey follows Roxanne → Devon theft and Peeko rescue → Briney’s boat → Steven’s letter → Brawly → Slateport delivery/museum → rival → Wattson → meteorite/volcano → Flannery → Norman → Weather Institute/Fortree → Winona → Mt. Pyre and the hideouts → Tate & Liza/Space Center → Seafloor Cavern → Sky Pillar → Juan → Victory Road → Elite Four → Wallace → Hall of Fame. Trainer battles only complete their event after victory. Existing badge saves migrate past the corresponding earlier story without losing ownership or progress.

The early motifs are informed by the supplied Gamma package inventory. Exact maps, dialogue and runtime event graphs could not be extracted from its encrypted Unreal package. Later chapters are authored extensions following Hoenn's journey. See GAMMA-REFERENCE.md for the evidence boundary. The locations use locally bundled original pixel artwork and adapted layouts, not recovered Gamma geometry.

Wild encounters continue to use all 1,025 national species across Generations 1–9, filtered by biome, level, evolution stage and rarity. Regional/battle forms from the original roster remain available in later content. Story trainer teams also mix generations. Nothing restricts the journey to Emerald’s regional Pokédex.

## Action combat

The existing copied battle engine and authored animation/effect library remain active. Static inspection of Empress confirms independent movement/aim, four move casts, windup/recovery, real-time projectiles, dodge protection/cooldown and switching/deployment. Our adaptation supplies separate left MOVE and AIM ANGLE sticks, a right four-skill grid and Dodge, party switching, items, pause and optional auto-battle. A dotted direction indicator shows manual aim. Moving/aiming use independently captured pointers; interruption resets movement.

Trainer observer sprites are copied directly from the supplied Empress ASAR. Wild battles omit the opposing trainer. The source engine's action rules are retained rather than copying Empress's server; this is similar combat, not exact mechanical parity. PP, for example, remains represented by cooldowns in our source engine.

## Android and saves

This is an installable, landscape Android APK. Its bundled Next/Canvas renderer runs inside Android System WebView without browser chrome, a local server or INTERNET permission. It is not a fully native graphics-engine rewrite. The original brief explicitly permitted this packaging approach.

Android uses immersive display controls and window insets. Canvas exploration sizes to the available surface; combat scales its arena and places controls at the landscape edges. The phone and tablet layouts were checked at 844×390 and 1280×800. Hardware validation across every device is not established by these checks.

Campaign location, coordinates and event IDs are stored alongside the existing versioned save. Position checkpoints occur every three seconds and on transitions, interruptions and leaving exploration. Combat checkpoints, atomic rewards/captures, backup recovery and system-picker import/export remain intact. Fan attribution appears in Credits, with no persistent gameplay disclaimer.

## Verification boundary

Automated checks cover story gate reachability through all 13 gym/League battles, reachable NPCs/exits on all maps, existing-save migration, original combat and offline progression. They do not replace a complete human campaign playthrough or phone performance measurement. No Android device was connected for installation, airplane-mode, multitouch, cutout or sustained FPS testing.
