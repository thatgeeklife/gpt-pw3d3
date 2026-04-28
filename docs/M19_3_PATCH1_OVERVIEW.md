# M19.3 Patch 1 Overview

This patch adds file dialogs to the baker project and switches GameProject to prefer baked `.tres` files.

## Added
- Browse Source button with a source image file dialog
- Browse Output button with a baked output save dialog

## Runtime change
GameProject now prefers:
- `SharedLevelContent/baked_levels/*.tres`

and only falls back to:
- `*.json`

Baked levels are also reloaded from disk instead of being served from the in-memory cache.
