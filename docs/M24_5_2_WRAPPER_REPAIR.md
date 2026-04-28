# M24.5.2 Wrapper Repair Hotfix

M24.5.2 is a focused repair update for missing generated wrapper scenes such as:

```text
straight_wall_scene_a_path does not exist: res://assets/theme_imports/walls/wall_wrapper.tscn
```

The authoring tool now performs an additional repair pass before validation:

1. If the wrapper exists in the wrong project folder, it copies it into `GameProject`.
2. If the wrapper is missing but the matching `.glb` or `.gltf` exists in managed imports, it regenerates the wrapper.
3. If the model is also missing, it reports that the original model must be browse-selected again.

Existing broken theme JSON that only contains a missing wrapper path may not be recoverable unless the copied model still exists beside it. In that case, browse-select the original `.glb` or `.gltf` again.
