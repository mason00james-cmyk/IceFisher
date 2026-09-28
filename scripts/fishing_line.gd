extends Line2D

@export var rod_tip: Node2D
@export var hook: Node2D

func _process(_delta):
	clear_points()
	add_point(to_local(rod_tip.global_position))
	add_point(to_local(hook.global_position))
