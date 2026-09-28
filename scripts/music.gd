extends Node
# Lives across every scene so music never cuts out between levels.

const SILENT := -40.0
@export var volume_db := -25.0

var players := {}   # track path -> AudioStreamPlayer
var tweens := {}    # track path -> Tween
var current := ""


func play(path: String, fade := 1.5):
	if path == current:
		return

	# fade out whatever's playing, then pause it so it can resume later
	if current != "" and players.has(current):
		var old_path := current
		var old: AudioStreamPlayer = players[old_path]
		_kill_tween(old_path)
		var out := create_tween()
		out.tween_property(old, "volume_db", SILENT, fade)
		out.tween_callback(func():
			if current != old_path:
				old.stream_paused = true)
		tweens[old_path] = out

	current = path
	var p := _get_player(path)
	if p == null:
		return
	p.stream_paused = false
	if not p.playing:
		p.play()
	_kill_tween(path)
	var fade_in := create_tween()
	fade_in.tween_property(p, "volume_db", volume_db, fade)
	tweens[path] = fade_in


func _get_player(path: String) -> AudioStreamPlayer:
	if players.has(path):
		return players[path]
	if not ResourceLoader.exists(path):
		push_warning("Music file not found: " + path)
		return null
	var stream = load(path)
	if "loop" in stream:
		stream.loop = true
	var p := AudioStreamPlayer.new()
	add_child(p)
	p.stream = stream
	p.volume_db = SILENT
	players[path] = p
	return p


func _kill_tween(path: String):
	if tweens.has(path) and tweens[path]:
		tweens[path].kill()
