# M20 Overview

M20 turns level selection into a manifest-driven progression-aware flow.

## Added
- `GameProject/systems/level_runtime/LevelCatalogEntry.gd`
- `GameProject/systems/level_runtime/LevelCatalogService.gd`
- `GameProject/scripts/ui/LevelInfoPanel.gd`

## Updated
- level selection now reads manifest-backed catalog entries
- pedestals show locked / unlocked / completed / selected / targeted state
- holding room shows a level info panel with preview, tile count, palette count, theme, and lock reason
- interaction with locked pedestals is denied with a clear message
- portal text now reflects the selected level name
