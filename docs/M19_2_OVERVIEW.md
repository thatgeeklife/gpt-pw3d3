# M19.2 Overview

This milestone adds the first real bake pipeline.

## Added in M19.2
- `LevelBakerProject/scripts/BakedLevelBuilder.gd`
- `LevelBakerProject/scripts/BakeValidation.gd`
- baker UI now supports:
	- Validate
	- Create Sample
	- Bake Level
- sample source images included in `SharedLevelContent/source_images/`

## Current behavior
The baker can:
- load a source image
- validate it
- extract visible pixels
- derive a deterministic palette
- assign deterministic alphanumeric palette codes
- create a baked level resource
- save it into `SharedLevelContent/baked_levels/`

## Not yet in M19.2
- runtime game loading baked definitions in the normal path
- bake manifest
- content pipeline docs polish
