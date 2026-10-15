# Original game adaptation — 16 October 2026

The first implementation replaced too much of the user's source game. This revision corrects that architecture by copying its source gameplay and presentation into the target repository and adding the requested offline features to it.

Copied: original battle engine and systems, source species/arena kits, source animated sheet renderer, move effects, camera, party portraits, Emerald styles, local artwork and sounds, nine regional routes. Online authentication, cloud storage, database modules and network server code are not in the runnable app.

Modified: BattleEngine/Rng/AimedCombat gain deterministic save checkpoints; ArenaCanvas gains touch controls, lifecycle pausing, trainer observers and short deployment effects. Its source drawing code, camera and move-effect helpers are retained. StageGame/HomeMenu adapt the source menu and stage structure to local progression and stores. Original Hoenn leaders remain primary; extra regions keep their original trainer rosters. The old standalone web/app.js UI is no longer built or packaged.

The source-copy manifest records exact original content hashes. Original-engine tests verify unchanged source combat/status/arena systems, camera and effect helpers; they also verify original skillshots, status buffs, animation sheets and deterministic checkpoint resumption. The prototype's useful local save, capture/economy and progression code is reused through an adapter, not used as the battle engine.

Source repo was read only. No source secrets, environment files, node_modules, build caches or Git history were copied. Dependencies were installed fresh in the target. Read installed Next.js 16.3.8 static-export/output documentation before making framework changes.

The complete source roster, including regional/Mega/Gigantamax entries, is preserved. Source form learnsets were copied from the source fixture and are used for move compatibility. Forms are available in postgame habitats; the existing extra-region trainer lineups no longer drop their form entries.
