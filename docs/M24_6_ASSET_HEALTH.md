# M24.6 Asset Health Report

Press **Validate Theme** in the Theme Authoring tool to refresh the report.

Each scene slot now shows:

- `Status`
- `Stored Path`
- `File Exists`
- `Generated Wrapper`
- `Wrapper Source`
- `Model Exists`
- `Root Type`
- `Node Count`
- `Mesh Marker`
- `Model Instance Marker`

A healthy wrapped model should look roughly like this:

```text
Status: OK
Stored Path: res://assets/theme_imports/walls/wall_wrapper.tscn
File Exists: YES
Generated Wrapper: YES
Wrapper Source: res://assets/theme_imports/walls/wall.gltf
Model Exists: YES
Root Type: Node3D
Model Instance Marker: YES
```

If a wrapper exists but points to a missing source model, the report should now make that explicit.
