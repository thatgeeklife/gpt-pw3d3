extends RefCounted

## Shared authoring contract for modular theme-kit scenes.
## This does not force the runtime to use authored scenes yet; it defines the footprint rules.

const FLOOR_WORLD_SIZE: float = 2.0
const WALL_SEGMENT_WORLD_LENGTH: float = 2.0
const DEFAULT_WALL_HEIGHT: float = 5.0
const DEFAULT_WALL_THICKNESS: float = 0.5
const EXPECTED_FORWARD_AXIS: String = "+Z"
const EXPECTED_ROOT_NOTE: String = "Root centered on footprint, y=0 at floor contact."

func build_default_contract_dictionary() -> Dictionary:
	return {
		"floor_world_size": FLOOR_WORLD_SIZE,
		"wall_segment_world_length": WALL_SEGMENT_WORLD_LENGTH,
		"default_wall_height": DEFAULT_WALL_HEIGHT,
		"default_wall_thickness": DEFAULT_WALL_THICKNESS,
		"expected_forward_axis": EXPECTED_FORWARD_AXIS,
		"expected_root_note": EXPECTED_ROOT_NOTE,
	}

func build_scene_validation_report(theme: Resource) -> Dictionary:
	var report := {
		"is_valid": true,
		"missing_paths": [],
		"present_paths": [],
		"notes": [],
	}
	if theme == null:
		report["is_valid"] = false
		report["notes"].append("Theme was null.")
		return report

	for scene_path in theme.get_authored_scene_paths():
		if scene_path.is_empty():
			continue
		if ResourceLoader.exists(scene_path):
			report["present_paths"].append(scene_path)
		else:
			report["missing_paths"].append(scene_path)

	if Array(report["missing_paths"]).size() > 0:
		report["is_valid"] = false

	report["notes"].append("Expected floor piece footprint: %s x %s world units." % [FLOOR_WORLD_SIZE, FLOOR_WORLD_SIZE])
	report["notes"].append("Expected wall segment length: %s world units." % WALL_SEGMENT_WORLD_LENGTH)
	report["notes"].append("Expected wall forward axis: %s." % EXPECTED_FORWARD_AXIS)
	report["notes"].append(EXPECTED_ROOT_NOTE)
	return report
