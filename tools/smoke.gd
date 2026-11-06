extends SceneTree

# Drives one complete evening with no window and no renderer, then checks that
# every promise the loop makes actually happened. Run with:
#   godot --headless --path . -s tools/smoke.gd

const Art = preload("res://scripts/Art.gd")
const SAVE := "user://ninecoats_smoke.json"

var checks: int = 0
var failures: Array = []


func _check(label: String, ok: bool) -> void:
	checks += 1
	if ok:
		print("  ok    ", label)
	else:
		failures.append(label)
		print("  FAIL  ", label)


func _run(main, seconds: float) -> void:
	var steps: int = int(seconds / 0.05)
	for i in range(steps):
		main.tick(0.05)
		if main.night_over:
			return


func _initialize() -> void:
	_start()


func _start() -> void:
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	var scene: PackedScene = load("res://scenes/Main.tscn")
	var main = scene.instantiate()
	main.save_path = SAVE
	root.add_child(main)
	# The tree is not running yet when a SceneTree script initialises, so the
	# node's _ready() has not fired. One frame gives it that.
	await process_frame
	main.set_process(false)

	print("")
	print("nine coats -- smoke test")
	print("")

	# --- the art exists and is the right shape
	_check("room is 320x180", Art.room_image().get_size() == Vector2i(320, 180))
	_check("font measures a line", Art.text_width("ABC") == 17)
	_check("font has A", Art.glyph_cell("A").x >= 0)
	_check("character sprite is 12x16", Art.char_tex("player", 0, 0).get_image().get_size() == Vector2i(12, 16))

	# --- the inn is standing
	_check("world built", main.world != null and main.player != null)
	_check("hud built", main.clock_text != null and main.prompt_text != null)
	_check("nine tables", main.TABLES.size() == 9)

	# --- the evening starts empty
	_check("night one, 17:00", main.night == 1 and main.clock_min == 17 * 60)
	_check("no coats on the rack", main.coat_count() == 0)
	_check("nobody arrived yet", main.guest_state_name(0) == "away")
	_check("three guests scheduled", main.guests.size() == 3)

	# --- Bramble comes in out of the rain
	_run(main, 22.0)
	_check("badger arrived", main.guest_state_name(0) != "away")
	_run(main, 14.0)
	_check("badger sat down", main.guest_state_name(0) == "sitting")
	_check("one coat on the rack", main.coat_count() == 1)
	_check("the clock is running", main.clock_min > 17 * 60)

	# --- take a bowl from the counter
	main.player_pos = main.counter_pos + Vector2(0.0, -8.0)
	main.interact()
	_check("bowl in hand", main.hands == 1)
	_check("one bowl left the pot", main.stew_left == 5)

	# --- carry it to the table
	var seat: Vector2 = main.guest_position(0)
	main.player_pos = seat + Vector2(0.0, 10.0)
	main.interact()
	_check("stew served", main.hands == 0)
	_check("coins paid", main.coins == 7)
	_check("guest eating", main.guest_state_name(0) == "eating")

	_run(main, 15.0)
	_check("guest finished eating", main.guest_state_name(0) == "talking")

	# --- listen
	main.interact()
	_check("dialogue opened", main._dialogue_open == true)
	_check("dialogue has a line", main.dialogue_line.text.length() > 10)
	main.interact()
	main.interact()
	main.interact()
	_check("dialogue closed", main._dialogue_open == false)
	_check("guest heading out", main.guest_state_name(0) == "outbound" or main.guest_state_name(0) == "gone")

	_run(main, 20.0)
	_check("guest gone", main.guest_state_name(0) == "gone")
	_check("badger's coat taken down", main.guests[0]["coat"] == null)

	# --- feed the fire
	main.fire = 0.2
	main.player_pos = main.hearth_pos
	main.interact()
	_check("fire fed", main.fire > 0.5)

	# --- close the evening
	main.clock_min = 22 * 60 + 58
	_run(main, 4.0)
	_check("night ended", main.night_over == true)
	_check("ledger written", main.ledger_lines.size() == 1)
	_check("ledger says something", str(main.ledger_lines[0]).length() > 30)
	_check("saved to disk", FileAccess.file_exists(SAVE))

	# --- and the next night begins clean
	main.interact()
	_check("next night started", main.night == 2 and main.clock_min == 17 * 60)
	_check("guests cleared", main.coat_count() == 0)
	_check("hands empty", main.hands == 0)
	_check("ledger hidden", main.ledger_panel.visible == false)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	print("")
	if failures.is_empty():
		print("PASS  ", checks, " checks")
		quit(0)
	else:
		print("FAILED ", failures.size(), " of ", checks, " checks")
		for f in failures:
			print("   - ", f)
		quit(1)
