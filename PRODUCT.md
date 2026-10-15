# Emerald Horizons Offline
<!-- impeccable:product-schema 1 -->
## Platform
web
## Stack
Delegated by user: dependency-free bundled JavaScript game in a native Android shell. Source assets and species stats are reused; Next.js is not retained.
## Users
The owner playing offline on an Android phone, primarily in landscape.
## Product Purpose
A complete local collection adventure: starter, roaming, action combat, captures, shops, eight gyms, League and legendary postgame.
## Constraints
No accounts, remote content or network permission. Durable local saves, touch controls, Gen 1–9 coverage. Preserve the source repository.
## Evidence
Existing source roster and sprite imports; local Empress distribution inspected as data. Original story is required.

## Shipped implementation
The local game is in `web/`; the Android shell is in `android/`. It offers starter selection, tap navigation, ten biome maps, weighted encounters, action combat, capture retries, shared EXP, branching level evolution, six-member party/PC, local shops/training, eight gyms, League and Champion postgame. Source sprite/data systems are reused; no online account or server is present. Versioned checksummed snapshots use native AtomicFile storage with previous-revision recovery and system-file export/import.

## Known delivery limits
All base national species are present; alternate forms are excluded. Canonical non-damaging move effects are simplified. Maps and story are compact. Physical-device acceptance and full difficulty balancing remain unverified; see docs/VERIFICATION.md. These limits are part of the current product truth, not hidden future promises.
