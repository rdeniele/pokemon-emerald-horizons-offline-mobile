# Emerald progression coverage

These checks exercise imported Emerald event instructions through the actual script VM and native mechanics. They are bounded entrypoint tests, not a completed walk-through or proof that every map, puzzle and optional activity is playable.

Source: the local `pret/pokeemerald` checkout whose ROM SHA1 matches the user's Emerald reference. No ROM is bundled into the APK.

## Script entrypoints checked

`tests/original/emerald-story-chain.test.ts` executes these exact source labels:

- `RustboroCity_Gym_EventScript_RoxanneDefeated`
- `RustboroCity_DevonCorp_3F_EventScript_MeetPresident`
- `Route104_MrBrineysHouse_EventScript_SailToDewford`
- `SlateportCity_OceanicMuseum_2F_EventScript_CaptStern`
- `Route110_EventScript_MayDefeated`
- `MauvilleCity_Gym_EventScript_WattsonDefeated`
- `MtChimney_EventScript_Maxie`
- `PetalburgCity_Gym_EventScript_NormanBattle`
- `Route119_WeatherInstitute_2F_EventScript_ShellyDefeated`
- `Route120_EventScript_StevenGiveDeconScope`
- `FortreeCity_Gym_EventScript_WinonaDefeated`
- `MossdeepCity_SpaceCenter_2F_EventScript_DefeatedMaxieTabitha`
- `SeafloorCavern_Room9_EventScript_ArchieAwakenKyogre`
- `SootopolisCity_EventScript_StartRayquazaScene`
- `SootopolisCity_Gym_1F_EventScript_JuanDefeated`
- `EverGrandeCity_SidneysRoom_EventScript_Defeated`
- `EverGrandeCity_PhoebesRoom_EventScript_Defeated`
- `EverGrandeCity_GlaciasRoom_EventScript_Defeated`
- `EverGrandeCity_DrakesRoom_EventScript_Defeated`
- `EverGrandeCity_ChampionsRoom_EventScript_Defeated`
- `EverGrandeCity_HallOfFame_EventScript_GameClearMale`

The harness chooses affirmative dialogue options and simulates external action-combat victories and a gift entering the party. It validates that source movement labels exist, rather than rendering movement. UI and presentation effects are recorded at the boundary; actual dialogue, cinematics, party editors, battle rendering and callback dispatch require separate renderer QA. Warps update the test map without performing traversal. Several tests start at victory or resolution entrypoints and do not establish that the preceding encounter is reachable.

Badge and Elite Four reward tests assert actual resulting flags. Additional assertions cover the Mt. Chimney defeat, Castform reward, Devon Scope receipt and Kyogre's escape. All invoked native handlers must be implemented; unsupported operations fail the test rather than receiving a fabricated success result.

## Additional checks

- Original wall-clock script suspends at the clock UI and resumes after JSON save restoration.
- Empty new-game bedroom decorations initialize without spawning objects. Saved sprite decoration layouts restore onto canonical small/large decoration surfaces with dynamic graphic variables and hide flags.
- Dad's TV broadcast changes actual television metatiles using source collision bits.
- Steven's selection requires an explicit one-based party order before reducing the party.
- Drake's fan counter follows the source packed bitfield and gain threshold.
- Gen 1–9 starter species remain actual national IDs while rival branches receive Emerald's canonical elemental representative.
- Mart inventories preserve the source `.2byte`/`.hword` stock labels, including Oldale's pre-Pokedex stock.
- Trainer rewards use the source class money value, last party level and double-battle multiplier.
- Multichoice menus preserve source option order and text from `gMultichoiceLists` and `src/strings.c`; `MULTI_PC` is a source placeholder requiring its dynamic PC service.

## Limits

This does not certify a complete new-game-to-credits traversal, all gender variants, every loss/capture branch, battle rematches, optional contests, the Battle Frontier, berry powder services, all decoration editing, multiplayer or all postgame natives. Unsupported natives deliberately keep scripts suspended. Physical Android gameplay and every device aspect ratio still need device testing.

## Continuation validation — 17 October 2026

The real action engine now has a focused Birch rescue integration test using Fuecoco (Generation 9). It executes the imported Birch bag event, checks the pre-choice empty-party save, runs the action battle to a win, reloads its deterministic checkpoint and resumes the original event into Birch's lab. This is a code-level integration test; it does not simulate UI clicks or certify the whole route traversal.

The continuation also verifies durable trainer victory/defeat/capture handoffs and selection of Steven's party without discarding the durable roster. Hall of Fame presentation now stores the actual team and returns to the source home location.

All 16 offline core tests and 76 source/adaptation tests pass. The latter include 10 original action-engine checks, four legacy condensed-campaign checks and 62 canonical Emerald/item/bridge checks. Legacy campaign tests do not establish coverage of the new world.

Browser QA in this continuation was rejected by the browser security policy. No alternate browser or raw browser-control workaround was used. ADB reports no connected Android devices. Browser walkthrough and physical Android acceptance therefore remain outstanding.
