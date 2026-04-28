# M21 Theme Authoring Contract

## Purpose
This contract defines how imported modular theme-kit assets should be normalized for the game.

## Core footprint rules
- one gameplay cell = **2.0 x 2.0** world units
- one straight wall segment spans **one gameplay cell**
- default wall segment length = **2.0** world units
- default wall thickness target = **0.5**
- default wall height target = **5.0**

## Origin rule
Every authored theme piece should use:
- root centered on its footprint
- `y = 0` at the floor-contact baseline

## Forward axis rule
Wall pieces are expected to face:
- **+Z**

That means:
- the visible front of the piece should be authored for +Z forward
- generator-side rotation can be handled later if a pack needs directional mapping

## Floor piece categories
- play floor
- edge floor
- outer floor

## Wall piece categories
- straight wall A
- straight wall B
- straight wall C
- corner post A
- corner post B

## Why this matters
If all imported kit pieces are normalized to this contract:
- small and large rooms both work
- modular generators can swap themes safely
- you avoid one-off offsets and ad-hoc scale hacks per asset

## Included prototype scenes
The following placeholder scenes are included as normalization references:
- `res://scenes/theme_contract/floor/PrototypePlayFloorTile.tscn`
- `res://scenes/theme_contract/floor/PrototypeEdgeFloorTile.tscn`
- `res://scenes/theme_contract/floor/PrototypeOuterFloorTile.tscn`
- `res://scenes/theme_contract/walls/PrototypeStraightWall_A.tscn`
- `res://scenes/theme_contract/walls/PrototypeStraightWall_B.tscn`
- `res://scenes/theme_contract/walls/PrototypeStraightWall_C.tscn`
- `res://scenes/theme_contract/walls/PrototypeCornerPost_A.tscn`
- `res://scenes/theme_contract/walls/PrototypeCornerPost_B.tscn`
