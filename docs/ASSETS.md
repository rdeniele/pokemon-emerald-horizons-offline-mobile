# Assets in the original-game adaptation

The target now retains the source game's bundled runtime asset library: `public/assets/empress` (catalog sprites, directional movement sheets and fallback sheets), `arena-audio`, `samy`, `pokemon`, `pret`, `fan-art`, `humble-paper` and `vryell`. Those files are copied unchanged; their hashes are in `source-copy-manifest.json`.

The original ArenaCanvas/combatAnimation renderer uses these directional sheets with the authored frame timing and per-frame anchors. Move audio and type-themed arena music are restored. Original paper panels, ribbons, icons and keyboard artwork are used by the copied menus. No CDN assets are needed.

Additional local files in `public/assets/offline` are the earlier pass's source trainer GIF/PNG, VT323 font and font license. The original @fontsource/vt323 package provides the source menu's self-hosted webfont at build time. No font service is used on the device.

Version 1.2 also imports 24 small trainer PNGs directly from `client/assets/trainers/` in the supplied Empress ASAR; `scripts/read-empress.mjs` records the selection. Brendan, May, Steven and a generic opposing trainer are used by combat observers. Exploration reuses the bundled `pret` player/NPC sheets and map artwork. Gamma's encrypted package was inventoried only; no Gamma image or map geometry was extracted.

Source contributor metadata is retained in `public/assets/empress/credits.json`. Pokémon catalog sprites identify Pokémon Showdown as their source; movement metadata retains its authors. Samy Pokémon RPG provides local audio and trainer artwork. Humble Pixel Paper and Vryell remain credited as in the source. Mainline Pokémon names/artwork belong to their respective owners. Local availability does not itself establish distribution rights.

The earlier duplicate `web/assets` library and standalone `web/app.js` interface have been removed from the checkout; their history remains in Git. The useful offline data and progression/save modules remain in `web/` and are imported by the original-game adapter. The Android package bundles the Next.js `out/` directory.
