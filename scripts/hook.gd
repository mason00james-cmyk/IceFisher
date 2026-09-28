extends CharacterBody2D

enum State { READY, SINKING, REELING, CATCH_REEL, DONE, QTE, AUTO_REEL, STRUGGLE }

@export var water_y := 0.0
@export var sink_speed := 150.0
@export var steer_speed := 250.0
@export var reel_speed := 1000.0
@export var catch_reel_speed := 1200.0
@export var max_bait_hp := 100.0
@export var nibble_cooldown := 0.5

signal entered_water
signal exited_water
signal bait_changed(hp: float, max_hp: float)
signal level_complete
signal casted
signal qte_started
signal struggle_started

const FISH_OFFSET := Vector2(0, 20)

var state := State.READY
var bait_hp := 0.0
var can_be_nibbled := true
var underwater := false
var start_pos: Vector2

var hooked_fish: Node2D = null
var anchor := Vector2.ZERO
var jerk_timer := 0.0
var jerk_to := Vector2.ZERO


@onready var bite_area: Area2D = $BiteArea


func _ready():
	add_to_group("hook")
	start_pos = global_position
	bait_hp = max_bait_hp


func _physics_process(delta):
	var steer := 0.0
	if bait_hp > 0.0:
		steer = Input.get_axis("steer_left", "steer_right") * steer_speed

	match state:
		State.READY:
			if Input.is_action_just_pressed("cast"):
				state = State.SINKING
				casted.emit()
		State.SINKING:
			velocity = Vector2(steer, sink_speed)
			move_and_slide()
			if Input.is_action_pressed("reel"):
				state = State.REELING
		State.REELING:
			global_position = global_position.move_toward(start_pos, reel_speed * delta)
			if not Input.is_action_pressed("reel"):
				state = State.SINKING
		State.CATCH_REEL:
			global_position = global_position.move_toward(start_pos, catch_reel_speed * delta)
		State.QTE:
			pass
		State.AUTO_REEL:
			global_position = global_position.move_toward(start_pos, reel_speed * delta)
		State.STRUGGLE:
			_struggle(delta)

	# the hooked fish rides along with the hook
	if hooked_fish:
		hooked_fish.global_position = global_position + FISH_OFFSET

	_check_water()
	_check_bites()

	var going_up: bool = state in [State.REELING, State.CATCH_REEL, State.AUTO_REEL]
	if going_up and global_position.distance_to(start_pos) < 1.0:
		_arrive_at_surface()


func _struggle(delta: float):
	jerk_timer -= delta
	if jerk_timer <= 0.0:
		jerk_timer = randf_range(0.15, 0.45)
		jerk_to = anchor + Vector2(randf_range(-70.0, 70.0), randf_range(-35.0, 35.0))
		if hooked_fish:
			hooked_fish.rotation_degrees = -90.0 + randf_range(-35.0, 35.0)
	global_position = global_position.lerp(jerk_to, clamp(12.0 * delta, 0.0, 1.0))


func _check_water():
	var now_under := global_position.y > water_y
	if now_under != underwater:
		underwater = now_under
		if underwater:
			entered_water.emit()
		else:
			exited_water.emit()


func _check_bites():
	if not underwater or not state in [State.SINKING, State.REELING]:
		return
	for area in bite_area.get_overlapping_areas():
		var fish = area.owner
		if area.is_in_group("target"):
			_hook_target(fish)
			return
		if area.is_in_group("nibbler") and can_be_nibbled and bait_hp > 0:
			_take_nibble(fish.nibble_damage)
			if fish.has_method("on_bite"):
				fish.on_bite()
			return


func _take_nibble(amount: float):
	bait_hp = max(bait_hp - amount, 0.0)
	bait_changed.emit(bait_hp, max_bait_hp)
	can_be_nibbled = false
	get_tree().create_timer(nibble_cooldown).timeout.connect(func(): can_be_nibbled = true)
	if bait_hp <= 0.0:
		state = State.QTE
		velocity = Vector2.ZERO
		qte_started.emit()


func finish_qte():
	if state == State.QTE:
		state = State.AUTO_REEL


func _hook_target(fish: Node2D):
	state = State.STRUGGLE
	hooked_fish = fish
	fish.set_process(false)
	if fish.has_method("on_hooked"):
		fish.on_hooked()
	fish.z_index = 2
	anchor = global_position
	jerk_to = anchor
	jerk_timer = 0.0
	struggle_started.emit()


func finish_struggle(success: bool):
	if state != State.STRUGGLE:
		return
	if success:
		if hooked_fish:
			hooked_fish.rotation_degrees = -90.0
		state = State.CATCH_REEL
	else:
		if hooked_fish:
			hooked_fish.z_index = 0
			if hooked_fish.has_method("on_escaped"):
				hooked_fish.on_escaped()
			hooked_fish.set_process(true)
		hooked_fish = null
		bait_hp = 0.0
		bait_changed.emit(bait_hp, max_bait_hp)
		state = State.AUTO_REEL


func _arrive_at_surface():
	bait_hp = max_bait_hp
	bait_changed.emit(bait_hp, max_bait_hp)
	if state == State.CATCH_REEL:
		state = State.DONE
		level_complete.emit()
	else:
		state = State.READY
