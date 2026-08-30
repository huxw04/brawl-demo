class_name BrawlMapCatalog
extends RefCounted

const TEST_MAP_ID := "stage_b_test_arena"
const LARGE_BRAWL_MAP_ID := "large_brawl_01"
const WIND_GORGE_MAP_ID := "wind_gorge_01"
const BROKEN_CHESS_MAP_ID := "broken_chess_01"
const NETWORK_MAP_IDS := [LARGE_BRAWL_MAP_ID, WIND_GORGE_MAP_ID, BROKEN_CHESS_MAP_ID]
const PATHS := {
	TEST_MAP_ID: "res://maps/stage_b_test_arena.json",
	LARGE_BRAWL_MAP_ID: "res://maps/large_brawl_01.json",
	WIND_GORGE_MAP_ID: "res://maps/wind_gorge_01.json",
	BROKEN_CHESS_MAP_ID: "res://maps/broken_chess_01.json",
}


static func load_definition(map_id: String) -> BrawlMapDefinition:
	var path := str(PATHS.get(map_id, ""))
	if path.is_empty():
		push_error("Unknown map id: %s" % map_id)
		return null
	var definition := BrawlMapDefinition.load_from_file(path)
	if definition != null and definition.map_id != map_id:
		push_error("Map id does not match catalog key: %s" % map_id)
		return null
	return definition


static func default_test_map() -> BrawlMapDefinition:
	return load_definition(TEST_MAP_ID)


static func default_network_map() -> BrawlMapDefinition:
	return load_definition(LARGE_BRAWL_MAP_ID)


static func network_map_ids() -> Array[String]:
	var result: Array[String] = []
	for map_id in NETWORK_MAP_IDS:
		result.append(str(map_id))
	return result


static func is_network_map(map_id: String) -> bool:
	return map_id in NETWORK_MAP_IDS


static func display_name(map_id: String) -> String:
	var definition := load_definition(map_id)
	return definition.display_name if definition != null else map_id
