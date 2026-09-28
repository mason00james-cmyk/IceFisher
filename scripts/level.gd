extends Node2D

@export_file("*.tscn") var next_level := ""
@export var qte_length := 4
@export var struggle_rounds := 2
@export var struggle_key_time := 2.0
@export var max_slips := 5

const QTE_KEYS := {KEY_W: "W", KEY_A: "A", KEY_S: "S", KEY_D: "D"}

@onready var hook = $Hook
@onready var color_fx: ColorRect = $ColorFX/ColorRect
@onready var bait_bar: ProgressBar = $HUD/BaitBar
@onready var message: Label = $HUD/Message
@onready var fisher_hold: Sprite2D = $Surface/FishermanHold
@onready var fisher_cast: Sprite2D = $Surface/FishermanCast

var dialogue: Label
var bait_empty := false
var caught_layer: CanvasLayer

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
	_outline(message, 48)
	_make_dialogue()
	_make_qte_label()
	_make_caught_layer()
	fisher_hold.visible = true
	fisher_cast.visible = false
	hook.entered_water.connect(_on_enter_water)
	hook.exited_water.connect(_on_exit_water)
	hook.bait_changed.connect(_on_bait_changed)
	hook.level_complete.connect(_on_level_complete)
	hook.casted.connect(_on_cast)
	hook.qte_started.connect(_start_reel_qte)
	hook.struggle_started.connect(_start_struggle)


func say(text: String):
	dialogue.text = text


# ---------- UI setup ----------

func _make_caught_layer():
	# sits above the gray filter so the caught fish keeps its color topside
	$HUD.layer = 3
	caught_layer = CanvasLayer.new()
	caught_layer.layer = 2
	caught_layer.follow_viewport_enabled = true
	add_child(caught_layer)


func _make_dialogue():
	dialogue = Label.new()
	$HUD.add_child(dialogue)
	dialogue.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	dialogue.offset_left = 80
	dialogue.offset_right = -80
	dialogue.offset_top = -130
	dialogue.offset_bottom = -30
	dialogue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_outline(dialogue, 26)


func _make_qte_label():
	qte_label = RichTextLabel.new()
	$HUD.add_child(qte_label)
	qte_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	qte_label.offset_top = 170
	qte_label.offset_bottom = -300
	qte_label.bbcode_enabled = true
	qte_label.scroll_active = false
	qte_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	qte_label.add_theme_font_size_override("normal_font_size", 56)
	qte_label.add_theme_color_override("font_outline_color", Color.BLACK)
	qte_label.add_theme_constant_override("outline_size", 10)
	qte_label.visible = false


func _outline(label: Label, size: int):
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)


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
		footer = "\n[font_size=26]Slips: %d / %d[/font_size]" % [slips, max_slips]
	qte_label.text = ("[center][font_size=30]" + header + "[/font_size]\n"
		+ "    ".join(parts) + footer + "[/center]")


func _process(delta):
	if qte_active and qte_mode == "struggle":
		key_time_left -= delta
		if key_time_left <= 0.0:
			_slip()


func _unhandled_input(event):
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
		else:
			_new_sequence()


# ---------- events ----------

func _on_cast():
	say("")
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


func _on_level_complete():
	_show_cast_pose(0.6)
	message.text = "Caught it!"
	await get_tree().create_timer(2.5).timeout
	if next_level != "":
		get_tree().change_scene_to_file(next_level)
