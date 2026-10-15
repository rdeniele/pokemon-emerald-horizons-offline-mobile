# Progression and formulas

National base stats are sourced from the local reference catalog; source catch rate/base EXP fields are reused when available. Gen counts: 151 / 100 / 135 / 107 / 156 / 72 / 88 / 96 / 120.

For level L, HP = floor(2 × baseHP × L / 100) + L + 10 + 2 × HP upgrades. Other stats = floor(2 × baseStat × L / 100) + 5 + 2 × upgrades. Each stat permits five upgrades, priced 150 × (current upgrades + 1). Focus Charm adds 10% outgoing damage. Speed increases movement speed. Stats remain individual and species-specific.

EXP is cumulative L³. Victory shares round((enemyLevel² × 4 + 40) × difficultyScale) EXP with every party member; difficultyScale = min(1, (enemyLevel / activePartnerLevel)²). Level increases until the cumulative threshold is reached, capped at 100. Evolution is a player choice: a three-stage root evolves at 16 and its next stage at 36; two-stage roots evolve at 36. Large EXP awards can cross both thresholds; evolving the first stage immediately offers the next eligible choice. Nonlinear and regional branches use the same threshold mechanism. Upgrades and held items persist.

Damage = floor(((2L/5 + 2) × power × attack/defense / 50 + 2) × typeEffectiveness × STAB × heldMultiplier), minimum 1 except immunities (0). Physical moves use ATK/DEF; special moves use SPA/SPD. STAB is 1.5. Dual-type effectiveness multiplies the reused Gen 6+ chart. Projectiles can miss moving targets. A dodge grants 0.55s invulnerability with a 2s reuse interval. Four move cooldowns are 1.2 + power/65 seconds. Enemy attacks occur every 1.5s. Non-damaging moves recover a small amount of HP in this version.

Capture chance = clamp(0.035, 0.94, rarityFactor × (1 − level/250) × ballQuality). Ordinary rarityFactor = 0.22 + 0.5 × catchRate/255; legendary rarityFactor = 0.085. BallQuality: 1 / 1.7 / 2.6 for Poké / Great / Ultra. There are five attempts per defeated encounter. RNG advances inside the same saved snapshot that consumes the ball and assigns ownership.

Ordinary encounter weights = max(0.15, catchRate/255) × (3 if unevolved, otherwise 1). Legendary weight = 0.015 per eligible species. Pools require matching biome types, appropriate stage thresholds and story/tier eligibility. Legend families are exempt from stage filtering to keep their unevolved members obtainable. Pool coverage is tested for all 1,025 species. Each roaming stretch of 140 movement units has a 38% encounter probability. Pokémon levels are uniform within the selected tier. Wild stages are limited by the tier floor; pools can keep unevolved species briefly beyond their threshold.

Gold per victory = round((35 + enemyLevel × 8) × difficultyScale). A first gym/League clear adds 500 + stageIndex × 180, exactly once. Defeat gives 30 gold and restores inventory to at least three standard balls. Shops: balls 60/150/360, potion 50, revive 160, charm 400, compatible tutor move 200. All purchases use validated local transactions.

Gyms recommend levels 14, 23, 32, 41, 50, 59, 68, 77; League 82, 85, 88, 91; Champion 95. Trainer teams choose generation-diverse appropriate-stage species for their type and use bundled four-move kits. Team size grows from 2 to 6. Quick battles have three opponents at each bracket midpoint. Brackets 1–15, 16–30, 31–45, 46–60, 61–80 unlock after 0/2/4/6/8 clears; 81–100 requires all 13 clears.
