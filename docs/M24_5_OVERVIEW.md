# M24.5 Overview

M24.5 is a theme authoring workflow patch built on M24.4. It keeps the stable lobby/runtime behavior unchanged and improves the GLTF/GLB picker workflow.

## Main change

In M24.4, selecting a `.gltf` or `.glb` outside `GameProject` failed because wrappers need export-safe `res://` references.

In M24.5, external `.gltf` and `.glb` files are copied into a managed runtime folder first:

```text
GameProject/assets/theme_imports/floors/
GameProject/assets/theme_imports/walls/
GameProject/assets/theme_imports/props/
```

Then the wrapper `.tscn` is generated next to the copied model, and the theme field stores the wrapper scene path.

## Expected examples

External wall model:

```text
Selected: C:/Users/you/Desktop/wall_stone.glb
Copied:   GameProject/assets/theme_imports/walls/wall_stone.glb
Wrapper:  GameProject/assets/theme_imports/walls/wall_stone_wrapper.tscn
Stored:   res://assets/theme_imports/walls/wall_stone_wrapper.tscn
```

External floor model:

```text
Selected: C:/Users/you/Desktop/floor_tile.glb
Copied:   GameProject/assets/theme_imports/floors/floor_tile.glb
Wrapper:  GameProject/assets/theme_imports/floors/floor_tile_wrapper.tscn
Stored:   res://assets/theme_imports/floors/floor_tile_wrapper.tscn
```

## Notes

- `.tscn` files must still be inside `GameProject`. External `.tscn` dependency copying is intentionally not attempted.
- `.gltf` dependencies are copied on a best-effort basis by reading local `uri` entries from the GLTF JSON.
- Runtime/exported theme definitions should reference wrapper `.tscn` files, not raw model files.
