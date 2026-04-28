extends RefCounted

## Deterministic weighted variant selection with basic repetition avoidance.

func select_variant(
	variants: Array,
	level_id: String,
	theme_id: String,
	slot_index: int,
	slot_category: String,
	perimeter_cells: int,
	recent_variant_ids: Array
) -> Resource:
	var candidates: Array = []
	for variant_resource in variants:
		if variant_resource == null:
			continue
		if not variant_resource.is_allowed_for_perimeter(perimeter_cells):
			continue
		if int(variant_resource.weight) <= 0:
			continue
		candidates.append(variant_resource)

	if candidates.is_empty():
		return null

	var filtered: Array = _filter_repetition(candidates, recent_variant_ids)
	if filtered.is_empty():
		filtered = candidates

	var seed_text: String = "%s|%s|%s|%s|%s" % [
		level_id,
		theme_id,
		slot_category,
		slot_index,
		perimeter_cells
	]
	var hash_value: int = abs(int(hash(seed_text)))
	var total_weight: int = 0
	for candidate in filtered:
		total_weight += int(candidate.weight)

	if total_weight <= 0:
		return filtered[0]

	var roll: int = hash_value % total_weight
	var running_weight: int = 0
	for candidate in filtered:
		running_weight += int(candidate.weight)
		if roll < running_weight:
			return candidate

	return filtered[0]

func _filter_repetition(candidates: Array, recent_variant_ids: Array) -> Array:
	if recent_variant_ids.size() < 2:
		return candidates

	var recent_last: String = str(recent_variant_ids[recent_variant_ids.size() - 1])
	var recent_prev: String = str(recent_variant_ids[recent_variant_ids.size() - 2])
	if recent_last != recent_prev:
		return candidates

	var filtered: Array = []
	for candidate in candidates:
		if str(candidate.variant_id) == recent_last:
			continue
		filtered.append(candidate)
	return filtered
