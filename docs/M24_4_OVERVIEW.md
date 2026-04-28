# M24.4 Overview

M24.4 is built from the uploaded stable M24.2 baseline.

## Main goal

The Theme Authoring Tool can now accept authored wall/floor pieces from:

- `.tscn`
- `.gltf`
- `.glb`

Runtime and exported theme JSON still use `.tscn` paths.

## How selection works

### Selecting `.tscn`

The selected scene is used directly.

Example:

```text
Selected:
../GameProject/scenes/theme_contract/walls/StoneWall.tscn

Theme JSON stores:
res://scenes/theme_contract/walls/StoneWall.tscn
```

### Selecting `.gltf` or `.glb`

The authoring tool creates a sibling wrapper scene and stores the wrapper path.

Example:

```text
Selected:
../GameProject/scenes/theme_contract/walls/StoneWall.glb

Generated:
../GameProject/scenes/theme_contract/walls/StoneWall_wrapper.tscn

Theme JSON stores:
res://scenes/theme_contract/walls/StoneWall_wrapper.tscn
```

The wrapper scene instances the original model and records metadata:

- `metadata/generated_by`
- `metadata/source_model_path`

## Important constraint

GLTF/GLB source files must be inside `GameProject`.

That keeps generated wrappers export-safe because the wrapper can reference the source model using a normal `res://` path.

## Runtime impact

No lobby, Steam, P2P, spawn, portal, or generated-level runtime behavior was intentionally changed in M24.4.

This pass keeps runtime loading simple by making the authoring/export path normalize model selections to `.tscn` wrapper scenes.

## Current limitation

Wrapper generation is authoring-side only.

If a model file has not been imported by Godot yet, open `GameProject/project.godot` or the baker project once so Godot can create its usual import data before relying on that model in an exported build.
