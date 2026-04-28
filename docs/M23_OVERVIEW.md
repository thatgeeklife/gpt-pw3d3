# M23 Overview

This milestone hooks the authored theme contract into the runtime generator.

## Main change
`LevelGenerator.gd` can now use authored floor and wall scenes from `LevelTheme` when they exist.

## What is now wired up
- custom theme JSON files can now be loaded from:
	- `res://data/levels/themes/<theme_id>.json`
	- `res://data/levels/themes/<theme_id>_theme.json`
- floor zones can instantiate authored scenes for:
	- play floor
	- edge floor
	- outer floor
- wall generation can instantiate authored scenes for:
	- straight wall A / B / C
	- corner post A / B
- missing scene paths fall back to the primitive generator path

## Performance note
Authored floor scenes can become expensive on very large levels, so M23 keeps a safety threshold:
- if a floor zone exceeds the authored-scene instance cap, that zone falls back to the MultiMesh primitive floor renderer
