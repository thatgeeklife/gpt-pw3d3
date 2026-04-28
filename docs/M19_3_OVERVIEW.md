# M19.3 Overview

This milestone switches the **game project's normal level load path** to baked definitions.

## What changed
- `GameProject` now prefers baked definitions from:
  - `../SharedLevelContent/baked_levels/*.json`
- baked definitions are adapted into the legacy `LevelDefinition` shape for compatibility with the existing runtime, save system, minimap, and progression code
- raw image import remains as a fallback/dev-only path
- baked JSON files for Forest, Lava, Portrait, and Scene are included in the package

## Runtime behavior
Normal path:
1. game asks `LevelContentLibrary` for a level
2. library loads sibling baked JSON from `SharedLevelContent/baked_levels`
3. library adapts baked data into the runtime-compatible legacy level definition resource
4. existing runtime/gameplay systems continue working

Fallback path:
- if a baked definition is missing, the old runtime image importer still works
