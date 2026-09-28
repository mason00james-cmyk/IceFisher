extends Node2D

@export_file("*.tscn") var next_level := ""
@export var qte_length := 4
@export var struggle_rounds := 2
@export var struggle_key_time := 2.0
@export var max_slips := 5
@export_multiline var intro_text := ""
@export_multiline var outro_text := ""
@export var walk_in := false

const QTE_KEYS := {KEY_W: "W", KEY_A: "A", KEY_S: "S", KEY_D: "D"}
const END_SCENE := "res://scenes/end.tscn"

# pixel sheet pieces
const ICE_SHEET := preload("res://art/icefishing_transparent.png")
const HOLE_REGION := Rect2(104, 9, 16, 7)
const ICE_SPECKLE := Rect2i(76, 0, 16, 16)
const POSE_FISHING := Rect2(96, 16, 16, 16)   # rod out over the hole
const POSE_ROD_UP := Rect2(80, 16, 16, 16)    # rod raised (cast)
const DANCE_A := Rect2(176, 16, 16, 16)
const DANCE_B := Rect2(192, 16, 16, 16)
const WALK_LEFT_A := Rect2(160, 16, 16, 16)   # facing left, legs apart
const WALK_LEFT_B := Rect2(144, 16, 16, 16)   # facing left, legs together
const WALK_RIGHT_A := Rect2(112, 16, 16, 16)  # facing right, legs apart
const WALK_RIGHT_B := Rect2(128, 16, 16, 16)  # facing right, legs together

# surface layout (ice top is at y = -30)
const ICE_TOP := -30.0
const FISHER_POS := Vector2(-48, -70)
const ROD_TIP := Vector2(-10, -88)
const HOOK_REST := Vector2(0, -30)
const HOLE_POS := Vector2(0, -30)
const BANNER_POS := Vector2(-48, -190)
const OFFSCREEN_X := -740.0
const WALK_SPEED := 220.0
const FISH_CARRY := Vector2(-22, 18)

@onready var hook = $Hook
@onready var color_fx: ColorRect = $ColorFX/ColorRect
@onready var bait_bar: ProgressBar = $HUD/BaitBar
@onready var message: Label = $HUD/Message
@onready var fisher_hold: Sprite2D = $Surface/FishermanHold
@onready var fisher_cast: Sprite2D = $Surface/FishermanCast

var dialogue: Label
var dialogue_box: ColorRect
var bait_empty := false
var caught_layer: CanvasLayer
var dancing := false
var ice_cover: ColorRect
var cover_tween: Tween
var waiting_continue := false
var leaving := false
var continue_prompt: Label

var qte_label: RichTextLabel
var qte_seq: Array = []
var qte_idx := 0
var qte_active := false
var qte_mode := ""  # "reel" or "struggle"
var rounds_done := 0
var slips := 0
var key_time_left := 0.0


func _ready():
	color_fx.material.set_shader_parameter("saturation", 0.0)
	bait_bar.max_value = hook.max_bait_hp
	bait_bar.value = hook.max_bait_hp
	message.text = ""
	message.visible = false
	_make_dialogue()
	_make_qte_label()
	_make_caught_layer()
	_fix_ice()
	_make_hole()
	_setup_surface()
	_make_bobber()
	_make_snow()
	_make_ice_cover()
	fisher_hold.visible = true
	fisher_cast.visible = false
	hook.entered_water.connect(_on_enter_water)
	hook.exited_water.connect(_on_exit_water)
	hook.bait_changed.connect(_on_bait_changed)
	hook.level_complete.connect(_on_level_complete)
	hook.casted.connect(_on_cast)
	hook.qte_started.connect(_start_reel_qte)
	hook.struggle_started.connect(_start_struggle)
	say("")
	_intro()


func say(text: String):
	dialogue.text = text
	dialogue_box.visible = text != ""


# ---------- level intro ----------

func _intro():
	var fade := _make_fade(1.0)
	var fade_in := create_tween()
	fade_in.tween_property(fade, "modulate:a", 0.0, 0.8)
	fade_in.tween_callback(fade.queue_free)

	if walk_in:
		# no casting until he's at the hole
		hook.set_physics_process(false)
		var line := get_node_or_null("FishingLine") as CanvasItem
		if line:
			line.visible = false
		fisher_cast.visible = false
		fisher_hold.visible = true
		fisher_hold.global_position = Vector2(OFFSCREEN_X, FISHER_POS.y)

		await _walk_to(FISHER_POS.x, WALK_RIGHT_A, WALK_RIGHT_B)

		fisher_hold.region_rect = POSE_FISHING
		fisher_hold.global_position = FISHER_POS
		if line:
			line.visible = true
		hook.set_physics_process(true)
	else:
		await fade_in.finished

	if intro_text != "":
		say(intro_text)


func _walk_to(target_x: float, frame_a: Rect2, frame_b: Rect2):
	var dir: float = sign(target_x - fisher_hold.global_position.x)
	var frame := false
	var step := 0.0
	var fish: Node2D = null
	if leaving:
		fish = hook.hooked_fish
		hook.hooked_fish = null   # stop the hook from moving the fish
	while (target_x - fisher_hold.global_position.x) * dir > 0.0:
		var dt := get_process_delta_time()
		fisher_hold.global_position.x += WALK_SPEED * dt * dir
		step += dt
		if step >= 0.15:
			step = 0.0
			frame = not frame
		fisher_hold.region_rect = frame_a if frame else frame_b
		fisher_hold.global_position.y = FISHER_POS.y - (3.0 if frame else 0.0)
		if fish:
			fish.global_position = fisher_hold.global_position + FISH_CARRY
		await get_tree().process_frame
	fisher_hold.global_position = Vector2(target_x, FISHER_POS.y)


func _make_fade(start_alpha: float) -> ColorRect:
	var fade := ColorRect.new()
	$HUD.add_child(fade)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color = Color.BLACK
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.modulate.a = start_alpha
	return fade


# ---------- surface setup ----------

func _fix_ice():
	# one solid sheet of ice, no gap; the hole sprite is the hole
	var left := get_node_or_null("IceLeft") as ColorRect
	if left:
		left.position = Vector2(-640, ICE_TOP)
		left.size = Vector2(1280, -ICE_TOP)
		_add_ice_texture(left)
	var right := get_node_or_null("IceRight") as CanvasItem
	if right:
		right.visible = false


func _add_ice_texture(target: Control):
	# tile the speckle pattern from the ice fishing sheet across the ice
	var img := ICE_SHEET.get_image().get_region(ICE_SPECKLE)
	img.resize(64, 64, Image.INTERPOLATE_NEAREST)
	var tex := ImageTexture.create_from_image(img)
	var tiles := TextureRect.new()
	target.add_child(tiles)
	tiles.texture = tex
	tiles.stretch_mode = TextureRect.STRETCH_TILE
	tiles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tiles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tiles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tiles.modulate = Color(1, 1, 1, 0.45)


func _make_hole():
	var hole := Sprite2D.new()
	hole.texture = ICE_SHEET
	hole.region_enabled = true
	hole.region_rect = HOLE_REGION
	hole.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hole.scale = Vector2(5, 5)
	$Surface.add_child(hole)
	hole.global_position = HOLE_POS


func _setup_surface():
	for s in [fisher_hold, fisher_cast]:
		s.texture = ICE_SHEET
		s.region_enabled = true
		s.scale = Vector2(5, 5)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.global_position = FISHER_POS
	fisher_hold.region_rect = POSE_FISHING
	fisher_cast.region_rect = POSE_ROD_UP

	var tip := get_node_or_null("Surface/RodTip") as Node2D
	if tip:
		tip.global_position = ROD_TIP

	# hook starts resting in the hole
	hook.global_position = HOOK_REST
	hook.start_pos = HOOK_REST


func _make_snow():
	# snow only exists above the ice: a clipping box that ends at the ice top
	var sky_box := Control.new()
	add_child(sky_box)
	sky_box.position = Vector2(-640, -900)
	sky_box.size = Vector2(1280, 900 + ICE_TOP)
	sky_box.clip_contents = true
	sky_box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# two layers for depth: small/slow/faint behind, big/fast in front
	var flake := _make_flake_texture()
	_snow_layer(sky_box, flake, 80, 1.0, 2.0, 15.0, 30.0, 0.6)   # far
	_snow_layer(sky_box, flake, 45, 2.5, 4.0, 40.0, 70.0, 1.0)   # near


func _snow_layer(parent: Control, flake: Texture2D, amount: int, size_min: float,
		size_max: float, speed_min: float, speed_max: float, alpha: float):
	var snow := CPUParticles2D.new()
	parent.add_child(snow)
	snow.texture = flake
	snow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	snow.position = Vector2(640, 440)   # top-center of the sky box
	snow.amount = amount
	snow.lifetime = 9.0
	snow.preprocess = 9.0
	snow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	snow.emission_rect_extents = Vector2(680, 10)
	snow.direction = Vector2(0, 1)
	snow.spread = 15.0
	snow.gravity = Vector2(0, 15)
	snow.initial_velocity_min = speed_min
	snow.initial_velocity_max = speed_max
	snow.scale_amount_min = size_min
	snow.scale_amount_max = size_max
	snow.color = Color(1, 1, 1, alpha)


func _make_flake_texture() -> ImageTexture:
	# 7x7 pixel flake: white center, dark outline
	var rows := [
		"..ooo..",
		".o###o.",
		"o#####o",
		"o#####o",
		"o#####o",
		".o###o.",
		"..ooo..",
	]
	var outline := Color(0.3, 0.33, 0.4)
	var img := Image.create(7, 7, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in rows.size():
		for x in rows[y].length():
			var c: String = rows[y][x]
			if c == "#":
				img.set_pixel(x, y, Color.WHITE)
			elif c == "o":
				img.set_pixel(x, y, outline)
	return ImageTexture.create_from_image(img)


func _make_bobber():
	var icon := hook.get_node_or_null("Sprite2D") as CanvasItem
	if icon:
		icon.visible = false
	var bottom := Polygon2D.new()
	bottom.polygon = _half_circle(7.0, false)
	bottom.color = Color.WHITE
	var top := Polygon2D.new()
	top.polygon = _half_circle(7.0, true)
	top.color = Color(0.9, 0.15, 0.15)
	hook.add_child(bottom)
	hook.add_child(top)


func _half_circle(r: float, upper: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI * i / 12.0
		var p := Vector2(cos(a) * r, sin(a) * r)
		if upper:
			p.y = -p.y
		pts.append(p)
	return pts


func _make_ice_cover():
	# a snowy sheet over the water that fades away when you cast
	ice_cover = ColorRect.new()
	var ice := get_node_or_null("IceLeft") as ColorRect
	ice_cover.color = ice.color if ice else Color(0.92, 0.94, 0.96)
	ice_cover.position = Vector2(-640, 0)
	ice_cover.size = Vector2(1280, 900)
	ice_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ice_cover.z_index = 1
	add_child(ice_cover)
	_add_ice_texture(ice_cover)
	# keep the hook and line drawn above the cover
	hook.z_index = 2
	var line := get_node_or_null("FishingLine") as CanvasItem
	if line:
		line.z_index = 2


func _fade_cover(to_alpha: float, time: float):
	if cover_tween:
		cover_tween.kill()
	cover_tween = create_tween()
	cover_tween.tween_property(ice_cover, "modulate:a", to_alpha, time)


func _make_caught_layer():
	# sits above the gray filter so things put here keep their color topside
	$HUD.layer = 3
	caught_layer = CanvasLayer.new()
	caught_layer.layer = 2
	caught_layer.follow_viewport_enabled = true
	add_child(caught_layer)


# ---------- UI setup ----------

func _make_dialogue():
	# dark box behind the text so it reads on white snow
	dialogue_box = ColorRect.new()
	$HUD.add_child(dialogue_box)
	dialogue_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	dialogue_box.offset_left = 60
	dialogue_box.offset_right = -60
	dialogue_box.offset_top = -140
	dialogue_box.offset_bottom = -20
	dialogue_box.color = Color(0.05, 0.08, 0.15, 0.75)
	dialogue_box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	dialogue = Label.new()
	$HUD.add_child(dialogue)
	dialogue.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	dialogue.offset_left = 90
	dialogue.offset_right = -90
	dialogue.offset_top = -130
	dialogue.offset_bottom = -30
	dialogue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_label(dialogue, 24)


func _make_qte_label():
	qte_label = RichTextLabel.new()
	$HUD.add_child(qte_label)
	qte_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	qte_label.offset_top = 170
	qte_label.offset_bottom = -300
	qte_label.bbcode_enabled = true
	qte_label.scroll_active = false
	qte_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	qte_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	qte_label.add_theme_font_size_override("normal_font_size", 48)
	qte_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	qte_label.add_theme_constant_override("shadow_offset_x", 4)
	qte_label.add_theme_constant_override("shadow_offset_y", 4)
	qte_label.visible = false


func _style_label(label: Label, size: int):
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 3)
	label.add_theme_constant_override("shadow_offset_y", 3)


func _make_glow(radius_scale: float) -> Sprite2D:
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.9, 0.35, 0.9))
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
	glow.scale = Vector2(radius_scale * 1.3, radius_scale)
	var pulse := create_tween().set_loops()
	pulse.tween_property(glow, "scale", Vector2(radius_scale * 1.6, radius_scale * 1.25), 0.8).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(glow, "scale", Vector2(radius_scale * 1.3, radius_scale), 0.8).set_trans(Tween.TRANS_SINE)
	return glow


func _show_caught_banner():
	# "CAUGHT IT!" above the fisherman, glowing like the fish, in full color
	var banner := Node2D.new()
	caught_layer.add_child(banner)
	banner.global_position = BANNER_POS

	banner.add_child(_make_glow(1.2))

	var label := Label.new()
	label.text = "CAUGHT IT!"
	label.size = Vector2(600, 80)
	label.position = Vector2(-300, -40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_label(label, 64)
	label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.4))
	banner.add_child(label)

	# pop in, then bob gently
	banner.scale = Vector2(0.2, 0.2)
	var pop := create_tween()
	pop.tween_property(banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var bob := create_tween().set_loops()
	bob.tween_property(banner, "position:y", BANNER_POS.y - 8, 0.6).set_trans(Tween.TRANS_SINE)
	bob.tween_property(banner, "position:y", BANNER_POS.y, 0.6).set_trans(Tween.TRANS_SINE)


func _show_continue_prompt():
	continue_prompt = Label.new()
	$HUD.add_child(continue_prompt)
	continue_prompt.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	continue_prompt.offset_top = 40
	continue_prompt.offset_bottom = 90
	continue_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	continue_prompt.text = "PRESS SPACE TO CONTINUE"
	_style_label(continue_prompt, 32)
	var blink := create_tween().set_loops()
	blink.tween_property(continue_prompt, "modulate:a", 0.2, 0.6)
	blink.tween_property(continue_prompt, "modulate:a", 1.0, 0.6)


# ---------- skill checks ----------

func _start_reel_qte():
	qte_mode = "reel"
	_new_sequence()


func _start_struggle():
	qte_mode = "struggle"
	rounds_done = 0
	slips = 0
	_new_sequence()
	say("It's fighting! Hit the keys to keep it on the line!")


func _new_sequence():
	qte_seq.clear()
	for i in qte_length:
		qte_seq.append(QTE_KEYS.keys().pick_random())
	qte_idx = 0
	key_time_left = struggle_key_time
	qte_active = true
	qte_label.visible = true
	_draw_qte()


func _end_qte():
	qte_active = false
	qte_label.visible = false
	qte_mode = ""


func _draw_qte():
	var parts: Array[String] = []
	for i in qte_seq.size():
		var k: String = QTE_KEYS[qte_seq[i]]
		if i < qte_idx:
			parts.append("[color=#66ff66]" + k + "[/color]")
		elif i == qte_idx:
			parts.append("[color=yellow][u]" + k + "[/u][/color]")
		else:
			parts.append("[color=white]" + k + "[/color]")
	var header := "REEL IT IN!"
	var footer := ""
	if qte_mode == "struggle":
		header = "HOLD ON!  %d / %d" % [rounds_done + 1, struggle_rounds]
		footer = "\n[font_size=24]SLIPS: %d / %d[/font_size]" % [slips, max_slips]
	qte_label.text = ("[center][font_size=32]" + header + "[/font_size]\n"
		+ "    ".join(parts) + footer + "[/center]")


func _process(delta):
	if qte_active and qte_mode == "struggle":
		key_time_left -= delta
		if key_time_left <= 0.0:
			_slip()


func _unhandled_input(event):
	# after a catch, wait for SPACE to move on
	if waiting_continue:
		if event.is_action_pressed("cast"):
			waiting_continue = false
			get_viewport().set_input_as_handled()
			_go_next()
		return

	if not qte_active:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if not QTE_KEYS.has(event.physical_keycode):
		return
	get_viewport().set_input_as_handled()
	if event.physical_keycode == qte_seq[qte_idx]:
		qte_idx += 1
		key_time_left = struggle_key_time
		if qte_idx >= qte_seq.size():
			_sequence_done()
		else:
			_draw_qte()
	else:
		_slip()


func _slip():
	qte_idx = 0
	key_time_left = struggle_key_time
	qte_label.modulate = Color(1, 0.3, 0.3)
	create_tween().tween_property(qte_label, "modulate", Color.WHITE, 0.3)
	if qte_mode == "struggle":
		slips += 1
		if slips > max_slips:
			_end_qte()
			hook.finish_struggle(false)
			say("It got away! Reel in, rebait, and try again.")
			return
	_draw_qte()


func _sequence_done():
	if qte_mode == "reel":
		_end_qte()
		hook.finish_qte()
		say("Reeling in...")
	elif qte_mode == "struggle":
		rounds_done += 1
		if rounds_done >= struggle_rounds:
			_end_qte()
			hook.finish_struggle(true)
			say("Got it! Bring it up!")
		else:
			_new_sequence()


# ---------- fisherman animation ----------

func _show_cast_pose(duration: float):
	if dancing:
		return
	fisher_hold.visible = false
	fisher_cast.visible = true
	await get_tree().create_timer(duration).timeout
	fisher_cast.visible = false
	fisher_hold.visible = true


func _dance():
	# dances until he walks off
	dancing = true
	var base_y := fisher_hold.position.y
	fisher_cast.visible = false
	fisher_hold.visible = true
	var frame := false
	while dancing and is_inside_tree():
		fisher_hold.region_rect = DANCE_A if frame else DANCE_B
		fisher_hold.position.y = base_y - (8.0 if frame else 0.0)
		frame = not frame
		await get_tree().create_timer(0.2).timeout


# ---------- events ----------

func _on_cast():
	say("")
	_show_cast_pose(0.4)
	_fade_cover(0.0, 0.6)


func _on_bait_changed(hp: float, max_hp: float):
	bait_bar.max_value = max_hp
	bait_bar.value = hp
	if hp <= 0.0 and not bait_empty:
		bait_empty = true
		say("Bait's gone! Hit the keys in order to reel it in.")
	elif bait_empty and hp >= max_hp:
		bait_empty = false
		say("Fresh bait. Press SPACE to cast again.")


func _on_enter_water():
	var t = create_tween()
	t.tween_property(color_fx.material, "shader_parameter/saturation", 1.2, 0.4)


func _on_exit_water():
	# lift a caught fish above the gray filter so it stays in color
	if hook.hooked_fish:
		hook.hooked_fish.reparent(caught_layer)
	var t = create_tween()
	t.tween_property(color_fx.material, "shader_parameter/saturation", 0.0, 0.6)
	_fade_cover(1.0, 0.6)


func _on_level_complete():
	say(outro_text)
	_show_caught_banner()
	_dance()
	# short pause so the moment lands, then wait for the player
	await get_tree().create_timer(1.5).timeout
	_show_continue_prompt()
	waiting_continue = true


func _go_next():
	if leaving:
		return
	leaving = true
	dancing = false
	if continue_prompt:
		continue_prompt.visible = false
	say("")
	var line := get_node_or_null("FishingLine") as CanvasItem
	if line:
		line.visible = false
	fisher_cast.visible = false
	fisher_hold.visible = true
	fisher_hold.global_position = FISHER_POS
	await _walk_to(OFFSCREEN_X, WALK_LEFT_A, WALK_LEFT_B)
	var fade := _make_fade(0.0)
	var t := create_tween()
	t.tween_property(fade, "modulate:a", 1.0, 0.6)
	await t.finished

	# level order lives here so it can't get lost in the Inspector
	var order := {
		"res://scenes/level_1.tscn": "res://scenes/level_2.tscn",
		"res://scenes/level_2.tscn": END_SCENE,
	}
	var target: String = next_level
	if target == "":
		target = order.get(scene_file_path, END_SCENE)
	get_tree().change_scene_to_file(target)
