extends Node2D

@export_file("*.tscn") var next_level := ""

@onready var hook = $Hook
@onready var color_fx: ColorRect = $ColorFX/ColorRect
@onready var bait_bar: ProgressBar = $HUD/BaitBar
@onready var message: Label = $HUD/Message
@onready var fisher_hold: Sprite2D = $Surface/FishermanHold
@onready var fisher_cast: Sprite2D = $Surface/FishermanCast

func _ready():
	color_fx.material.set_shader_parameter("saturation", 0.0)
	bait_bar.max_value = hook.max_bait_hp
	bait_bar.value = hook.max_bait_hp
	message.text = ""
	fisher_hold.visible = true
	fisher_cast.visible = false
	hook.entered_water.connect(_on_enter_water)
	hook.exited_water.connect(_on_exit_water)
	hook.bait_changed.connect(_on_bait_changed)
	hook.level_complete.connect(_on_level_complete)
	hook.casted.connect(_on_cast)

func _on_cast():
	_show_cast_pose(0.4)

func _show_cast_pose(duration: float):
	fisher_hold.visible = false
	fisher_cast.visible = true
	await get_tree().create_timer(duration).timeout
	fisher_cast.visible = false
	fisher_hold.visible = true

func _on_bait_changed(hp: float, max_hp: float):
	bait_bar.max_value = max_hp
	bait_bar.value = hp

func _on_enter_water():
	var t = create_tween()
	t.tween_property(color_fx.material, "shader_parameter/saturation", 1.2, 0.4)

func _on_exit_water():
	var t = create_tween()
	t.tween_property(color_fx.material, "shader_parameter/saturation", 0.0, 0.6)

func _on_level_complete():
	_show_cast_pose(0.6)
	message.text = "Caught it!"
	await get_tree().create_timer(2.0).timeout
	if next_level != "":
		get_tree().change_scene_to_file(next_level)
