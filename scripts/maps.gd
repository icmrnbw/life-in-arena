class_name Maps
extends RefCounted
## Arena layouts. A run fights in one of these (Run.cfg["map"]); Run.setup() sets Maps.cur before anything is built,
## so the arena logic (pillars, gates, barrel stacks) and the art (art/world.gd) both read the same layout.
## Every arena is a ring of radius DB.ARENA_R round the origin; they differ in pillars, gates, barrel stacks and look.
## Gates use the same keys as DB.GATES ("N", "E", "W", "NE") so wave bursts work on every map.
## Delve mode doesn't use an arena: its dungeon is scripts/delve.gd.

const ORDER := ["pit", "hollow"]
const MAPS := {
	"pit": {"name": "The Pit", "desc": "The ember-lit ring where it all began. Three pillars, three barrel stacks.",
		"pillars": DB.PILLARS, "gates": DB.GATES, "stacks": DB.STACKS, "kegs": DB.KEGS},
	"hollow": {"name": "Rimefang Hollow", "desc": "A frozen ring. Five pillars, foes from both flanks, two barrel stacks by your spawn.",
		"pillars": [Vector3(-12, 0, -2), Vector3(12, 0, -2), Vector3(-6, 0, -13), Vector3(6, 0, -13), Vector3(0, 0, 7)],
		# angles -120, -60, 15 and 165 degrees: two gates up north, two low on the flanks
		"gates": {"N": Vector3(-10.5, 0, -18.2), "NE": Vector3(10.5, 0, -18.2), "E": Vector3(20.3, 0, 5.4), "W": Vector3(-20.3, 0, 5.4)},
		"stacks": [
			{"sx": 1, "sz": 1, "t": 9.5, "kegs": [Vector3(13.8, 0, 16.0)]},
			{"sx": -1, "sz": 1, "t": 9.5, "kegs": [Vector3(-13.8, 0, 16.0)]},
		],
		"kegs": [Vector3(0, 0, -6.5), Vector3(-15.5, 0, -8.0), Vector3(15.5, 0, -8.0)],
		"theme": "frost"},
	# Delve mode: no arena at all (the dungeon is scripts/delve.gd); the camp is still built
	"delve": {"name": "The Undercroft", "desc": "", "pillars": [], "gates": DB.GATES, "stacks": [], "kegs": [], "theme": "none"},
}

## The arena the current run fights in.
static var cur := "pit"


static func use(id: String) -> void:
	cur = id if MAPS.has(id) else "pit"


static func data() -> Dictionary:
	return MAPS.get(cur, MAPS["pit"])


static func pillars() -> Array:
	return data()["pillars"]


static func gates() -> Dictionary:
	return data()["gates"]


static func stacks() -> Array:
	return data()["stacks"]


static func kegs() -> Array:
	return data()["kegs"]


static func theme() -> String:
	return data().get("theme", "ember")


static func map_name(id: String) -> String:
	return String(MAPS.get(id, MAPS["pit"])["name"])
