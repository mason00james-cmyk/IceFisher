extends Control

@export var title_text := "ICE FISHER"
@export_multiline var body_text := ""
@export var prompt_text := "PRESS SPACE TO START"
@export_file("*.tscn") var next_scene := ""
@export var show_dancers := false

const ICE_SHEET := preload("res://art/icefishing_transparent.png")
const DANCE_A := Rect2(176, 16, 16, 16)
const DANCE_B := Rect2(192, 16, 16, 16)

var leaving := false


func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# bleak gray backdrop
	var bg := ColorRect.new()
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.55, 0.58, 0.62)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_make_snow()
	_make_title_glow()

	var title := _make_label(title_text, 96, 170, 290)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.4))

	if show_dancers:
		_make_dancer(Vector2(200, 235), false, false)
		_make_dancer(Vector2(1080, 235), true, true)

	var body := _make_label(body_text, 24, 330, 480)
	body.offset_left = 190
	body.offset_right = -190
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var prompt := _make_label(prompt_text, 32, 560, 620)
	var blink := create_tween().set_loops()
	blink.tween_property(prompt, "modulate:a", 0.2, 0.6)
	blink.tween_property(prompt, "modulate:a", 1.0, 0.6)

	# fade in from black
	var fade := _make_fade(1.0)
	var t := create_tween()
	t.tween_property(fade, "modulate:a", 0.0, 0.8)
	t.tween_callback(fade.queue_free)


func _unhandled_input(event):
	if leaving or not event.is_action_pressed("cast"):
		return
	leaving = true
	var fade := _make_fade(0.0)
	var t := create_tween()
	t.tween_property(fade, "modulate:a", 1.0, 0.6)
	await t.finished
	if next_scene != "":
		get_tree().change_scene_to_file(next_scene)


# ---------- dancing fishermen ----------

func _make_dancer(pos: Vector2, face_left: bool, offbeat: bool):
	var s := Sprite2D.new()
	s.texture = ICE_SHEET
	s.region_enabled = true
	s.region_rect = DANCE_A
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2(8, 8)
	s.position = pos
	s.flip_h = face_left
	add_child(s)
	_dance(s, pos.y, offbeat)


func _dance(s: Sprite2D, base_y: float, offbeat: bool):
	var frame := offbeat
	while is_inside_tree():
		s.region_rect = DANCE_A if frame else DANCE_B
		s.position.y = base_y - (12.0 if frame else 0.0)
		frame = not frame
		await get_tree().create_timer(0.25).timeout


# ---------- helpers ----------

func _make_label(text: String, size: int, top: float, bottom: float) -> Label:
	var label := Label.new()
	add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	label.offset_top = top
	label.offset_bottom = bottom
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 4)
	label.add_theme_constant_override("shadow_offset_y", 4)
	return label


func _make_title_glow():
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.9, 0.35, 0.8))
	g.set_color(1, Color(1.0, 0.75, 0.2, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 256
	tex.height = 256
	var glow := Sprite2D.new()
	glow.texture = tex
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = mat
	glow.position = Vector2(640, 230)
	glow.scale = Vector2(3.5, 1.2)
	add_child(glow)
	var pulse := create_tween().set_loops()
	pulse.tween_property(glow, "scale", Vector2(4.2, 1.5), 0.9).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(glow, "scale", Vector2(3.5, 1.2), 0.9).set_trans(Tween.TRANS_SINE)


func _make_snow():
	var snow := CPUParticles2D.new()
	add_child(snow)
	snow.position = Vector2(640, -20)
	snow.amount = 140
	snow.lifetime = 14.0
	snow.preprocess = 14.0
	snow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	snow.emission_rect_extents = Vector2(700, 10)
	snow.direction = Vector2(0, 1)
	snow.spread = 15.0
	snow.gravity = Vector2(0, 20)
	snow.initial_velocity_min = 20.0
	snow.initial_velocity_max = 50.0
	snow.scale_amount_min = 2.0
	snow.scale_amount_max = 5.0
	snow.color = Color(1, 1, 1, 0.8)


func _make_fade(start_alpha: float) -> ColorRect:
	var fade := ColorRect.new()
	add_child(fade)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color.BLACK
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.modulate.a = start_alpha
	return fade
