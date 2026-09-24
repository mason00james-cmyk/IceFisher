extends Node2D

@onready var hook = $Hook
@onready var color_fx: ColorRect = $ColorFX/ColorRect

func _ready():
	color_fx.material.set_shader_parameter("saturation", 0.0)
	hook.entered_water.connect(_on_enter_water)
	hook.exited_water.connect(_on_exit_water)

func _on_enter_water():
	var t = create_tween()
	t.tween_property(color_fx.material, "shader_parameter/saturation", 1.2, 0.4)

func _on_exit_water():
	var t = create_tween()
	t.tween_property(color_fx.material, "shader_parameter/saturation", 0.0, 0.6)
