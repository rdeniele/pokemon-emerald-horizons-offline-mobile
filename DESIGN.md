---
name: Pokémon Prototype Mobile
description: The supplied HD-2D Kanto game with landscape touch controls.
colors:
  paper: "#f8f8f0"
  ink: "#283040"
  rim: "#c8ccd4"
  red: "#e0403a"
  green: "#48a860"
  blue: "#3870c8"
  amber: "#e8b030"
  pp-blue: "#58a0e8"
  dim: "#9098a0"
  shadow-text: "#d0d0c8"
  red-soft: "#fbe3e1"
typography:
  display:
    fontFamily: "Pixelify Sans"
    fontSize: "64px"
    fontWeight: 600
  body:
    fontFamily: "Nunito"
    fontSize: "24px"
    fontWeight: 600
  headline:
    fontFamily: "Pixelify Sans"
    fontSize: "28px"
    fontWeight: 600
  label:
    fontFamily: "Nunito"
    fontSize: "18px"
    fontWeight: 600
rounded:
  window: "10px"
  glass: "14px"
spacing:
  window-content: "18px"
components:
  window:
    backgroundColor: "{colors.paper}"
    textColor: "{colors.ink}"
    rounded: "{rounded.window}"
    padding: "{spacing.window-content}"
  glass:
    backgroundColor: "rgba(40,48,64,0.35)"
    rounded: "{rounded.glass}"
---

# Design System: Pokémon Prototype Mobile

## Overview
**Creative North Star: "The supplied HD-2D Kanto game"**

The recovered Godot game is the visual authority: HD-2D scenery, animated pixel characters, original title, music and white/ink menus. Mobile controls extend its existing touch system.

**Key Characteristics:**
- Original pixel characters in a lit three-dimensional world.
- Paper windows and translucent combat overlays.
- Contextual touch controls around a visible landscape playfield.

## Colors
Tokens come from `game/scripts/ui/kit/ui_kit.gd`; scenery and creature palettes remain in the supplied assets.

### Primary
- Paper and ink define windows, text and outlined titles.

### Secondary
- Green, amber and red communicate HP; PP uses pp-blue. Blue remains the kit's separate blue accent.
- Dim marks subdued content; red-soft supports red states; shadow-text supports label relief.

### Neutral
- Rim supplies the kit's pale edge color. Translucent ink backs overlays.

**The Semantic Meter Rule.** HP is green above half, amber above one fifth, and red otherwise; PP keeps its own blue.

## Typography
Supplied Pixelify Sans titles and Nunito body both use weight 600. Frontmatter records the kit's title, header, body and small-label design sizes. Godot's fallback font is a missing-resource fallback, not the display identity. Canvas scaling affects rendered size.

Battle move labels retain Pixelify Sans and use at least 12 engine screen pixels in touch mode, with wrapping within 92% of the move control width. This is a local readability adaptation, not a replacement for the kit's type ramp.

## Layout
1280×720 minimum canvas; wider landscape displays expand horizontally. Native landscape and immersive mode. Movement left; contextual actions lower right; location/menu upper right; party strip right. Browser portrait asks the player to rotate.

**The Bounded Touch Scale Rule.** Retain the source scale range of 1.0–1.8. At the verified 844×390 engine viewport, Menu reaches at least 48px, small actions 52px and moves 60px. The cap means these are not universal physical-size guarantees; phone ergonomics require device review.

## Elevation & Depth
Retain world lighting and source shadows. Windows use a black shadow at 30% opacity, size 8 design pixels and vertical offset 3. Touch controls use dark translucent fills and bright source-colored rims. Compatibility rendering preserves the world while omitting Forward+-only lighting effects; desktop lighting parity is not asserted.

## Shapes
Windows: 3px ink borders, 10px corners, 18px padding. Circular stick/actions; rounded-square menu controls.

## Components
Paper windows use the frontmatter window tokens. Glass overlays use translucent ink, a faint paper border and the kit's glass corners. HP rings and bars retain semantic thresholds.

Visible idle joystick becomes a floating stick on drag. Talk/Run use circular A/B controls and green/red rims; Menu uses drawn lines inside a rounded square. These letters are gamepad action labels, not decorative glyph icons. Independent multi-touch actions release on backgrounding. Title accepts taps without a menu D-pad. Auto/On touch settings migrate older Off values to On.

Original dialogue, party, bag, Pokédex and battle components remain authoritative. Kit windows pop in from scale 0.96 and zero opacity over 0.12s with Back/Out easing; pop out over 0.1s.

## Do's and Don'ts
### Do:
- Do preserve supplied assets, world visibility, original Credits and demo boundaries.
- Do retain original fonts, window construction and semantic meters.
- Do verify touch dimensions in engine screen pixels and separately review physical-device ergonomics.

### Don't:
- Don't replace this game with Emerald/Empress UI or add marketing panels around active play.
- Don't treat Compatibility rendering as exact desktop lighting parity.

Not canonized: source tiny auxiliary labels, resource/font cleanup warnings and observed debug-entry camera occlusion are retained issues, not reusable rules; full traversal and physical-device acceptance remain unverified.
