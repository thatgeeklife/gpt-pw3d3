# M19.4 Overview

This milestone finishes the separate baker pipeline with manifest tracking and workflow docs.

## Added
- `SharedLevelContent/bake_manifest.json`
- `LevelBakerProject/scripts/BakeManifest.gd`
- baker now updates the manifest every time a level is baked

## Manifest tracks
- level id
- level name
- theme id
- source image path
- baked `.tres` path
- baked `.json` path
- visible pixel count
- palette count
- image size
- baker version
- bake timestamp

## Workflow
1. put source images in `SharedLevelContent/source_images/`
2. open `LevelBakerProject/project.godot`
3. choose source/output paths
4. bake the level
5. baker writes:
   - baked `.tres`
   - baked `.json`
   - updated `bake_manifest.json`
6. `GameProject` reads baked `.tres` in the normal runtime path
