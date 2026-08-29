class_name BrawlMapCatalog
extends RefCounted

const TEST_MAP_ID := "stage_b_test_arena"
const LARGE_BRAWL_MAP_ID := "large_brawl_01"
const PATHS := {
	TEST_MAP_ID: "res://maps/stage_b_test_arena.json",
	LARGE_BRAWL_MAP_ID: "res://maps/large_brawl_01.json",
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
