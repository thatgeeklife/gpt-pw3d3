# M24.5.1 Wrapper Hotfix

This is a focused patch for the M24.5 external GLTF/GLB import flow.

## Fixed behavior

When a GLTF/GLB model is selected, the authoring tool now only assigns the generated wrapper path after confirming the wrapper file exists.

Example expected result:

```text
GameProject/assets/theme_imports/walls/wall.glb
GameProject/assets/theme_imports/walls/wall_wrapper.tscn
```

Stored field value:

```text
res://assets/theme_imports/walls/wall_wrapper.tscn
```

## Auto-repair behavior

If validation sees a generated wrapper path is missing, it checks for a sibling source model.

Example missing wrapper:

```text
res://assets/theme_imports/walls/wall_wrapper.tscn
```

If this exists:

```text
GameProject/assets/theme_imports/walls/wall.glb
```

validation will recreate:

```text
GameProject/assets/theme_imports/walls/wall_wrapper.tscn
```

If the sibling model is also missing, validation will keep reporting the missing scene path. In that case, browse/select the source GLTF/GLB again.
