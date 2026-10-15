# Reference inspection

Inspected `C:\Users\ronde\Downloads\Empress-Pokemon-2D-win\resources\app.asar` using an ASAR header reader, treating the archive exclusively as data. Did not run the reference executable or modify its files.

Read `client/app.js`, `client/story.mjs`, `client/index.html`, `client/data/catalog.json`, and the source project's importer. The reference home offers story, quick battle and team management. Story mode uses a drawn regional overworld: gated regions with `requires` conditions, roads, towns, proximity NPC interactions, short dialogue, completed-stage records and a minimap. Its NPC renderer distinguishes uncleared objectives and completed stages. Quick battles use a three-member action team, directional movement, move casts, dodges and switching. The reference is server-integrated; its online modules and server origin are not reused.

The user's requested clickable map is an adaptation, not an exact claim about the reference. This version substitutes tap-to-enter gym/League nodes and biome choices for continuous regional traversal. Original characters Larch, Rowan, Nia and the Prism Guild tell a new beacon-restoration story. Compact roaming maps supply wild encounters separately from the progression map.

Data audit found 1,025 base national species with sprites, four-move selections and compatible learnsets across Generations 1–9. Imported only selected source sprite GIFs, local trainer art, two short audio files, one font, species/move data and contributor metadata. No server code, executable, authentication configuration, secrets, dependencies or source Git history were copied. Source evolution code had only a small hand-written family map; this target supplies its own national-ID evolution graph.

The source repo's Emerald pixel interface is retained in green framing, cream panels, local pixel sprites and VT323 labels. No Next.js files are retained or modified, so its framework documentation requirement does not apply to this implementation.

## Correction on 16 October 2026
The first standalone implementation is superseded. The game is now copied and adapted from the user's source repository. Its Next.js static export, original battle engine, source directional sprites/effects, sounds, menus and Hoenn leaders are retained. See ORIGINAL-ADAPTATION.md and the source-copy manifest. The earlier statement that Next.js was not retained applied only to the superseded prototype.
