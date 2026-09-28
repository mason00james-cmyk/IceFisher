extends Node2D

const SHEET := preload("res://art/spritesheet.png")
const ROCK := preload("res://scenes/rock.tscn")
const NIBBLER := preload("res://scenes/nibbler.tscn")
const TARGET := preload("res://scenes/target.tscn")
const CELL := 64
const SCALE_FIX := 2.0
const PUFFER_REGION := Rect2(512, 576, 64, 64)
const EEL_REGION := Rect2(512, 256, 64, 64)
const WALL_SPACING := 60.0

@export_enum("level_1", "level_2") var layout := "level_1"

var floor_y := 2300.0
var floor_top := 2280.0

var THEMES := {
	"level_1": {
		"floor_y": 2300.0,
		"sand": Vector2i(0, 0),
		"fill": Vector2i(1, 7),
		"top": Color(0.35, 0.78, 0.95),
		"bottom": Color(0.05, 0.25, 0.5),
	},
	"level_2": {
		"floor_y": 4000.0,
		"sand": Vector2i(2, 0),
		"fill": Vector2i(3, 2),
		"top": Color(0.12, 0.35, 0.55),
		"bottom": Color(0.02, 0.04, 0.12),
	},
}

# Gameplay: [kind, position, cleared after tutorial bait loss?]
# Walls:    ["wall", y, gap_x, gap_width]
var LAYOUTS := {
	"level_1": [
		["rock", Vector2(-200, 250)],
		["rock", Vector2(180, 380)],
		["biter", Vector2(0, 750), true],
		["nibbler", Vector2(-280, 1000), true],
		["nibbler", Vector2(260, 1080), true],
		["rock", Vector2(-120, 1280)],
		["rock", Vector2(-120, 1340)],
		["nibbler", Vector2(-250, 1310), true],
		["rock", Vector2(120, 1480)],
		["rock", Vector2(120, 1540)],
		["nibbler", Vector2(250, 1510), true],
		["puffer", Vector2(0, 1950), true],
		["target", Vector2(0, 2190)],
	],
	"level_2": [
		# the drop
		["rock", Vector2(-250, 400)],
		["rock", Vector2(300, 560)],
		# the school
		["nibbler", Vector2(-540, 930)],
		["nibbler", Vector2(-405, 990)],
		["nibbler", Vector2(-270, 930)],
		["nibbler", Vector2(-135, 990)],
		["nibbler", Vector2(0, 930)],
		["nibbler", Vector2(135, 990)],
		["nibbler", Vector2(270, 930)],
		["nibbler", Vector2(405, 990)],
		["nibbler", Vector2(540, 930)],
		# the maze
		["wall", 1400.0, 420.0, 180.0],
		["nibbler", Vector2(-450, 1560)],
		["eel", Vector2(0, 1650)],
		["wall", 1800.0, -420.0, 180.0],
		["nibbler", Vector2(450, 1960)],
		["eel", Vector2(0, 2050)],
		["wall", 2200.0, 380.0, 180.0],
		["nibbler", Vector2(-420, 2360)],
		["wall", 2600.0, -380.0, 180.0],
		# the graveyard
		["puffer_mid", Vector2(-200, 3000)],
		["puffer_mid", Vector2(250, 3220)],
		# the den
		["rock", Vector2(-190, 3780)],
		["rock", Vector2(190, 3780)],
		["puffer_mid", Vector2(0, 3580)],
		["target", Vector2(0, 3780)],
	],
}

# plant / bgplant: [kind, cell, x, scale] sits on the floor
# wallrock:        [kind, cell, x, y] solid
# deco:            [kind, cell, x, y, scale] floats in place
var DECOR := {
	"level_1": [
		["bgplant", Vector2i(10, 3), -420, 1.0],
		["bgplant", Vector2i(9, 9), 60, 1.0],
		["bgplant", Vector2i(10, 3), 380, 1.0],
		["plant", Vector2i(4, 10), -570, 0.7],
		["plant", Vector2i(3, 10), -480, 0.6],
		["plant", Vector2i(4, 0), -350, 0.5],
		["plant", Vector2i(5, 3), -230, 0.6],
		["plant", Vector2i(5, 3), 230, 0.6],
		["plant", Vector2i(4, 1), 340, 0.5],
		["plant", Vector2i(4, 10), 460, 0.7],
		["plant", Vector2i(3, 10), 570, 0.7],
		["wallrock", Vector2i(5, 5), -600, 250],
		["wallrock", Vector2i(5, 6), 600, 500],
		["wallrock", Vector2i(5, 4), -600, 900],
		["wallrock", Vector2i(5, 7), 600, 1250],
		["wallrock", Vector2i(5, 5), -600, 1600],
		["wallrock", Vector2i(5, 6), 600, 1950],
	],
	"level_2": [
		["bgplant", Vector2i(10, 3), -300, 1.0],
		["bgplant", Vector2i(9, 9), 350, 1.0],
		["plant", Vector2i(4, 10), -520, 0.6],
		["plant", Vector2i(3, 11), -380, 0.6],
		["plant", Vector2i(4, 11), 420, 0.6],
		["plant", Vector2i(3, 10), 540, 0.6],
		["wallrock", Vector2i(5, 5), -600, 300],
		["wallrock", Vector2i(5, 6), 600, 700],
		["wallrock", Vector2i(5, 4), -600, 1150],
		["wallrock", Vector2i(5, 7), 600, 2900],
		["wallrock", Vector2i(5, 5), -600, 3300],
		["wallrock", Vector2i(5, 6), 600, 3600],
		["deco", Vector2i(7, 0), -380, 2950, 0.8],
		["deco", Vector2i(9, 0), 320, 3050, 0.7],
		["deco", Vector2i(8, 5), -120, 3300, 0.8],
		["deco", Vector2i(8, 6), 420, 3400, 0.7],
		["deco", Vector2i(6, 11), -450, 3500, 0.9],
		["deco", Vector2i(8, 11), -350, 3960, 0.8],
		["deco", Vector2i(7, 11), 330, 3960, 0.8],
	],
}


func _ready():
	var th: Dictionary = THEMES[layout]
	floor_y = th["floor_y"]
	floor_top = floor_y - 20.0
	_make_water(th)
	_make_floor(th)
	for d in DECOR[layout]:
		_make_decor(d)
	for entry in LAYOUTS[layout]:
		if entry[0] == "wall":
			_make_wall(entry[1], entry[2], entry[3])
			continue
		var node: Node2D = _make(entry[0])
		node.position = entry[1]
		if entry.size() > 2 and entry[2]:
			node.add_to_group("clear_on_recast")
		add_child(node)
	for i in 14:
		_make_bubble()
	_set_camera_limits()


# ---------- gameplay pieces ----------

func _make(kind: String) -> Node2D:
	match kind:
		"rock":
			return ROCK.instantiate()
		"nibbler":
			return NIBBLER.instantiate()
		"target":
			return TARGET.instantiate()
		"biter":
			var b = NIBBLER.instantiate()
			b.chase_speed = 320.0
			b.chase_range = 300.0
			b.nibble_damage = 25.0
			b.bites_once = true
			return b
		"puffer":
			# tutorial guard: unavoidable once you're below 1800
			return _puffer(100.0, 2000.0, 380.0, 1800.0)
		"puffer_mid":
			return _puffer(60.0, 200.0, 180.0)
		"eel":
			var e = NIBBLER.instantiate()
			e.nibble_damage = 30.0
			e.chase_range = 0.0
			e.wander_distance = 450.0
			e.idle_speed = 220.0
			e.scale = Vector2(1.3, 1.3)
			var spr: Sprite2D = e.get_node("Sprite2D")
			spr.region_rect = EEL_REGION
			spr.scale = Vector2(1.0, 1.0)
			return e
	return null


func _puffer(damage: float, range_px: float, speed: float, depth := -100000.0) -> Node2D:
	var p = NIBBLER.instantiate()
	p.nibble_damage = damage
	p.chase_range = range_px
	p.chase_speed = speed
	p.activate_depth = depth
	p.puffs = true
	p.scale = Vector2(1.4, 1.4)
	var spr: Sprite2D = p.get_node("Sprite2D")
	spr.region_rect = PUFFER_REGION
	spr.scale = Vector2(1.0, 1.0)
	return p


func _make_wall(y: float, gap_x: float, gap_w: float):
	var x := -600.0
	while x <= 600.0:
		if abs(x - gap_x) > gap_w / 2.0:
			var r: Node2D = ROCK.instantiate()
			r.position = Vector2(x, y)
			add_child(r)
		x += WALL_SPACING


# ---------- looks ----------

func _sprite(cellv: Vector2i, pos: Vector2, sc: float, z: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = SHEET
	s.region_enabled = true
	s.region_rect = Rect2(cellv.x * CELL, cellv.y * CELL, CELL, CELL)
	s.position = pos
	s.scale = Vector2(sc, sc) * SCALE_FIX
	s.z_index = z
	add_child(s)
	return s


func _make_water(th: Dictionary):
	var grad := Gradient.new()
	grad.set_color(0, th["top"])
	grad.set_color(1, th["bottom"])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 1280
	tex.height = int(floor_y + 300)
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.position = Vector2(-640, 0)
	s.z_index = -10
	add_child(s)


func _make_floor(th: Dictionary):
	for x in range(-640, 640, 64):
		_sprite(th["sand"], Vector2(x + 32, floor_top + 32), 0.5, -5)
		for row in [1, 2, 3]:
			_sprite(th["fill"], Vector2(x + 32, floor_top + 32 + row * 64), 0.5, -5)
	_add_blocker(Vector2(0, floor_y), Vector2(1300, 40))


func _make_decor(d: Array):
	match d[0]:
		"plant":
			_plant(d[1], d[2], d[3], -2)
		"bgplant":
			var s := _plant(d[1], d[2], d[3], -8)
			s.modulate = Color(1, 1, 1, 0.5)
		"wallrock":
			var pos := Vector2(d[2], d[3])
			var s := _sprite(d[1], pos, 0.8, -1)
			s.flip_h = d[2] > 0
			_add_blocker(pos, Vector2(90, 70))
		"deco":
			var s := _sprite(d[1], Vector2(d[2], d[3]), d[4], -1)
			s.modulate = Color(1, 1, 1, 0.85)


func _add_blocker(pos: Vector2, size: Vector2):
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	body.position = pos
	add_child(body)


func _plant(cellv: Vector2i, x: float, sc: float, z: int) -> Sprite2D:
	var s := _sprite(cellv, Vector2(x, floor_top + 8), sc, z)
	s.offset = Vector2(0, -CELL / 2.0)
	s.rotation_degrees = randf_range(-4.0, 4.0)
	var dur := randf_range(1.4, 2.4)
	var t := create_tween().set_loops()
	t.tween_property(s, "rotation_degrees", 4.0, dur).set_trans(Tween.TRANS_SINE)
	t.tween_property(s, "rotation_degrees", -4.0, dur).set_trans(Tween.TRANS_SINE)
	return s


func _make_bubble():
	var b := _sprite(Vector2i(9, [3, 4, 5].pick_random()), Vector2.ZERO,
		randf_range(0.15, 0.3), -3)
	b.modulate = Color(1, 1, 1, 0.6)
	_rise(b, true)


func _rise(b: Sprite2D, first: bool):
	var start_y: float = randf_range(60.0, floor_top) if first else floor_top
	b.position = Vector2(randf_range(-600.0, 600.0), start_y)
	var dur: float = (start_y - 20.0) / randf_range(60.0, 120.0)
	var t := create_tween()
	t.tween_property(b, "position:y", 20.0, dur)
	t.tween_callback(_rise.bind(b, false))


func _set_camera_limits():
	var cam := get_node_or_null("../Hook/Camera2D") as Camera2D
	if cam:
		cam.limit_left = -640
		cam.limit_right = 640
		cam.limit_top = -800
		cam.limit_bottom = int(floor_top + 256)
