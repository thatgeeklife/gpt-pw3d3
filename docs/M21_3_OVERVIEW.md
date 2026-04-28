# M21.3 Overview

This milestone upgrades room walls from one repeated wall box per side into modular perimeter segments.

## Main change
Walls are now generated from ordered perimeter slots and resolved through weighted deterministic variants.

## Included in M21.3
- `ThemePieceVariant.gd`
- `ThemeVariantResolver.gd`
- `RoomWallLayoutBuilder.gd`
- weighted straight-wall variants
- deterministic per-slot wall selection
- basic repetition avoidance by wall run
- corner post variants
- new wall-variant theme settings in `LevelTheme`

## Current state
This milestone still uses generated primitive wall pieces rather than imported authored wall-kit scenes.
The important new part is the slot/resolver/theme architecture for future modular theme assets.
