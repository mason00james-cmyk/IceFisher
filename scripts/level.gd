extends Node2D

@onready var hook = $Hook
@onready var color_fx: ColorRect = $ColorFX/ColorRect
@onready var bait_bar: ProgressBar = $HUD/BaitBar

func _ready():
	color_fx.material.set_shader_parameter("saturation", 0.0)
	bait_bar.max_value = hook.max_bait_hp
	bait_bar.value = hook.max_bait_hp
	hook.entered_water.connect(_on_enter_water)
	hook.exited_water.connect(_on_exit_water)
	hook.bait_changed.connect(_on_bait_changed)

func _on_bait_changed(hp: float, max_hp: float):
	bait_bar.max_value = max_hp
	bait_bar.value = hp

func _on_enter_water():
	var t = create_tween()
	t.tween_property(color_fx.material, "shader_parameter/saturation", 1.2, 0.4)

func _on_exit_water():
	var t = create_tween()
	t.tween_property(color_fx.material, "shader_parameter/saturation", 0.0, 0.6)
