# Gamma Emerald package reference

Inspected supplied local package `C:\Users\ronde\Downloads\gamma-emerald-ea-windows` on 2026-10-16. Static inspection only; the executable was not launched. This is reference evidence, not a claim that the resulting mobile app reproduces Gamma exactly.

## Evidence and reproducibility

Run `node scripts/gamma-inspect.mjs` to produce the retained [package evidence](gamma-package-evidence.json). The evidence includes exact manifest line numbers for each map, dialogue and cinematic candidate.

- `Manifest_UFSFiles_Win64.txt`: 404,105 entries; SHA-256 `9653dd0a5be41299a1ee6afa08aec1718dc82a1cab148b9781fec7ed32eb642c`.
- `PokemonEmerald/Content/Paks/PokemonEmerald-Windows.pak`: 1,645,117,904 bytes. Unreal pak magic at byte 1,645,117,700, version 11, encrypted-index flag 1, compression-name field `Oodle`. Index starts at 1,615,066,323 and spans 6,417,952 bytes. No decryption or key recovery attempted.
- Inventory contains 119 `.umap` map candidates, 862 dialogue `.uasset` candidates, and 70 cinematic/cutscene candidates.
- Format-aware inspection of the footer establishes package structure. The separate shipping manifest establishes candidate member names; it does not establish that every listed member is reachable or used.

## Supported reference motifs

The inventory supports a world assembled from connected town, route, forest, cave and building maps, with dedicated interior maps for shops, Pokémon Centers, houses and gyms. Examples include Rustboro, Route 116, Petalburg Woods, Granite Cave, Dewford, Slateport, Route 110, Mauville, Verdanturf, Meteor Falls and Fallharbor. NPC assets distinguish before/after events, gym introduction/defeat/reward phases, rival encounters, deliveries, and blocked-route interactions.

This supports adapting our existing game into traversable routes with collision, doors, interactive NPCs, encounter terrain, story flags and location-specific objectives. It does **not** establish exact Gamma camera behavior, controls, collision shapes, terrain layout or dialogue wording. `MODELS/BUILDINGS`, `SPRITES/NPC` and `SEQ` paths suggest a mixed model/sprite presentation, but visual style still requires runtime observation.

## Candidate story sequence for an adaptation

The following are interpretations of explicit member names. They are useful implementation references but were not decoded as executable event graphs:

| Candidate scenario | Supplied-package evidence |
| --- | --- |
| Rustboro first gym, Stone Badge | `GymLeaderRoxanne_Intro`, `_WantsToBattle`, `_Defeated`, `_GiveStoneBadge`, `_PostBattle`; `MAP_RoxanneGym` |
| Devon theft and Rusturf rescue | `RustboroCity_DevonResearcherPart1` through `Part6`; `Route116_BrineyNoPeeko1`; `RusturfTunnel_AquaGrunt`, `_AquaGruntDefeated`, `_Peeko`, `_Briney` |
| Boat journey and letter delivery | `Briney_Route104ToDewford`; `_DewfordBeforeLetterDelivered`, `_DewfordAfterLetterDelivered`; `GraniteCave_StevenRoom`; `SEQ_BrineyBoat` |
| Dewford gym | `BrawlyGym_*` trainer phases, `Brawly_*` leader phases; `MAP_Brawley_Gym`, `MAP_BrawlyGym_Battle` |
| Slateport delivery and museum confrontation | `SternShipyard_1F_ImDock`; `OceanicMuseum_F2_AquaGrunt1_Pre`, `_AquaGrunt2_Defeated`, `_ArchieCameToSeeWhatWasTakingSoLong`, `_Stern_ThankYouForTheParts` |
| Rival and Mauville gym | `Route110_Rival`, `_RivalDefeated`, `_RivalPostBattle`; `MauvilleGym_*`; `Wattson_WantsToBattle`, `_Defeat`, `_PostBattle` |
| Optional exploration rewards | Berry-tree harvest states; follower interactions; trade and egg dialogue; casino, daycare, rematch-room and secret-area maps |

## Coverage boundary

The shipped dialogue inventory is concentrated around the first three gyms and their surrounding routes. Searches did not find corresponding dedicated later-town/gym map or leader-dialogue names for Lavaridge/Flannery, Fortree/Winona, Mossdeep/Tate and Liza, Sootopolis/Juan or a complete League sequence. Norman appears in early Petalburg/Wally dialogue and a gym route asset, which does not prove a playable fifth-gym battle.

Hall of Fame map, widget and cinematic candidates **do** exist, as do Rayquaza flight and Groudon/Kyogre sequence names. These isolated assets do not prove that a complete campaign is playable in this early-access package. A full eight-gym-to-Champion campaign in our app must therefore be described as our adaptation/extension, unless additional runtime or source evidence establishes those later scenarios.

Exact dialogue, event ordering, map geometry, active camera, interactive behavior, complete story ending and runtime reachability remain unverified. The current inspection does not justify claiming a one-to-one Gamma recreation or successful asset extraction.
