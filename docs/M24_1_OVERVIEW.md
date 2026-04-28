# M24.1 Overview

This milestone adds the first pass of the Theme Authoring Tool inside `LevelBakerProject`.

## Main additions
- new root tool scene with tabs:
	- Level Baker
	- Theme Authoring
- Theme Authoring editor UI
- new theme definition model
- new theme definition IO helper
- load/save/export theme JSON without hand-editing files

## What M24.1 does
You can now:
- create a new theme definition
- load an existing theme JSON
- edit theme fields through UI controls
- browse for scene paths
- save theme JSON anywhere
- export theme JSON to:
	- `../GameProject/data/levels/themes/`

## What M24.1 does not do yet
- validation
- preview room
- live scene contract checking
