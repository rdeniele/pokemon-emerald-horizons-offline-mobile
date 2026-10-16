# Emerald field gameplay and Empress combat evidence

Inspected the owner's exact three supplied targets on 16 October 2026. Existing matching analysis was reused rather than repeated. Neither Windows executable nor the ROM was executed. No analysis-engine installation or client configuration changes were made.

## Findings and limits

| Question | Evidence | Status |
| --- | --- | --- |
| Which mainline Emerald ROM? | Read-only GBA header and digests in `emerald-rom-reference.json`: BPEE revision 0, 16,777,216 bytes, SHA-1 `f3ae088181bf583e55daf962a92bb46f4f1d07b7`. | Answered for artifact identity. |
| Can the complete field story be reconstructed from readable data? | Existing local `third-party/pokeemerald` reference contains map layouts, event scripts and C gameplay implementations. Its expected ROM checksum matches the supplied ROM; a rebuilt byte comparison has not been performed. | Source evidence available; this is ordinary source inspection, not REA decompilation. |
| What does Empress battle implement? | Retained REA Evidence `ev_79359df899c44ddecce6ead2b96ffd9762c642cda08e560ce05f4db3aea654bc`, operation `analyze_javascript_application`, selected `client/controls.mjs`, `client/combat.mjs`, `server/engine.cjs`. | Answered statically for selected battle sources; runtime not observed. |
| Does retained Empress evidence still match the target? | Current supplied `resources/app.asar` SHA-256 `5e71a4b11c35b01512772445e981ab5fe5299dc3f315cbb50530fc0a7ba97e91` matches retained Evidence subject. Complete 34,185,206-byte Evidence remains at ignored `build/reference/empress-rea.json`; compact checked-in summary is `empress-combat-evidence.json`. | Answered. |
| Is Gamma usable as an exact decoded campaign? | `gamma-package-evidence.json`: Unreal pak version 11, encrypted-index flag 1, Oodle compression; manifest separately inventories 119 map, 862 dialogue and 70 cutscene candidates. | Partial. Member names support scenario candidates; exact decoded content, runtime camera, collisions, event ordering and later campaign reachability remain unknown. |

REA tools are not connected in this active session. The prior registration diagnostic found no Codex REA registration; no native provider is available here. The installed cached CLI package is `rea-agents` 6.5.0, with its public launcher at `scripts/rea.mjs`. This pass did not repeat the same doctor/setup diagnostic because the blocker and matching retained analysis already exist. Gamma native decompilation is unavailable; inspecting its manifest and pak footer with normal tools does not produce REA Evidence. No claim of decrypted or extracted Gamma assets is made.

## Combat facts to preserve

The selected Empress engine creates continuously updated teams, facing vectors, projectiles, effects, PP and move cooldowns. `server/engine.cjs` lines 77–82 implement a 0.26-second dodge with a 2.8-second cooldown, choosing movement direction or retained facing. Lines 84–97 implement switching with a 7-second cooldown and inherited field position/facing. Lines 139–165 implement four move slots, PP consumption, cooldowns, windup and recovery; lines 202 onward implement active effects and projectile release. These are static code observations, not measurements of a running game.

The mobile adaptation deliberately uses one movement-and-facing joystick instead of the reference's independent pointer aim. Four skills, dodge and switching must remain accessible to the right. The reference's online transport and authentication are unnecessary for the offline battle adapter.

## Reusable local assets

The inert ASAR inventory contains 12,122 entries, including 8,745 `client/assets/movement` entries, 1,367 Pokémon image entries, 1,118 cries, 287 audio entries, 24 trainer images, 12 font entries and 6 arenas. Counts describe packaged files, not distinct species or proof that each animation is reachable. Movement sheets include Idle, Walk, Attack, SpAttack, Shoot, Hurt and other species-specific states. The target already retains source directional sheets, sprite catalog and contributor metadata under `public/assets/empress`; selected trainer files are under `public/assets/offline/trainers`. See `ASSETS.md` and `source-copy-manifest.json` for copied-asset provenance.

Gamma assets remain packaged behind the encrypted index. The canonical field port therefore uses the available Emerald map/tileset/NPC assets and Empress Pokémon artwork rather than claiming Gamma texture extraction.

## Required integration behavior

The user's latest scope makes the Emerald field world the primary application. Walk into encounters and trigger NPC, trainer, gym and story events in that world; these events hand off to Empress action combat and then resume the saved field script. Remove the separate click-to-battle, region challenge and battle-selection launcher from the journey.

Readable canonical menu source is `third-party/pokeemerald/src/start_menu.c`, especially the action definitions around lines 53–65 and menu entries around lines 182–195. It defines Pokédex, Pokémon, Bag, PokéNav, player card, Save, Option and Exit, with additional context-specific actions. Availability must follow source progression flags rather than exposing every feature at the beginning. The canonical menu is an in-world pause/menu flow; removing the old launcher does not mean removing inventory, party, save or settings.

Generation 1–9 is an intentional adaptation: preserve Emerald location/story/terrain/progression semantics and encounter levels while expanding species selection across all 1,025 base species. National roster IDs must be translated separately from Emerald's internal species constants when handling source gifts, trainer teams or script conditions.

The investigation establishes reusable evidence and resources. It does not establish that every native Emerald minigame, puzzle, story special or menu is already implemented. Shipping acceptance still requires opening-to-Champion progression and battle-return/save checks against the actual adaptation, with unsupported native handlers reported explicitly.
