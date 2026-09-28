extends Node2D

const SHEET := preload("res://art/spritesheet.png")
const FISH_REGION := Rect2(448, 576, 64, 64)

@export var swim_distance := 80.0
@export var swim_speed := 0.6
@export var fish_scale := 1.6

var home: Vector2
var t := 0.0
var hooked := false
var glow: Sprite2D

@onready var sprite: Sprite2D = $Sprite2D


func _ready():
	home = position
	$Mouth.add_to_group("target")

	sprite.texture = SHEET
	sprite.region_enabled = true
	sprite.region_rect = FISH_REGION
	sprite.scale = Vector2.ONE * fish_scale
	sprite.modulate = Color.WHITE

	var shape = $Mouth/CollisionShape2D.shape
	if shape is CircleShape2D:
		shape.radius = 26.0 * fish_scale

	_make_glow()


func _make_glow():
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.9, 0.35, 0.9))
	g.set_color(1, Color(1.0, 0.75, 0.2, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 256
	tex.height = 256

	glow = Sprite2D.new()
	glow.texture = tex
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	glow.scale = Vector2.ONE * 0.8
	add_child(glow)
	move_child(glow, 0)

	var pulse := create_tween().set_loops()
	pulse.tween_property(glow, "scale", Vector2.ONE * 1.15, 0.8).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(glow, "scale", Vector2.ONE * 0.8, 0.8).set_trans(Tween.TRANS_SINE)


func _process(delta):
	if hooked:
		return
	t += delta
	position = home + Vector2(sin(t * swim_speed) * swim_distance, 0)
	sprite.flip_h = cos(t * swim_speed) < 0


func on_hooked():
	hooked = true
	sprite.flip_h = false
	rotation_degrees = -90.0


func on_escaped():
	hooked = false
	rotation_degrees = 0.0
