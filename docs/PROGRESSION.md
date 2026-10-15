# Progression in the adapted original game

The offline progression/economy formulas are retained from the first pass; the combat implementation is now the original Emerald Horizons source engine.

Stats at level L: HP = floor(2 × baseHP × L / 100) + L + 10 + 2 × upgrades. Other stats = floor(2 × baseStat × L / 100) + 5 + 2 × upgrades. Source real-time combat multiplies HP by 10, while party panels show the underlying stat. Each stat allows five upgrades, costing 150 × (current upgrades + 1). Focus Charm adds 10% outgoing damage. Movement is 3.2 + current SPE/160 grid units per second. Basic reuse interval is max(0.8, 1.8 − SPE/300).

Original source damage calculation, collision/cover, skillshots, physical/special split, STAB, type immunities and dual-type multipliers are retained. The source engine uses a deterministic 0.85–1.0 roll, move-specific projectile speeds, skill cooldowns, buffs, statuses, dodging, knockback, streams and clashes. Learned move names/types/power/categories enter the original move system; utility effects use supported source heal/buff/control behaviors. This is not full mainline move-effect parity.

EXP thresholds are L³ and cap at 100. Victory shares round((enemyLevel² × 4 + 40) × difficultyScale) with every party member, where difficultyScale = min(1, (enemyLevel / activePartnerLevel)²). Three-stage roots evolve at 16, then 36; two-stage roots evolve at 36. Evolution is a player choice. A large EXP award can cross both thresholds and immediately offer the second choice after the first evolution. Individual upgrades and held items persist.

Capture chance = clamp(0.035, 0.94, rarityFactor × (1 − level/250) × ballQuality). Ordinary rarityFactor = 0.22 + 0.5 × catchRate/255; legendary = 0.085. Ball quality is 1 / 1.7 / 2.6 for Poké / Great / Ultra. Five attempts are allowed after each wild victory. RNG advancement, ball consumption and ownership commit in one save before the animation begins.

Ordinary encounter weight = max(0.15, catchRate/255) × (3 if unevolved, otherwise 1). Legendary weight = 0.015 per eligible species. Pools match biome types, evolution-stage thresholds and progression requirements. Legendary families are exempt from stage filtering so their earlier stages remain obtainable. All 1,025 base species participate in pools. Each 140 movement units has a 38% encounter check; failed checks let roaming continue. Levels are uniform within the area's tier.

Victory gold = round((35 + enemyLevel × 8) × difficultyScale). First primary stage clear adds 500 + stageIndex × 180 once. Extra source regional challenges award 400 first-clear bonus gold. Defeat awards 30 gold and guarantees at least three Poké Balls. Ball prices 60/150/360, potion 50, revive 160, charm 400, compatible tutor 200.

Primary source Hoenn leaders recommend levels 14, 23, 32, 41, 50, 59, 68, 77; League 82, 85, 88, 91; Wallace 95. Primary teams are generation-diverse and respect the leader's original type. Extra source regional teams are retained at levels 80–100 and unlock after eight badges. Quick battles have three opponents at the bracket midpoint. Tiers 1–15, 16–30, 31–45, 46–60, 61–80 unlock at 0/2/4/6/8 primary clears; 81–100 requires all 13 primary clears.

Original-engine checkpoints include all simulation state and in-flight effects, not just HP/position. Saves checkpoint every 750ms and on actions/pause. An interruption may rewind the last fraction of a second of combat but never duplicates an already committed reward or capture.

Source variants are an additional 391 roster entries (1,416 total). Their encounter weight is multiplied by 0.1 relative to an ordinary entry, except legendary variants retain the legendary weight. They require tier 81–100 and completed primary progression. Variant move compatibility uses the copied source learnsets and selected source kits.
