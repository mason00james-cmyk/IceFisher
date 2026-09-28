extends CharacterBody2D

@export var nibble_damage := 15.0
@export var chase_range := 250.0
@export var chase_speed := 120.0
@export var idle_speed := 40.0
@export var wander_distance := 60.0
@export var turn_smoothing := 4.0
@export var bites_once := false

var hook: Node2D
var home: Vector2
var t := 0.0
var retreat_time := 0.0
var facing_left := false

@onready var sprite: Sprite2D = $Sprite2D

func _ready():
	home = global_position
	hook = get_tree().get_first_node_in_group("hook")
	$Mouth.add_to_group("nibbler")

func _physics_process(delta):
	t += delta
	var goal: Vector2
	var speed: float
	var to_hook := Vector2.ZERO
	if hook:
		to_hook = hook.global_position - global_position

	if retreat_time > 0.0:
		retreat_time -= delta
		goal = global_position - to_hook.normalized() * 100.0
		speed = chase_speed
	elif hook and hook.underwater and hook.bait_hp > 0.0 and to_hook.length() < chase_range:
		goal = hook.global_position
		speed = chase_speed
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

func on_bite():
	retreat_time = 999.0 if bites_once else 0.8
	
