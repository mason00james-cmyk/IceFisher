extends Node

const MIN_TIME := 5.0          # every line stays up at least this long
const SECONDS_PER_CHAR := 0.08 # longer lines stay up longer
const SINK_SPEED := 70.0       # how fast the hook drifts down in the tutorial
const REELING := 2             # matches State.REELING in hook.gd

@onready var level = get_parent()
@onready var hook = get_parent().get_node("Hook")

var shown := {}      # lines the player has actually seen
var pending := {}    # lines waiting in the queue
var bait_lost := false
var queue: Array = []   # each entry is [key, text]
var showing_until := 0.0


func _ready():
	await get_tree().process_frame
	hook.sink_speed = SINK_SPEED
	tell("Nothing lives up here anymore. Everything's down there. "
		+ "We only need one fish... the one that glows. Press SPACE to cast.", true)
	hook.casted.connect(_on_cast)
	hook.bait_changed.connect(_on_bait)
	hook.level_complete.connect(_on_done)
	hook.qte_started.connect(_on_qte)
	hook.struggle_started.connect(_on_struggle)
	hook.exited_water.connect(_on_surface)


func _process(_delta):
	_advance_queue()
	if not hook.underwater or bait_lost:
		return
	var y: float = hook.global_position.y
	var reeling: bool = hook.state == REELING

	_once("steer", y > 60.0,
		"Let it sink. A and D steer around the rocks.")
	_once("reel", y > 180.0,
		"Hold W any time to pull your line back up. "
		+ "Handy for backing out of trouble. Try it.")
	if shown.has("reel") and reeling:
		_once("reel_ok", true,
			"Good. Let go of W and it sinks again.")
	_once("fish", y > 900.0,
		"More of them. They all want your bait. Keep your distance.")
	_once("rocks", y > 1200.0,
		"Rocks block fish, but not your line. "
		+ "Put a rock between you and them.")
	_once("puffer", y > 1700.0,
		"Careful... that puffer down there bites HARD.")


# ---------- text pacing ----------

func tell(text: String, urgent := false, key := ""):
	if urgent:
		_clear_queue()
		_show(key, text)
	else:
		queue.append([key, text])
		if key != "":
			pending[key] = true


func _show(key: String, text: String):
	level.say(text)
	if key != "":
		shown[key] = true
		pending.erase(key)
	var read_time: float = max(MIN_TIME, text.length() * SECONDS_PER_CHAR)
	showing_until = Time.get_ticks_msec() / 1000.0 + read_time


func _advance_queue():
	if queue.is_empty():
		return
	if Time.get_ticks_msec() / 1000.0 >= showing_until:
		var entry: Array = queue.pop_front()
		_show(entry[0], entry[1])


func _clear_queue():
	# lines that never got shown can play again later
	queue.clear()
	pending.clear()


func _once(key: String, cond: bool, text: String, urgent := false):
	if cond and not shown.has(key) and not pending.has(key):
		tell(text, urgent, key)


# ---------- events ----------

func _on_surface():
	_clear_queue()
	# bait / catch messages handle themselves
	if hook.hooked_fish or hook.bait_hp <= 0.0:
		return
	tell("Back up top. SPACE when you're ready to drop it again.", true)


func _on_bait(hp: float, max_hp: float):
	if hp > 0.0 and hp < max_hp and not bait_lost:
		_once("bite", true,
			"That's a bite! See your bait bar drop, top left? "
			+ "Every bite costs you.", true)
	elif bait_lost and hp >= max_hp and not shown.has("recast"):
		for n in get_tree().get_nodes_in_group("clear_on_recast"):
			n.queue_free()
		tell("Fresh bait. I scared the rest off. "
			+ "SPACE to cast again, and look for the glow.", true, "recast")


func _on_qte():
	if not bait_lost:
		bait_lost = true
		tell("Ha! Happens to everyone. Bait's gone, so reel it in: "
			+ "hit those keys in order. Miss one and you start over.", true)


func _on_cast():
	if shown.has("recast"):
		hook.sink_speed = 300.0
		tell("Straight down. That gold one's ours.", true)


func _on_struggle():
	tell("It's fighting! Keys in order before the timer runs out. "
		+ "Slip up more than five times and it's gone.", true)


func _on_done():
	tell("That's the one. Now pack up. There's an old hole way out on the lake "
		+ "nobody fishes anymore. That's where the big ones are.", true)
