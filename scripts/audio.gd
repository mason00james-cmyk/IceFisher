extends Node
# Tells the global Music manager what to play for this scene.

@export_enum("level", "menu") var mode := "level"

const TITLE_TRACK := "res://audio/Track1.mp3"
const TUTORIAL_TRACK := "res://audio/Track2.mp3"
const LEVEL2_TRACK := "res://audio/Track3.mp3"

# what plays on the ice, per level
const SURFACE_BY_LEVEL := {
	"res://scenes/level_1.tscn": TITLE_TRACK,
	"res://scenes/level_2.tscn": LEVEL2_TRACK,
}
# what plays underwater, per level
const UNDERWATER_BY_LEVEL := {
	"res://scenes/level_1.tscn": TUTORIAL_TRACK,
	"res://scenes/level_2.tscn": LEVEL2_TRACK,
}
# what starts playing as he walks off after the catch
const LEAVING_BY_LEVEL := {
	"res://scenes/level_1.tscn": LEVEL2_TRACK,
	"res://scenes/level_2.tscn": TITLE_TRACK,
}

var scene_path := ""
var surface_track := TITLE_TRACK
var underwater_track := TUTORIAL_TRACK
var fish_landed := false


func _ready():
	if mode == "menu":
		Music.play(TITLE_TRACK, 1.5)
		return

	scene_path = get_parent().scene_file_path
	surface_track = SURFACE_BY_LEVEL.get(scene_path, TITLE_TRACK)
	underwater_track = UNDERWATER_BY_LEVEL.get(scene_path, TUTORIAL_TRACK)
	Music.play(surface_track, 1.5)

	var hook = get_parent().get_node_or_null("Hook")
	if hook:
		hook.entered_water.connect(_on_enter_water)
		hook.exited_water.connect(_on_exit_water)


func _on_enter_water():
	if fish_landed:
		return
	Music.play(underwater_track, 1.0)


func _on_exit_water():
	if fish_landed:
		return  # keep the victory music going
	Music.play(surface_track, 1.2)


func on_fish_landed():
	# struggle won: victory music while the fish comes up
	fish_landed = true
	Music.play(TITLE_TRACK, 1.0)


func on_level_leaving():
	var next_track: String = LEAVING_BY_LEVEL.get(scene_path, "")
	if next_track != "":
		Music.play(next_track, 2.5)
