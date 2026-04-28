extends Control

const PARCHMENT_BG: Color = Color(0.86, 0.78, 0.61, 0.92)
const PARCHMENT_TILE: Color = Color(0.82, 0.74, 0.57, 1.0)
const PARCHMENT_OUTLINE: Color = Color(0.54, 0.42, 0.27, 0.45)

var level_definition: Resource = null
var session_state: Resource = null
var generated_root: Node3D = null
var player_node: Node3D = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _process(_delta: float) -> void:
	if visible:
		queue_redraw()

func set_state(
	new_level_definition: Resource,
	new_session_state: Resource,
	new_generated_root: Node3D,
	new_player_node: Node3D
) -> void:
	level_definition = new_level_definition
	session_state = new_session_state
	generated_root = new_generated_root
	player_node = new_player_node
	queue_redraw()

func clear_state() -> void:
	level_definition = null
	session_state = null
	generated_root = null
	player_node = null
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PARCHMENT_BG, true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.39, 0.30, 0.18, 0.35), false, 2.0)

	if level_definition == null or generated_root == null:
		return

	var bounds: Dictionary = Dictionary(generated_root.get_meta("bounds", {}))
	var border_tiles: int = int(generated_root.get_meta("border_tiles", 5))
	var room_width_cells: int = int(generated_root.get_meta("room_width_cells", 1))
	var room_depth_cells: int = int(generated_root.get_meta("room_depth_cells", 1))
	if room_width_cells <= 0 or room_depth_cells <= 0:
		return

	var padding: float = 6.0
	var draw_width: float = max(size.x - (padding * 2.0), 1.0)
	var draw_height: float = max(size.y - (padding * 2.0), 1.0)
	var cell_size: float = min(draw_width / float(room_width_cells), draw_height / float(room_depth_cells))

	var content_width: float = float(room_width_cells) * cell_size
	var content_height: float = float(room_depth_cells) * cell_size
	var origin: Vector2 = Vector2(
		(size.x - content_width) * 0.5,
		(size.y - content_height) * 0.5
	)

	draw_rect(Rect2(origin, Vector2(content_width, content_height)), PARCHMENT_BG.darkened(0.04), true)

	for pixel_resource in level_definition.pixels:
		if pixel_resource == null:
			continue

		var cell_x: int = (pixel_resource.grid_pos.x - int(bounds.get("min_x", 0))) + border_tiles
		var cell_y: int = (pixel_resource.grid_pos.y - int(bounds.get("min_y", 0))) + border_tiles

		var tile_color: Color = PARCHMENT_TILE
		if session_state != null and session_state.is_tile_completed(int(pixel_resource.pixel_id)):
			tile_color = pixel_resource.source_color

		var rect := Rect2(
			origin + Vector2(float(cell_x) * cell_size, float(cell_y) * cell_size),
			Vector2(cell_size, cell_size)
		)
		draw_rect(rect, tile_color, true)
		draw_rect(rect, PARCHMENT_OUTLINE, false, 1.0)

	if player_node != null and is_instance_valid(player_node):
		_draw_player_marker(origin, cell_size, room_width_cells, room_depth_cells)

func _draw_player_marker(origin: Vector2, cell_size: float, room_width_cells: int, room_depth_cells: int) -> void:
	var local_position: Vector3 = generated_root.to_local(player_node.global_position)
	var room_center_x: float = (float(room_width_cells) - 1.0) * 0.5
	var room_center_y: float = (float(room_depth_cells) - 1.0) * 0.5

	var cell_x: float = local_position.x + room_center_x
	var cell_y: float = local_position.z + room_center_y

	var center: Vector2 = origin + Vector2(
		(cell_x + 0.5) * cell_size,
		(cell_y + 0.5) * cell_size
	)

	draw_circle(center, max(cell_size * 0.20, 2.5), Color(0.12, 0.16, 0.19, 1.0))

	var forward: Vector3 = -player_node.global_transform.basis.z.normalized()
	var arrow_dir: Vector2 = Vector2(forward.x, forward.z)
	if arrow_dir.length() <= 0.001:
		return
	arrow_dir = arrow_dir.normalized()

	var arrow_tip: Vector2 = center + (arrow_dir * max(cell_size * 0.60, 6.0))
	var right: Vector2 = Vector2(-arrow_dir.y, arrow_dir.x)

	var p1: Vector2 = arrow_tip
	var p2: Vector2 = center - (arrow_dir * max(cell_size * 0.20, 2.0)) + (right * max(cell_size * 0.22, 2.0))
	var p3: Vector2 = center - (arrow_dir * max(cell_size * 0.20, 2.0)) - (right * max(cell_size * 0.22, 2.0))

	draw_colored_polygon(PackedVector2Array([p1, p2, p3]), Color(0.93, 0.30, 0.12, 1.0))