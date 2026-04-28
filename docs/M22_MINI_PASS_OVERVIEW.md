# M22 Mini-Pass Overview

This mini-pass converts the level-select system from **automatic pedestal spawning** to **hand-placed pedestal binding**.

## What changed
- pedestals are no longer auto-laid out from the catalog at runtime
- the holding room now instantiates:
	- `res://scenes/level_select/HoldingRoomPedestalLayout.tscn`
- each placed pedestal binds to level data by exported identifier

## Pedestal binding
Each pedestal now exposes:
- `bound_level_id`
- `fallback_level_key`

Recommended usage:
- set `bound_level_id` in the inspector
- use `fallback_level_key` only as a backup

## Workflow
You now place pedestals where you want them in the world by editing:
- `GameProject/scenes/level_select/HoldingRoomPedestalLayout.tscn`

Then set the pedestal identifiers there.
