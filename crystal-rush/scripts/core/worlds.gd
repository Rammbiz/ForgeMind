class_name Worlds
## The worlds a campaign travels through. Each has its own road (a sculpted module repeated
## along the run), sky, light and scenery.
##
## "road_fit" describes the road module in its own file: it runs along X, the walkway between
## the railings spans walk_min..walk_max in Z with its surface at `top`, and one module covers
## x_min..x_min + length. `vscale` flattens the module so railings stay low.
##
## "models" maps model keys to optional GLB overrides (Models.asset). Missing files are fine:
## every Models builder falls back to its procedural model. Keys: soldier (optional soldier_1,
## soldier_2 per army tier), raider, gate (frame only), barricade, sweeper, geode, turret,
## rotor, fortress, crate, ballista, cannon, laser, rockets, drone.

const LIST := {
	"space": {
		"name": "WORLD_SPACE",
		"road": "res://assets/worlds/space/road.glb",
		"road_fit": {"walk_min": -0.416, "walk_max": 0.189, "top": 0.08, "x_min": -0.92, "length": 1.87, "vscale": 0.55},
		"sky": "res://assets/worlds/space/sky.png",
		"sky_energy": 1.0,
		"ambient": Color(0.5, 0.52, 0.75),
		"ambient_energy": 0.7,
		# Warm nebula key light (fusion §6.3) so the porcelain HUD and the army pop.
		"sun": Color(1.0, 0.93, 0.84),
		"sun_energy": 1.0,
		"road_tint": Color(0.78, 0.8, 0.88),
		"scenery": "space",
		"models": {
			"soldier": "res://assets/worlds/space/soldier.glb",
			"raider": "res://assets/worlds/space/raider.glb",
			"gate": "res://assets/worlds/space/gate.glb",
			"barricade": "res://assets/worlds/space/barricade.glb",
			"geode": "res://assets/worlds/space/geode.glb",
			"turret": "res://assets/worlds/space/turret.glb",
			"rotor": "res://assets/worlds/space/rotor.glb",
			"fortress": "res://assets/worlds/space/fortress.glb",
			"crate": "res://assets/worlds/space/crate.glb",
			"ballista": "res://assets/worlds/space/ballista.glb",
			"cannon": "res://assets/worlds/space/cannon.glb",
			"laser": "res://assets/worlds/space/laser.glb",
			"rockets": "res://assets/worlds/space/rockets.glb",
			"drone": "res://assets/worlds/space/drone.glb",
		},
	},
	"reef": {
		"name": "WORLD_REEF",
		"road": "res://assets/worlds/space/road.glb",
		"road_fit": {"walk_min": -0.416, "walk_max": 0.189, "top": 0.08, "x_min": -0.92, "length": 1.87, "vscale": 0.55},
		"sky": "res://assets/worlds/space/sky.png",
		"sky_energy": 1.0,
		# World 2 palette swap (UI v2 final pass): turquoise water light, coral nebula, a warm
		# key light and teal planks on the same road and models.
		"ambient": Color(0.5, 0.7, 0.72),
		"ambient_energy": 0.78,
		"sun": Color(1.0, 0.9, 0.76),
		"sun_energy": 1.05,
		"road_tint": Color(0.62, 0.9, 0.86),
		"neb_a": Color(0.1, 0.62, 0.7),
		"neb_b": Color(0.18, 0.4, 0.62),
		"neb_c": Color(1.0, 0.52, 0.42),
		"deep": Color(0.01, 0.04, 0.06),
		"fog_color": Color(0.08, 0.26, 0.3),
		"rim_light": Color(1.0, 0.62, 0.5),
		"rim_energy": 0.5,
		"vein_glow": 0.75,
		"scenery": "space",
		"models": {
			"soldier": "res://assets/worlds/space/soldier.glb",
			"raider": "res://assets/worlds/space/raider.glb",
			"gate": "res://assets/worlds/space/gate.glb",
			"barricade": "res://assets/worlds/space/barricade.glb",
			"geode": "res://assets/worlds/space/geode.glb",
			"turret": "res://assets/worlds/space/turret.glb",
			"rotor": "res://assets/worlds/space/rotor.glb",
			"fortress": "res://assets/worlds/space/fortress.glb",
			"crate": "res://assets/worlds/space/crate.glb",
			"ballista": "res://assets/worlds/space/ballista.glb",
			"cannon": "res://assets/worlds/space/cannon.glb",
			"laser": "res://assets/worlds/space/laser.glb",
			"rockets": "res://assets/worlds/space/rockets.glb",
			"drone": "res://assets/worlds/space/drone.glb",
		},
	},
}

const ORDER: Array[String] = ["space", "reef"]
const LEVELS_PER_WORLD := 5


## GLB override path for model `key` in world `w` ("" when none is listed).
static func model_path(w: Dictionary, key: String) -> String:
	return str((w.get("models", {}) as Dictionary).get(key, ""))


## The world of campaign `level` (the meta's 8-level worlds, ArsenalData.world_of): World 1
## space, World 2 the reef, then they alternate until more worlds exist.
static func for_level(level: int) -> Dictionary:
	var w := ArsenalData.world_of(maxi(level, 1))
	return LIST[ORDER[(w - 1) % ORDER.size()]]
