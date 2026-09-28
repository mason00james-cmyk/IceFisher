extends Node2D

const SHEET := preload("res://art/spritesheet.png")
const ROCK := preload("res://scenes/rock.tscn")
const NIBBLER := preload("res://scenes/nibbler.tscn")
const TARGET := preload("res://scenes/target.tscn")
const CELL := 64
const SCALE_FIX := 2.0
const PUFFER_REGION := Rect2(512, 576, 64, 64)

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
var LAYOUTS := {
	"level_1": [
		# steering
		["rock", Vector2(-200, 250)],
		["rock", Vector2(180, 380)],
		# guaranteed bite
		["biter", Vector2(0, 750), true],
		# fish to avoid
		["nibbler", Vector2(-280, 1000), true],
		["nibbler", Vector2(260, 1080), true],
		# rock lesson
		["rock", Vector2(-120, 1280)],
		["rock", Vector2(-120, 1340)],
		["nibbler", Vector2(-250, 1310), true],
		["rock", Vector2(120, 1480)],
		["rock", Vector2(120, 1540)],
		["nibbler", Vector2(250, 1510), true],
		# the big bite
		["puffer", Vector2(0, 2000), true],
		# the prize
		["target", Vector2(0, 2190)],
	],
	"level_2": [],
}

# Decoration: plants sit on the floor at x; wallrocks go at (x, y)
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
	"level_2": [],
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
			var p = NIBBLER.instantiate()
			p.nibble_damage = 100.0
			p.chase_range = 200.0
			p.chase_speed = 300.0
			p.scale = Vector2(1.4, 1.4)
			var spr: Sprite2D = p.get_node("Sprite2D")
			spr.region_rect = PUFFER_REGION
			spr.scale = Vector2(1.0, 1.0)
			return p
	return null

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
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(1300, 40)
	shape.shape = rect
	body.add_child(shape)
	body.position = Vector2(0, floor_y)
	add_child(body)

func _make_decor(d: Array):
	match d[0]:
		"plant":
			_plant(d[1], d[2], d[3], -2)
		"bgplant":
			var s := _plant(d[1], d[2], d[3], -8)
			s.modulate = Color(1, 1, 1, 0.5)
		"wallrock":
			var s := _sprite(d[1], Vector2(d[2], d[3]), 0.8, -1)
			s.flip_h = d[2] > 0

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
	var b := _sprite(Vector2i(9, [3, 4, 5].pick_random()), Vector2.ZERO, randf_range(0.15, 0.3), -3)
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
