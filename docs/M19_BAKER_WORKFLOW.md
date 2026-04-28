# M19 Baker Workflow

## Source images
Place source images in:

- `SharedLevelContent/source_images/`

## Bake output
Bake output is written to:

- `SharedLevelContent/baked_levels/`

Each bake writes:
- one `.tres`
- one `.json`

## Manifest
Each successful bake also updates:

- `SharedLevelContent/bake_manifest.json`

## Recommended steps
1. Open `LevelBakerProject/project.godot`
2. Use **Browse Source** to select a source image
3. Fill in:
	- level id
	- level name
	- theme id
4. Use **Browse Output** to choose the `.tres` output path
5. Click **Validate**
6. Click **Bake Level**
7. Open `GameProject/project.godot`
8. Reselect the level in game to verify the new baked content

## Runtime source of truth
`GameProject` now prefers baked `.tres` files first.

If a baked `.tres` is missing, it falls back to:
- baked `.json`
- then raw image import

## Current caveat
The runtime still adapts baked data into the older legacy level definition shape for compatibility.
