extends CharacterBody2D

@export var nibble_damage := 15.0
@export var chase_range := 250.0
@export var chase_speed := 120.0
@export var idle_speed := 40.0
@export var wander_distance := 60.0
@export var turn_smoothing := 4.0
@export var bites_once := false
@export var puffs := false
@export var activate_depth := -100000.0
@export var size_boost := 1.3
@export var outline_color := Color(1.0, 0.2, 0.2)

const OUTLINE_SHADER := """
shader_type canvas_item;
uniform vec4 outline_color : source_color = vec4(1.0, 0.2, 0.2, 1.0);
uniform float width = 1.5;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.a < 0.1) {
		vec2 px = TEXTURE_PIXEL_SIZE * width;
		float a = 0.0;
		a = max(a, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
		a = max(a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
		a = max(a, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
		a = max(a, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
		a = max(a, texture(TEXTURE, UV + px).a);
		a = max(a, texture(TEXTURE, UV - px).a);
		a = max(a, texture(TEXTURE, UV + vec2(px.x, -px.y)).a);
		a = max(a, texture(TEXTURE, UV + vec2(-px.x, px.y)).a);
		if (a > 0.1) {
			c = outline_color;
		}
	}
	COLOR = c * COLOR;
}
"""

static var _outline_shader: Shader

var hook: Node2D
var home: Vector2
var t := 0.0
var retreat_time := 0.0
var facing_left := false

# animation
var base_scale := Vector2.ONE
var anim_t := 0.0
var chasing := false
var puff := 0.0
var pop := 0.0

@onready var sprite: Sprite2D = $Sprite2D


func _ready():
	home = global_position
	hook = get_tree().get_first_node_in_group("hook")
	$Mouth.add_to_group("nibbler")

	# bigger + red outline = this fish is out to get you
	sprite.scale *= size_boost
	_apply_outline()

	base_scale = sprite.scale
	anim_t = randf() * TAU


func _apply_outline():
	if _outline_shader == null:
		_outline_shader = Shader.new()
		_outline_shader.code = OUTLINE_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _outline_shader
	mat.set_shader_parameter("outline_color", outline_color)
	sprite.material = mat


func _physics_process(delta):
	t += delta
	var goal: Vector2
	var speed: float
	var to_hook := Vector2.ZERO
	if hook:
		to_hook = hook.global_position - global_position

	var can_chase := false
	if hook and hook.underwater and hook.bait_hp > 0.0:
		var close_enough: bool = to_hook.length() < chase_range
		var deep_enough: bool = hook.global_position.y > activate_depth
		can_chase = close_enough and deep_enough

	chasing = false
	if retreat_time > 0.0:
		retreat_time -= delta
		goal = global_position - to_hook.normalized() * 100.0
		speed = chase_speed
	elif can_chase:
		goal = hook.global_position
		speed = chase_speed
		chasing = true
	else:
		goal = home + Vector2(sin(t * 0.8) * wander_distance, 0)
		speed = idle_speed

	var desired := Vector2.ZERO
	if global_position.distance_to(goal) > 6.0:
		desired = global_position.direction_to(goal) * speed
	velocity = velocity.lerp(desired, clamp(turn_smoothing * delta, 0.0, 1.0))
	move_and_slide()

	if velocity.x < -15.0:
		facing_left = true
	elif velocity.x > 15.0:
		facing_left = false
	sprite.flip_h = facing_left

	_animate(delta)


func _animate(delta: float):
	# tail wag: faster when swimming faster
	var freq := 4.0 + velocity.length() * 0.05
	anim_t += delta * freq
	sprite.skew = sin(anim_t) * 0.18
	sprite.position.y = sin(anim_t * 0.5) * 2.0

	# puff up while chasing (pufferfish only)
	var puff_goal := 1.0 if (puffs and chasing) else 0.0
	puff = move_toward(puff, puff_goal, delta * 3.0)

	# quick size pop after a bite
	pop = move_toward(pop, 0.0, delta * 5.0)

	sprite.scale = base_scale * (1.0 + 0.3 * puff + 0.2 * pop)


func on_bite():
	pop = 1.0
	retreat_time = 999.0 if bites_once else 0.8
