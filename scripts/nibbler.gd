extends CharacterBody2D

@export var nibble_damage := 15.0
@export var chase_range := 250.0
@export var chase_speed := 120.0
@export var idle_speed := 40.0
@export var wander_distance := 60.0

var hook: Node2D
var home: Vector2
var t := 0.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready():
	home = global_position
	hook = get_tree().get_first_node_in_group("hook")
	$Mouth.add_to_group("nibbler")

func _physics_process(delta):
	t += delta
	var goal: Vector2
	var speed: float
	if hook and hook.underwater and global_position.distance_to(hook.global_position) < chase_range:
		goal = hook.global_position
		speed = chase_speed
	else:
		goal = home + Vector2(sin(t * 0.8) * wander_distance, 0)
		speed = idle_speed
	velocity = global_position.direction_to(goal) * speed
	move_and_slide()
	if abs(velocity.x) > 1:
		sprite.flip_h = velocity.x < 0
