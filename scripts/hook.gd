extends CharacterBody2D

enum State { READY, SINKING, REELING, CATCH_REEL, DONE }

@export var water_y := 0.0
@export var sink_speed := 150.0
@export var steer_speed := 250.0
@export var reel_speed := 1000.0
@export var catch_reel_speed := 2500.0
@export var max_bait_hp := 100.0
@export var nibble_cooldown := 0.5

signal entered_water
signal exited_water
signal bait_changed(hp: float, max_hp: float)
signal level_complete

var state := State.READY
var bait_hp := 0.0
var can_be_nibbled := true
var underwater := false
var start_pos: Vector2

@onready var bite_area: Area2D = $BiteArea

func _ready():
	start_pos = global_position
	bait_hp = max_bait_hp

func _physics_process(delta):
	var steer := Input.get_axis("steer_left", "steer_right") * steer_speed

	match state:
		State.READY:
			if Input.is_action_just_pressed("cast"):
				state = State.SINKING
		State.SINKING:
			var down := sink_speed if bait_hp > 0 else 0.0
			velocity = Vector2(steer, down)
			move_and_slide()
			if Input.is_action_pressed("reel"):
				state = State.REELING
		State.REELING:
			global_position = global_position.move_toward(start_pos, reel_speed * delta)
			if not Input.is_action_pressed("reel"):
				state = State.SINKING
		State.CATCH_REEL:
			global_position = global_position.move_toward(start_pos, catch_reel_speed * delta)

	_check_water()
	_check_bites()

	if state in [State.REELING, State.CATCH_REEL] and global_position.distance_to(start_pos) < 1.0:
		_arrive_at_surface()

func _check_water():
	var now_under := global_position.y > water_y
	if now_under != underwater:
		underwater = now_under
		if underwater:
			entered_water.emit()
		else:
			exited_water.emit()

func _check_bites():
	if not underwater or state == State.CATCH_REEL:
		return
	for area in bite_area.get_overlapping_areas():
		if area.is_in_group("target"):
			_catch(area)
			return
		if area.is_in_group("nibbler") and can_be_nibbled and bait_hp > 0:
			_take_nibble(area.nibble_damage)
			return

func _take_nibble(amount: float):
	bait_hp = max(bait_hp - amount, 0.0)
	bait_changed.emit(bait_hp, max_bait_hp)
	can_be_nibbled = false
	get_tree().create_timer(nibble_cooldown).timeout.connect(func(): can_be_nibbled = true)

func _catch(fish: Node2D):
	state = State.CATCH_REEL
	if fish.has_method("on_hooked"):
		fish.on_hooked()
	fish.reparent(self)
	fish.position = Vector2(0, 24)

func _arrive_at_surface():
	bait_hp = max_bait_hp
	bait_changed.emit(bait_hp, max_bait_hp)
	if state == State.CATCH_REEL:
		state = State.DONE
		level_complete.emit()
	else:
		state = State.READY
