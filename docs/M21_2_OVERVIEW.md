# M21.2 Overview

This milestone introduces the first modular floor-theme pass.

## Main change
The room floor is no longer rendered as just one inner slab and one outer slab.

It is now split into three visual zones:
- play floor
- edge floor
- outer floor

## Included in M21.2
- `RoomFloorLayoutBuilder.gd`
- play / edge / outer floor zoning
- MultiMesh floor rendering by zone
- new `edge_floor_color` in `LevelTheme`
- single collision base kept under the room for stable movement

## Current state
This is the first modular floor pass using generated box-piece floor tiles.
It is intended to prepare the system for later replacement with authored theme kit pieces.
