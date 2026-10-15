# Bundled assets

- `web/assets/pokemon`: 1,025 animated/static GIF sprites imported from the source project's local Empress Pokémon sprite import. Catalog identifies Pokémon Showdown sprite sources; no sprite source URL is requested at runtime.
- `web/assets/credits.json`: preserved local Empress import contributor metadata, including authors for movement sheets. This target uses the catalog GIF sprites, not the movement-sheet library.
- `web/assets/player.gif`, `rival.png`: source `third-party/samy-pokemon-rpg/assets/img/player.gif` and `blue.png`.
- `web/assets/throw.mp3`, `victory.mp3`: source Samy RPG sound effects.
- `web/assets/display.woff2`: locally installed @fontsource/vt323 Latin regular font, VT323 / SIL Open Font License. License copied alongside the font.
- Map terrain and combat diagrams: original SVG/CSS markup generated locally by the game.

This is an unofficial fan project. The presence of an asset in a local game does not establish redistribution rights. Contributor/source metadata is retained rather than replaced with an invented license.
