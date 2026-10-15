# Supplemental Emerald reference

The owner supplied `C:/Users/ronde/Downloads/Pokemon - Emerald Version (USA, Europe)` as the reference to use when resources, story, pathing or gameplay details are missing.

Read-only inspection found a 16 MiB GBA ROM with title `POKEMON EMER`, game code `BPEE`, revision 0 and a valid header checksum. Its SHA-1 is `f3ae088181bf583e55daf962a92bb46f4f1d07b7`, matching the expected ROM checksum in the existing local `pokeemerald/rom.sha1`. Reproduce the identity check with `node scripts/inspect-emerald-rom.mjs`; the result is recorded in `emerald-rom-reference.json`.

The existing readable reference checkout is `D:/work/acqron/pokemon-emerald-horizons/third-party/pokeemerald`. It contains `data/maps/*/map.json`, map event scripts, layout data, graphics and gameplay source. Use those files to resolve Hoenn connections, collision, interiors, event prerequisites and story details that could not be verified from Gamma's encrypted package. Inspect the relevant script and data before changing the mobile adaptation; a matching expected ROM checksum is not a claim that this checkout has been rebuilt and compared byte-for-byte.

For example, `data/maps/RustboroCity_DevonCorp_3F/scripts.inc`, event `RustboroCity_DevonCorp_3F_EventScript_MeetPresident`, explicitly gives the player the letter, enables the PokéNav flags and heals the party after the meeting with Mr. Stone. That provides readable event evidence for a fuller Devon return sequence than the mobile campaign's current condensed dialogue.

Reference priorities: use Gamma for the requested exploration/scenario direction where evidence is available; use Emerald for missing Hoenn content and rules; retain Empress-style action combat and its available assets. The mobile game's expanded Generation 1–9 roster, custom evolution/progression, touch controls, landscape presentation and offline save requirements still apply. Emerald's regional encounter tables must not narrow the mobile roster to Generation 3.

This pass verifies and registers the supplemental reference. It does not claim to have executed the ROM, imported its complete world, or replaced the current campaign with exact ROM maps. The supplied ROM itself is not copied into the APK or repository.
