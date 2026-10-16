# Emerald event runtime audit

Audit of the local readable canonical `third-party/pokeemerald` source, 2026-10-16. This is static source evidence; no ROM was executed.

## Scope and architecture

The canonical map/shared script corpus contains 525 `.inc` files, 14,188 labels, and 479 distinct indented source command names (includes movement macros and data helpers). `data/script_cmd_table.inc` defines 227 bytecode opcodes. Source macro interpretation is preferable to decoding ROM pointers when importing this readable source.

The existing Horizons `src/game/script.ts` is a handwritten dialogue/trainer/cutscene adapter. It selects imported text and trainer rosters but does not execute canonical map scripts. Copying it cannot preserve complete original progression.

A faithful source runtime needs: global labels, call stack, comparisons and switch state, flags, vars, temporary vars, trainer flags; object movement/visibility/permanent positions; text substitutions and choices; map callback tables; coordinate triggers; warps; dynamic metatiles/collision; inventory and common service hooks. Battle instructions should suspend the script and delegate to the existing action battle, then return the result and resume the original script continuation.

Do not silently discard unsupported gameplay commands or native specials. `special` occurs 1,066 times and `specialvar` 345 times. Unknown helpers must be diagnosed with label/map/arguments. Visual/audio delays can be adapted, but results that drive conditionals must be explicit.

## Critical common hooks

- `data/scripts/new_game.inc:EventScript_ResetAllMapFlags` supplies initial hidden-object flags and resets berries. Without it, later story actors appear immediately.
- `src/new_game.c:NewGameInitData`: zero event data, money 3000, empty party/bag/storage, initial PC items, warp to truck, run ResetAllMapFlags. No preselected starter.
- `Route101/scripts.inc`: `ChooseStarter` then `HealPlayerParty`; original rescue event movements and subsequent script continuation matter.
- Birch lab: `SetUnlockedPokedexFlags`, `EnableNationalPokedex`.
- `data/scripts/pkmn_center_nurse.inc`: `CountPlayerTrainerStars`, `HealPlayerParty`, `PlayerNotAtTrainerHillEntrance`, `BufferUnionRoomPlayerName`, yes/no result and healing field effect.
- Shared services: `pc.inc`, `pc_transfer.inc`, `obtain_item.inc`, `item_ball_scripts.inc`, `surf.inc`, `field_move_scripts.inc`, `repel.inc`, `day_care.inc`, `berry_tree.inc`.
- Map callbacks include `MAP_SCRIPT_ON_LOAD`, `MAP_SCRIPT_ON_TRANSITION`, `MAP_SCRIPT_ON_FRAME_TABLE`, `MAP_SCRIPT_ON_WARP_INTO_MAP_TABLE`; coordinate trigger predicates must share persistent variables with these callbacks.

## Field movement and puzzle gates

`src/party_menu.c` maps field abilities to badges exactly: Cut 1, Flash 2, Rock Smash 3, Strength 4, Surf 5, Fly 6, Dive 7, Waterfall 8. Party move availability is checked separately. HMs are obtained through actual map scripts; granting all traversal at each gym without their story acquisition changes gameplay.

- Petalburg Gym: `VAR_PETALBURG_GYM_STATE` controls Norman/Wally placement and initial tutorial. State 6 opens trainer-cleared room doors; state >=7 opens all doors. Door states use individual trainer flags and metatile mutations.
- Mauville: native `MauvilleGymSetDefaultBarriers`, `MauvilleGymPressSwitch`, `MauvilleGymDeactivatePuzzle`.
- Fortree: native `RotatingGate_InitPuzzle`, `RotatingGate_InitPuzzleAndGraphics`.
- Mossdeep: rotating tile commands and dynamic metatile state. Requires actual puzzle collision changes.
- Sootopolis: native `SetSootopolisGymCrackedIceMetatiles`, step callback/cracked ice/fall handling.
- League: `data/scripts/elite_four.inc` closes entry doors and opens advance door by changing metatiles and collision. League front guard checks badge 6 specifically: canonical comment says Winona is the only badge that can otherwise be skipped. Do not replace with an invented linear stage index.

## Canonical main progression audit targets

Preserve script dependencies, rather than replacing these with a checklist completion reward:

1. Truck, house clock, rival visit, Route 101 Birch rescue/starter, Route 103 rival, lab Pokédex, running shoes.
2. Petalburg Norman/Wally tutorial, Woods Devon encounter, Roxanne, stolen goods/P eeko recovery, Devon president, Briney boat.
3. Dewford Brawly and Granite Cave Steven letter, Slateport goods delivery and museum Aqua, Route 110 rival, Mauville Wally/Wattson.
4. Rock Smash routes, Meteor Falls meteorite theft, Mt. Chimney Magma, Jagged Pass and Lavaridge Flannery, goggles, Norman and Surf.
5. Route 119 Weather Institute, rival/Fly, Steven/Devon Scope/Kecleon, Fortree Winona.
6. Mt. Pyre orbs, Magma Hideout, Slateport submarine theft, Aqua Hideout, Mossdeep Tate/Liza, Space Center double battle, Steven/Dive.
7. Underwater Seafloor Cavern, awakening/weather, Sootopolis Wallace, Sky Pillar Rayquaza, resolution, Juan/Waterfall.
8. Ever Grande/Victory Road Wally, Elite Four room sequence, Wallace, Hall of Fame; retain postgame scripted actors and access.

These are source exploration targets, not a substitute event implementation. Exact flags and variable predicates must be executed from the imported scripts.

## Emulator preservation option

No `.elf` or linker `.map` is present in the local pokeemerald tree. No installed GBA/mGBA/EmulatorJS implementation was found in either project dependency tree. Embedding an emulator could preserve original nonbattle gameplay, but replacing battles requires reliable ROM version-specific symbols, entry/exit hooks, party/save synchronization, capture and trainer outcome handling; Gen 1–9 additionally exceeds the original ROM species schema. It is not a drop-in solution with current local artifacts. Source map/script import provides better integration with the existing full-generation action combat while retaining inspectable event logic.

## Bounded ROM/emulator handoff feasibility follow-up

Local RAM symbol files are object-order manifests, not numeric symbol tables. `sym_common.txt` starts with main.o, but main.o declares key-repeat/link globals before gMain. `ld_script.ld` fixes EWRAM at 0x02000000, IWRAM at 0x03000000, COMMON at 0x030022A8; these do not alone resolve individual globals. No ELF/linker-map was found.

`include/main.h` gives relative gMain offsets: callback2 +0x004, savedCallback +0x008, inBattle bit 1 at +0x439. `src/battle_main.c` declares EWRAM gBattleOutcome (u8). Player/enemy parties are EWRAM arrays in pokemon.c; SaveBlock pointers are COMMON in load_save.c. SaveBlock storage is relocated by an offset, so dereference current pointers rather than assuming fixed save-data bases.

The normal exit is more than a callback swap. FreeRestoreBattleData restores callback1, clears inBattle, zeros the enemy party, stops low-health audio and frees battle/sprite resources. Battle setup assigns different saved callbacks for ordinary wild, scripted wild, trainer, tutorial and special battles. Bypassing this cleanup after initialization would leave invalid state. Hooking before allocations requires matching ROM function addresses and verified return semantics. Gen 1–9 needs a sidecar/proxy scheme because canonical boxed Pokémon use encrypted, shuffled, checksummed fields and the ROM has Gen 3 species tables.

The [official mGBA core interface](https://github.com/mgba-emu/mgba/blob/master/include/mgba/core/core.h) supplies frame stepping, bus memory reads/writes, register access, save/load state, core callbacks, and optional debugger/symbol loading. A custom WASM C shim could expose these for a deterministic battle handoff.

The independently maintained [mGBA-wasm wrapper mapping](https://github.com/wasm-gaming/mGBA-wasm/blob/main/CORE.md) exposes frames, rendering, input and states, but disables debugger/scripting/ELF loading. Its documented public mapping does not expose arbitrary memory access. Adapting its shim/build would be required; it is not an official upstream WASM API. No package was downloaded and no ROM was run.

Conclusion: technically feasible as a separate integration project, with greater exactness for optional original minigames. It is not a safe drop-in replacement for the current event runtime until matching symbols, proper exit/cleanup hooks, capture/trainer outcomes, party/storage proxy synchronization and save-state migration are implemented and exercised.
