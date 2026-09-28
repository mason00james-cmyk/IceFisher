extends Node2D

@export var swim_distance := 80.0
@export var swim_speed := 0.6

var home: Vector2
var t := 0.0
var hooked := false

@onready var sprite: Sprite2D = $Sprite2D

func _ready():
	home = position
	$Mouth.add_to_group("target")
	var pulse = create_tween().set_loops()
	pulse.tween_property(sprite, "modulate", Color(1.6, 1.4, 0.4), 0.6)
	pulse.tween_property(sprite, "modulate", Color(1.0, 0.85, 0.2), 0.6)

func _process(delta):
	if hooked:
		return
	t += delta
	position = home + Vector2(sin(t * swim_speed) * swim_distance, 0)
	sprite.flip_h = cos(t * swim_speed) < 0

func on_hooked():
	hooked = true
	rotation_degrees = -90
