extends SceneTree

# Headless check of one full evening. No display, no audio device, no speech
# server -- everything here drives the real scene by hand.

const Art = preload("res://scripts/Art.gd")
const Audio = preload("res://scripts/Audio.gd")
const Recipes = preload("res://scripts/Recipes.gd")
const SAVE := "user://ninecoats_smoke.json"

var _pass: int = 0
var _fail: int = 0
var _failed: Array = []


func _initialize() -> void:
	_start()


func _check(label: String, ok: bool) -> void:
	if ok:
		_pass += 1
		print("  ok    %s" % label)
	else:
		_fail += 1
		_failed.append(label)
		print("  FAIL  %s" % label)


func _flood(main) -> Dictionary:
	# walk the floor on a 2px grid, the way the player is allowed to
	var start := Vector2i(int(main.player_pos.x), int(main.player_pos.y))
	var seen: Dictionary = {}
	var queue: Array = []
	if main._free(Vector2(float(start.x), float(start.y))):
		seen[start] = true
		queue.append(start)
	while queue.size() > 0:
		var c: Vector2i = queue.pop_back()
		for d in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
			var n: Vector2i = c + d
			if n.x < 8 or n.x > 312 or n.y < 60 or n.y > 150:
				continue
			if seen.has(n):
				continue
			if not main._free(Vector2(float(n.x), float(n.y))):
				continue
			seen[n] = true
			queue.append(n)
	return seen


func _reachable(reach: Dictionary, target: Vector2) -> bool:
	var t := Vector2i(int(target.x), int(target.y))
	for dx in range(-8, 9):
		for dy in range(-8, 9):
			if reach.has(t + Vector2i(dx, dy)):
				return true
	return false


func _initialize_done() -> void:
	pass


func _start() -> void:
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("")
	print("nine coats -- smoke test")
	print("")

	var main = load("res://scenes/Main.tscn").instantiate()
	main.save_path = SAVE
	root.add_child(main)
	await process_frame
	main.set_process(false)

	# --- the pieces exist
	_check("room is 320x180", Art.make_room().get_size() == Vector2(320.0, 180.0))
	_check("kitchen is 320x180", Art.make_kitchen().get_size() == Vector2(320.0, 180.0))
	_check("village is 320x180", Art.make_village().get_size() == Vector2(320.0, 180.0))
	_check("character sprite is 12x16", Art.char_tex("player", 0, 0).get_image().get_size() == Vector2i(12, 16))
	_check("a chair is 12x11", Art.make_chair().get_image().get_size() == Vector2i(12, 11))
	_check("a seated sprite is 12x16", Art.sit_tex("badger", 0, 2).get_image().get_size() == Vector2i(12, 16))
	_check("the feet move between walk frames", Art.char_tex("player", 0, 0).get_image().get_data() != Art.char_tex("player", 0, 2).get_image().get_data())
	_check("music is synthesised", Audio.music().data.size() > 200000)
	_check("music loops", Audio.music().loop_mode == AudioStreamWAV.LOOP_FORWARD)
	_check("footsteps are synthesised", Audio.step().data.size() > 2000)
	_check("voices are synthesised", Audio.voice().data.size() > 2000)
	_check("coin ping is synthesised", Audio.ping().data.size() > 2000)
	_check("speech was probed", main._tts_seen)

	# --- the pantry: five things, ten pairs, ten dishes
	_check("five things in the pantry", Recipes.INGREDIENTS.size() == 5)
	_check("ten dishes on the menu", Recipes.count() == 10)
	var all_pairs: bool = true
	var names: Dictionary = {}
	for a in range(5):
		for b in range(a + 1, 5):
			var d: int = Recipes.dish_for(a, b)
			if d < 0:
				all_pairs = false
			else:
				names[str(Recipes.dish_name(d))] = true
				if Recipes.dish_for(b, a) != d:
					all_pairs = false
	_check("every pair of ingredients makes a dish", all_pairs)
	_check("all ten dishes are different", names.size() == 10)

	# --- the taproom can be walked
	_check("starts in the taproom", main.room == 0)
	main.player_pos = Vector2(64.0, 100.0)
	var reach: Dictionary = _flood(main)
	_check("walking from the door reaches the hearth", _reachable(reach, main.hearth_pos))
	_check("walking reaches the kitchen passage", _reachable(reach, main.PASSAGE_TAP))
	for t in [0, 3, 5]:
		var seat: Vector2 = main.TABLES[t] + main.SEAT_OFFSET
		_check("seat %d is clear of furniture" % t, main._free(seat))
		_check("can stand at table %d" % t, _reachable(reach, seat + Vector2(0.0, 10.0)))

	# --- and so can the kitchen
	main._set_room(1)
	main.player_pos = Vector2(150.0, 100.0)
	_check("the kitchen floor is clear", main._free(main.player_pos))
	var kreach: Dictionary = _flood(main)
	_check("walking reaches the jars", _reachable(kreach, main.JAR_SPOTS[0]))
	_check("walking reaches the last jar", _reachable(kreach, main.JAR_SPOTS[4]))
	_check("walking reaches the pot", _reachable(kreach, main.POT_SPOT))
	_check("walking reaches the way back", _reachable(kreach, main.PASSAGE_KIT))

	# --- take two things and cook them
	main.player_pos = main.JAR_SPOTS[0]
	main.interact()
	_check("took a mushroom", main.hand_kind == 1 and main.hand_id == 0)
	main.player_pos = main.POT_SPOT
	main.interact()
	_check("the mushroom is in the pot", main.pot_ingredients.size() == 1)
	_check("the hand is empty again", main.hand_kind == 0)
	main.player_pos = main.JAR_SPOTS[1]
	main.interact()
	main.player_pos = main.POT_SPOT
	main.interact()
	_check("two things are in the pot", main.pot_ingredients.size() == 2)
	main.interact()
	_check("the pot is cooking", main.pot_cook > 0.0)
	_check("the pot shows its bubbles", main.pot_bubbles.visible)
	main.tick(3.5)
	_check("something came out of the pot", main.pot_dish == Recipes.dish_for(0, 1))
	_check("a pot was counted", main.dishes_cooked == 1)
	main.interact()
	_check("the dish is in hand", main.hand_kind == 2 and main.hand_id == Recipes.dish_for(0, 1))

	# --- the book, and the pot showing its work
	var pot_keep_kind: int = main.hand_kind
	var pot_keep_id: int = main.hand_id
	_check("the book covers the whole menu", Art.make_book({}, Recipes.DISHES).get_size() == Vector2(320.0, 180.0))
	main._toggle_book()
	_check("the book opens", main._book_open and main.book_panel.visible)
	main._toggle_book()
	_check("and closes again", not main._book_open)
	_check("cooking is remembered", main.cooked.has(str(pot_keep_id)))
	main._set_room(1)
	main.pot_ingredients.clear()
	main.pot_dish = -1
	main.pot_cook = 0.0
	main.hand_kind = 1
	main.hand_id = 0
	main.player_pos = main.POT_SPOT + Vector2(0.0, 20.0)
	main.interact()
	main._update_pot_visual()
	_check("a thing in the pot shows as an icon", main.pot_icons[0].visible)
	_check("and the pot names what the next jar would make", main._jar_dish_name(1) == Recipes.dish_name(Recipes.dish_for(0, 1)))
	main.hand_kind = 0
	main.hand_id = -1
	main.pot_ingredients.clear()
	main.pot_dish = -1
	main.pot_cook = 0.0
	main._update_pot_visual()
	_check("and the icon goes when the pot is empty", not main.pot_icons[0].visible)
	main._set_room(0)
	main.hand_kind = pot_keep_kind
	main.hand_id = pot_keep_id

	# --- and the village outside the front door
	var keep_kind: int = main.hand_kind
	var keep_id: int = main.hand_id
	main._set_room(2)
	main.player_pos = main.VILLAGE_ENTRY
	_check("the village floor is clear", main._free(main.player_pos))
	var vreach: Dictionary = _flood(main)
	_check("walks to the grocer's stall", _reachable(vreach, main.SHOP_SPOTS[0] + Vector2(0.0, 24.0)))
	_check("walks to the last basket", _reachable(vreach, main.SHOP_SPOTS[4] + Vector2(0.0, 24.0)))
	_check("walks to the inn door", _reachable(vreach, main.INN_DOOR_OUT + Vector2(0.0, 12.0)))
	_check("there is a car", main.car != null)
	_check("two villagers walk the street", main.village_npcs.size() == 2)
	main.coins = 20
	main.hand_kind = 0
	main.hand_id = -1
	main.player_pos = main.SHOP_SPOTS[1] + Vector2(0.0, 24.0)
	main.interact()
	_check("bought something from the grocer", main.hand_kind == 1 and main.hand_id == 1)
	_check("and paid for it", main.coins == 20 - int(main.SHOP_PRICES[1]))
	main.interact()
	_check("cannot buy with full hands", main.coins == 20 - int(main.SHOP_PRICES[1]))
	main.hand_kind = keep_kind
	main.hand_id = keep_id

	# --- a guest arrives, walks to a chair and sits on it
	main._set_room(0)
	main.clock_min = 17 * 60 + 20
	var guard: int = 0
	while main.guest_state_name(0) != "sitting" and guard < 900:
		main.tick(0.05)
		guard += 1
	_check("the badger sat down", main.guest_state_name(0) == "sitting")
	_check("and is on its chair", main.guest_seated(0))
	_check("it has an order", main.guest_order(0) >= 0 and main.guest_order(0) < 10)
	_check("its coat is on the rack", main.coat_count() == 1)

	# --- serving the dish they asked for
	main.guests[0]["order"] = main.hand_id
	main.player_pos = main.TABLES[0] + main.SEAT_OFFSET + Vector2(0.0, 10.0)
	var coins_before: int = main.coins
	main.interact()
	_check("the right dish is eaten", main.guest_state_name(0) == "eating")
	_check("and paid for well", main.coins >= coins_before + Recipes.dish_price(0))

	# --- serving a dish nobody asked for still feeds them
	var g1: Dictionary = main.guests[1]
	main._spawn_guest(g1)
	main._seat_guest(g1)
	main.guests[1]["order"] = 9
	main.hand_kind = 2
	main.hand_id = 0
	var coins_before2: int = main.coins
	main.player_pos = main.TABLES[3] + main.SEAT_OFFSET + Vector2(0.0, 10.0)
	main.interact()
	_check("a wrong dish is still eaten", main.guest_state_name(1) == "eating")
	_check("and still pays something", main.coins > coins_before2)

	# --- asking what they want, and listening afterwards
	main.guests[0]["state"] = 2
	main.hand_kind = 0
	main.hand_id = -1
	main.player_pos = main.TABLES[0] + main.SEAT_OFFSET + Vector2(0.0, 10.0)
	main.interact()
	_check("they say what they were hoping for", main._dialogue_open)
	main.interact()
	_check("and that closes", not main._dialogue_open)

	main.guests[0]["state"] = 4
	main.player_pos = main.TABLES[0] + main.SEAT_OFFSET + Vector2(0.0, 10.0)
	main.interact()
	_check("dialogue opened", main._dialogue_open)
	for i in range(3):
		main.interact()
	_check("dialogue closed", not main._dialogue_open)
	_check("the guest heads out", main.guest_state_name(0) == "outbound")
	guard = 0
	while main.guest_state_name(0) != "gone" and guard < 900:
		main.tick(0.05)
		guard += 1
	_check("the guest is gone", main.guest_state_name(0) == "gone")
	_check("and took the coat", main.coat_count() == 1)

	# --- the fire, the ledger, the save
	main.player_pos = main.hearth_pos
	main.fire = 0.40
	main.interact()
	_check("the fire was fed", main.fire > 0.40)

	# --- upgrades, and someone to help in the kitchen
	main.coins = 200
	main.player_pos = main.counter_pos + Vector2(0.0, -20.0)
	main.interact()
	_check("bought the first upgrade", main.bought.has("boots"))
	_check("and it cost coins", main.coins == 200 - 30)
	_check("boots make you faster", main._speed() > main.PLAYER_SPEED)
	for i in range(3):
		main.interact()
	_check("the cook was hired", main.bought.has("cook") and not main.cook.is_empty())
	main.pot_ingredients.clear()
	main.pot_dish = -1
	main.pot_cook = 0.0
	main.guests[1]["state"] = 2
	main.guests[1]["order"] = 4
	main.guests[1]["patience"] = 9999.0
	var guard2: int = 0
	while main.pot_dish < 0 and guard2 < 1400:
		main.tick(0.05)
		guard2 += 1
	_check("the cook filled the pot on her own", main.pot_dish == 4)

	main.clock_min = 23 * 60 - 1
	main.tick(2.0)
	_check("the night ended", main.night_over)
	_check("the ledger is open", main.ledger_panel.visible)
	_check("the ledger says something", main.ledger_lines.size() == 1 and str(main.ledger_lines[0]).length() > 20)
	_check("saved to disk", FileAccess.file_exists(SAVE))

	main.interact()
	_check("the next night starts", main.night == 2)
	_check("guests are cleared", main.guest_state_name(0) == "away")
	_check("the pot is clean", main.pot_ingredients.is_empty() and main.pot_dish == -1)
	_check("hands are empty", main.hand_kind == 0)
	_check("the ledger is shut", not main.ledger_panel.visible)

	print("")
	if _fail == 0:
		print("PASS  %d checks" % _pass)
	else:
		print("FAILED %d of %d checks" % [_fail, _pass + _fail])
		for f in _failed:
			print("   - %s" % f)
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	quit(0 if _fail == 0 else 1)
