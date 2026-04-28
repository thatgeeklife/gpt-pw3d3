extends RefCounted

## Runtime state for one active chunk window entry.

var chunk_index: int = -1
var chunk_coord: Vector2i = Vector2i.ZERO
var tile_indices: PackedInt32Array = PackedInt32Array()
var is_built: bool = false
var is_visible: bool = false
var is_dirty: bool = false

func configure(new_chunk_index: int, new_chunk_coord: Vector2i, new_tile_indices: PackedInt32Array) -> void:
	chunk_index = new_chunk_index
	chunk_coord = new_chunk_coord
	tile_indices = new_tile_indices
	is_built = false
	is_visible = false
	is_dirty = false