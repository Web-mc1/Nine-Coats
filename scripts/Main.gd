extends Node2D

# Nine Coats -- the inn and the kitchen behind it, one evening at a time.
#
# The loop: a traveller comes in out of the rain and sits down, and tells you
# what they are hoping for. You go through to the kitchen, take two things off
# the shelf, put them in the pot, cook them, and carry the bowl back. Any two
# of the five things make a dish, and there are ten dishes, so the whole menu
# is the whole pantry. Get it wrong and they eat it anyway.
#
# The rules the loop is built to keep: no timers that punish you, no hunger, no
# way to lose, and no guest who ever gets angry. The only pressure is that the
# evening ends at 23:00 whether you were ready or not.

const Art = preload("res://scripts/Art.gd")
const PixelText = preload("res://scripts/PixelText.gd")
const Atmosphere = preload("res://scripts/Atmosphere.gd")
const Audio = preload("res://scripts/Audio.gd")
const Recipes = preload("res://scripts/Recipes.gd")

# --------------------------------------------------------------- constants --

const START_MIN := 17 * 60
const END_MIN := 23 * 60
const MIN_PER_SEC := 1.6

const PLAYER_SPEED := 46.0
const GUEST_SPEED := 24.0
const REACH := 26.0
const COOK_TIME := 3.2

const HAND_EMPTY := 0
const HAND_INGREDIENT := 1
const HAND_DISH := 2

enum Room { TAPROOM, KITCHEN, VILLAGE }
enum GState { AWAY, INBOUND, SITTING, EATING, TALKING, OUTBOUND, GONE }
const STATE_NAMES: Array = ["away", "inbound", "sitting", "eating", "talking", "outbound", "gone"]

# Nine tables, staggered so every seat has room for a chair and a person to
# stand in. The middle row is offset to leave gaps in the row below.
var TABLES: Array = [
	Vector2(96.0, 76.0), Vector2(160.0, 76.0), Vector2(224.0, 76.0),
	Vector2(128.0, 106.0), Vector2(192.0, 106.0), Vector2(256.0, 106.0),
	Vector2(96.0, 134.0), Vector2(160.0, 134.0), Vector2(224.0, 134.0),
]

var SEAT_OFFSET := Vector2(0.0, 15.0)
var counter_pos := Vector2(46.0, 122.0)
var hearth_pos := Vector2(24.0, 64.0)
var door_pos := Vector2(289.0, 62.0)

# the doorway between the two rooms, and where you stand to use it
var PASSAGE_TAP := Vector2(12.0, 96.0)
var PASSAGE_KIT := Vector2(308.0, 82.0)

# the five jars on the kitchen shelf, and the pot on the stove
var JAR_SPOTS: Array = [
	Vector2(93.0, 62.0), Vector2(123.0, 62.0), Vector2(153.0, 62.0),
	Vector2(183.0, 62.0), Vector2(213.0, 62.0),
]
var POT_SPOT := Vector2(253.0, 84.0)

# the village outside: where you come out, the way back in, and the grocer's
# baskets along the stall
var VILLAGE_ENTRY := Vector2(74.0, 112.0)
var INN_DOOR_OUT := Vector2(37.0, 100.0)
var SHOP_SPOTS: Array = [
	Vector2(190.0, 92.0), Vector2(214.0, 92.0), Vector2(238.0, 92.0),
	Vector2(262.0, 92.0), Vector2(286.0, 92.0),
]
var SHOP_PRICES: Array = [3, 2, 2, 3, 4]

# things you can build for the inn, in the order they are offered
var UPGRADES: Array = [
	{"id": "boots", "name": "FASTER BOOTS", "price": 30},
	{"id": "larder", "name": "A BIGGER LARDER", "price": 40},
	{"id": "hearth", "name": "A BETTER HEARTH", "price": 35},
	{"id": "cook", "name": "HIRE A COOK", "price": 60},
]

var BOUNDS_MIN := Vector2(8.0, 60.0)
var BOUNDS_MAX := Vector2(312.0, 150.0)

# ------------------------------------------------------------------- state --

var save_path: String = "user://ninecoats_save.json"

var night: int = 1
var clock_min: int = START_MIN
var coins: int = 12
var served_total: int = 0
var ledger_lines: Array = []

var fire: float = 0.75
var night_over: bool = false
var toast: String = ""
var toast_t: float = 0.0

var room: int = Room.TAPROOM
var player_pos := Vector2(64.0, 100.0)
var guests: Array = []

# hands hold one thing: an ingredient or a finished dish
var hand_kind: int = HAND_EMPTY
var hand_id: int = -1

# what is in the pot, and what came out of it
var pot_ingredients: Array = []
var pot_dish: int = -1
var pot_cook: float = 0.0

var guests_served: int = 0
var coins_earned: int = 0
var dishes_cooked: int = 0

var GUEST_DATA: Array = [
	{
		"kind": "badger",
		"name": "BRAMBLE",
		"trade": "BADGER, CARTOGRAPHER",
		"coat": Color8(112, 96, 78),
		"table": 0,
		"hook": 1,
		"pitch": 0.82,
		"voice": 0,
		"delay": 12,
		"lines": [
			"The road on my map stops at the bridge.",
			"I keep redrawing it. It ends in the same place.",
			"Thank you. The fire is a better landmark than I am.",
		],
	},
	{
		"kind": "heron",
		"name": "SABLE",
		"trade": "HERON, COURIER",
		"coat": Color8(92, 108, 132),
		"table": 3,
		"hook": 4,
		"pitch": 1.34,
		"voice": 1,
		"delay": 62,
		"lines": [
			"I'm carrying a letter to a house that isn't there anymore.",
			"I'll knock anyway. It seems rude not to.",
			"...Thank you. That was better than the road deserved.",
		],
	},
	{
		"kind": "mole",
		"name": "FENN",
		"trade": "MOLE, AWAKE",
		"coat": Color8(84, 92, 74),
		"table": 5,
		"hook": 7,
		"pitch": 0.68,
		"voice": 2,
		"delay": 112,
		"lines": [
			"I can't sleep. Out there the quiet is too big.",
			"In here the quiet has floorboards in it.",
			"That's better. That's much better.",
		],
	},
]

# ------------------------------------------------------------------- nodes --

var world: Node2D
var bg: Sprite2D
var tap_fx: Node2D
var tap_root: Node2D
var kit_root: Node2D
var vil_fx: Node2D
var vil_root: Node2D
var bubble_layer: Node2D
var fire_sprite: Sprite2D
var dusk: CanvasModulate
var glows: Array = []
var player: Sprite2D
var fade: ColorRect

var pot_fill: Sprite2D
var pot_bubbles: Sprite2D

var hud: CanvasLayer
var clock_text: PixelText
var night_text: PixelText
var coins_text: PixelText
var prompt_text: PixelText
var hand_icon: Sprite2D
var fire_bar: ColorRect

var dialogue_box: Node2D
var dialogue_name: PixelText
var dialogue_line: PixelText
var dialogue_hint: PixelText

var ledger_panel: Node2D
var ledger_title: PixelText
var ledger_body: Array = []
var ledger_hint: PixelText

var music_player: AudioStreamPlayer
var step_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var voice_player: AudioStreamPlayer

# ----------------------------------------------------------------- runtime --

var _time_accum: float = 0.0
var _walk_t: float = 0.0
var _fire_t: float = 0.0
var _anim_t: float = 0.0
var _facing: int = 0
var _interact_held: bool = false
var _last_step_beat: int = 0
var _dialogue_open: bool = false
var _dialogue_guest: Dictionary = {}
var _dialogue_lines: Array = []
var _dialogue_leaves: bool = false
var _obstacles: Array = []
var _obstacles_tap: Array = []
var _obstacles_kit: Array = []
var _obstacles_vil: Array = []
var village_npcs: Array = []
var car: Sprite2D
var _car_x: float = -60.0
var _car_driving: bool = false
var _car_wait: float = 6.0
var bought: Dictionary = {}
var cook: Dictionary = {}
var _table_bowls: Array = []
var _tts_seen: bool = false
var _tts_voices: Array = []
var _icon_cache: Dictionary = {}


# =============================================================== boot =======

func _ready() -> void:
	_build_world()
	_build_hud()
	_build_audio()
	_init_tts()
	load_game()
	_start_night()
	get_tree().auto_accept_quit = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()


func _build_world() -> void:
	world = Node2D.new()
	add_child(world)

	bg = Sprite2D.new()
	bg.texture = Art.make_room()
	bg.centered = false
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.z_index = -10
	world.add_child(bg)

	tap_fx = Node2D.new()
	world.add_child(tap_fx)

	tap_root = Node2D.new()
	tap_root.y_sort_enabled = true
	world.add_child(tap_root)

	kit_root = Node2D.new()
	kit_root.y_sort_enabled = true
	kit_root.visible = false
	world.add_child(kit_root)

	vil_fx = Node2D.new()
	vil_fx.visible = false
	world.add_child(vil_fx)

	vil_root = Node2D.new()
	vil_root.y_sort_enabled = true
	vil_root.visible = false
	world.add_child(vil_root)

	bubble_layer = Node2D.new()
	bubble_layer.z_index = 5
	world.add_child(bubble_layer)

	_build_taproom()
	_build_kitchen()
	_build_village()

	player = _make_actor("player", player_pos, tap_root)

	dusk = CanvasModulate.new()
	dusk.color = Color(1.0, 0.98, 0.94, 1.0)
	world.add_child(dusk)

	_set_room(Room.TAPROOM)


func _build_taproom() -> void:
	fire_sprite = Sprite2D.new()
	fire_sprite.texture = Art.fire_frames()[0]
	fire_sprite.centered = false
	fire_sprite.offset = Vector2(-8.0, -16.0)
	fire_sprite.position = Vector2(25.0, 54.0)
	fire_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fire_sprite.z_index = -3
	tap_fx.add_child(fire_sprite)

	_add_prop(Art.make_counter(), Vector2(46.0, 146.0), tap_root)
	_add_prop(Art.make_barrel(), Vector2(78.0, 72.0), tap_root)
	_add_prop(Art.make_crate(), Vector2(78.0, 94.0), tap_root)
	_add_prop(Art.make_plant(), Vector2(258.0, 64.0), tap_root)
	_add_prop(Art.make_cat(), Vector2(56.0, 68.0), tap_root)

	for i in range(TABLES.size()):
		var p: Vector2 = TABLES[i]
		_add_prop(Art.make_table(), p, tap_root)
		# one chair at every seat, sitting exactly where the guest sits so the
		# back reads as being behind them
		_add_prop(Art.make_chair(), p + SEAT_OFFSET, tap_root)
		_obstacles_tap.append(Rect2(p.x - 11.0, p.y - 9.0, 22.0, 11.0))

	for t in [0, 4, 8]:
		var tp: Vector2 = TABLES[t]
		_add_prop(Art.make_candle(), tp + Vector2(0.0, -6.0), tap_root)

	_obstacles_tap.append(Rect2(16.0, 112.0, 60.0, 34.0))
	_obstacles_tap.append(Rect2(70.0, 62.0, 16.0, 10.0))
	_obstacles_tap.append(Rect2(70.0, 84.0, 16.0, 10.0))
	_obstacles_tap.append(Rect2(251.0, 54.0, 14.0, 10.0))

	# warm halos: two lanterns and the hearth
	var glow_tex: Texture2D = Art.make_glow()
	var spots: Array = [
		[Vector2(float(Art.LANTERN_XS[0]), 24.0), 0.9, 0.22],
		[Vector2(float(Art.LANTERN_XS[1]), 24.0), 0.9, 0.22],
		[Vector2(25.0, 46.0), 1.0, 0.26],
	]
	for s in spots:
		var g: Sprite2D = Sprite2D.new()
		g.texture = glow_tex
		g.position = s[0]
		g.scale = Vector2(s[1], s[1])
		g.modulate = Color(1.0, 0.86, 0.62, s[2])
		var mat: CanvasItemMaterial = CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		g.material = mat
		g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		g.z_index = 4
		tap_fx.add_child(g)
		glows.append({"node": g, "base": float(s[2]), "hearth": s[0].x < 40.0})

	var air: Node2D = Atmosphere.new()
	air.z_index = 6
	tap_fx.add_child(air)


func _build_kitchen() -> void:
	_add_prop(Art.make_barrel(), Vector2(60.0, 120.0), kit_root)
	_add_prop(Art.make_crate(), Vector2(236.0, 118.0), kit_root)
	_obstacles_kit.append(Rect2(52.0, 110.0, 16.0, 10.0))
	_obstacles_kit.append(Rect2(228.0, 108.0, 16.0, 10.0))
	_obstacles_kit.append(Rect2(222.0, 34.0, 62.0, 42.0))
	_obstacles_kit.append(Rect2(126.0, 104.0, 48.0, 22.0))

	pot_fill = Sprite2D.new()
	pot_fill.centered = true
	pot_fill.position = Vector2(253.0, 22.0)
	pot_fill.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pot_fill.z_index = -2
	pot_fill.visible = false
	world.add_child(pot_fill)

	pot_bubbles = Sprite2D.new()
	pot_bubbles.centered = true
	pot_bubbles.position = Vector2(253.0, 12.0)
	pot_bubbles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pot_bubbles.z_index = 3
	pot_bubbles.visible = false
	world.add_child(pot_bubbles)


func _has(id: String) -> bool:
	return bought.has(id)


func _speed() -> float:
	return PLAYER_SPEED * (1.35 if _has("boots") else 1.0)


func _shop_price(i: int) -> int:
	var price: int = int(SHOP_PRICES[i])
	if _has("larder"):
		price = maxi(1, price - 1)
	return price


func _next_upgrade() -> Dictionary:
	for u in UPGRADES:
		if not _has(str(u["id"])):
			return u
	return {}


func _buy_upgrade() -> void:
	var u: Dictionary = _next_upgrade()
	if u.is_empty():
		_toast("THE OLD PLACE HAS EVERYTHING")
		return
	var price: int = int(u["price"])
	if coins < price:
		_toast("NOT ENOUGH IN THE TIN")
		return
	coins = coins - price
	bought[str(u["id"])] = true
	_play_ping()
	if str(u["id"]) == "cook":
		_spawn_cook()
		_toast("A COOK, AND SHE KNOWS HER WAY AROUND A POT")
	else:
		_toast("%s. IT IS DONE" % str(u["name"]))
	save_game()


func _spawn_cook() -> void:
	if not cook.is_empty():
		return
	var s: Sprite2D = _make_actor("hare", Vector2(200.0, 96.0), kit_root)
	cook = {"node": s, "state": 0, "target": Vector2(200.0, 96.0), "jar": -1, "carry": -1}


func _cook_plan() -> int:
	# what the pot is missing for whoever is waiting right now
	var order: int = -1
	for g in guests:
		if int(g["state"]) == GState.SITTING:
			order = int(g["order"])
			break
	if order < 0 or order >= Recipes.count():
		return -1
	var d: Dictionary = Recipes.DISHES[order]
	var a: int = int(d["a"])
	var b: int = int(d["b"])
	if pot_ingredients.size() == 0:
		return a
	if pot_ingredients.size() == 1:
		var have: int = int(pot_ingredients[0])
		if have == a:
			return b
		if have == b:
			return a
	return -1


func _move_cook(s: Sprite2D, delta: float) -> bool:
	var to: Vector2 = cook["target"] - s.position
	var step: float = 30.0 * delta
	if to.length() <= step:
		s.position = cook["target"]
		return true
	s.position = s.position + to.normalized() * step
	_face_actor(s, _dir_from_vec(to), int(_anim_t * 7.0) % 4)
	return false


func _update_cook(delta: float) -> void:
	if cook.is_empty():
		return
	var s: Sprite2D = cook["node"]
	if s == null or not is_instance_valid(s):
		return
	var st: int = int(cook["state"])
	if st == 0:
		if pot_cook > 0.0 or pot_dish >= 0:
			return
		if pot_ingredients.size() >= 2:
			cook["state"] = 3
			cook["target"] = Vector2(253.0, 86.0)
			return
		var want: int = _cook_plan()
		if want < 0:
			return
		cook["jar"] = want
		cook["state"] = 1
		cook["target"] = Vector2(JAR_SPOTS[want].x, 76.0)
		return
	if st == 1:
		if _move_cook(s, delta):
			cook["carry"] = int(cook["jar"])
			cook["state"] = 2
			cook["target"] = Vector2(253.0, 86.0)
		return
	if st == 2:
		if _move_cook(s, delta):
			if int(cook["carry"]) >= 0 and pot_ingredients.size() < 2:
				pot_ingredients.append(int(cook["carry"]))
			cook["carry"] = -1
			cook["state"] = 0
			_update_pot_visual()
		return
	if st == 3:
		if _move_cook(s, delta):
			pot_cook = COOK_TIME
			_update_pot_visual()
			cook["state"] = 0
			_toast("THE COOK SETS IT GOING")


func _build_village() -> void:
	# the fronts along the street, which you cannot walk through
	_obstacles_vil.append(Rect2(0.0, 12.0, 96.0, 92.0))
	_obstacles_vil.append(Rect2(104.0, 20.0, 56.0, 84.0))
	_obstacles_vil.append(Rect2(168.0, 16.0, 144.0, 92.0))

	# baskets of things for sale along the grocer's stall
	for i in range(SHOP_SPOTS.size()):
		var b: Sprite2D = _add_prop(Art.make_basket(Recipes.ingredient_col(i)), SHOP_SPOTS[i], vil_root)
		b.z_index = 1

	# a car, off the end of the street until it drives past
	car = Sprite2D.new()
	car.texture = Art.make_car()
	car.centered = true
	car.position = Vector2(-60.0, 142.0)
	car.visible = false
	car.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	vil_root.add_child(car)

	# two villagers walking the street
	var kinds: Array = ["hare", "fox"]
	for i in range(kinds.size()):
		var a: Sprite2D = _make_actor(str(kinds[i]), Vector2(70.0 + float(i) * 140.0, 118.0 + float(i) * 14.0), vil_root)
		village_npcs.append({
			"node": a,
			"x0": 24.0,
			"x1": 300.0,
			"dir": 1 if i == 0 else -1,
			"speed": 16.0 + float(i) * 5.0,
		})

	# the street lamp, as a glow on the snow
	var g: Sprite2D = Sprite2D.new()
	g.texture = Art.make_glow()
	g.position = Vector2(101.0, 96.0)
	g.scale = Vector2(1.3, 1.3)
	g.modulate = Color(1.0, 0.86, 0.62, 0.26)
	var mat: CanvasItemMaterial = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	g.material = mat
	g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	g.z_index = 4
	vil_fx.add_child(g)


func _update_village(delta: float) -> void:
	if room != Room.VILLAGE:
		return
	for npc in village_npcs:
		var a: Sprite2D = npc["node"]
		if a == null or not is_instance_valid(a):
			continue
		var dir: int = int(npc["dir"])
		a.position.x = a.position.x + float(dir) * float(npc["speed"]) * delta
		if a.position.x < float(npc["x0"]):
			a.position.x = float(npc["x0"])
			npc["dir"] = 1
			dir = 1
		elif a.position.x > float(npc["x1"]):
			a.position.x = float(npc["x1"])
			npc["dir"] = -1
			dir = -1
		_face_actor(a, 3 if dir > 0 else 2, int(_anim_t * 7.0) % 4)
	if car == null or not is_instance_valid(car):
		return
	if not _car_driving:
		_car_wait = _car_wait - delta
		if _car_wait <= 0.0:
			_car_driving = true
			_car_x = -40.0
		return
	car.visible = true
	_car_x = _car_x + 54.0 * delta
	car.position = Vector2(_car_x, 142.0)
	if _car_x > 372.0:
		_car_driving = false
		_car_wait = 14.0
		car.visible = false


func _near_basket() -> int:
	for i in range(SHOP_SPOTS.size()):
		if _near(SHOP_SPOTS[i] + Vector2(0.0, 6.0), 26.0):
			return i
	return -1


func _update_village_prompt() -> void:
	if _near(INN_DOOR_OUT + Vector2(0.0, 12.0), 24.0):
		prompt_text.set_text("E    BACK INSIDE")
		return
	var i: int = _near_basket()
	if i >= 0:
		var price: int = _shop_price(i)
		if hand_kind != HAND_EMPTY:
			prompt_text.set_text("YOUR HANDS ARE FULL")
		elif coins < price:
			prompt_text.set_text("%s IS %d COINS. NOT ENOUGH" % [Recipes.ingredient_name(i), price])
		else:
			prompt_text.set_text("E    BUY THE %s, %d COINS" % [Recipes.ingredient_name(i), price])
		return
	prompt_text.set_text("")


func _interact_village() -> void:
	if _near(INN_DOOR_OUT + Vector2(0.0, 12.0), 24.0):
		player_pos = Vector2(285.0, 80.0)
		_set_room(Room.TAPROOM)
		_toast("IN, OUT OF THE SNOW")
		return
	var i: int = _near_basket()
	if i < 0:
		return
	if hand_kind != HAND_EMPTY:
		_toast("YOUR HANDS ARE FULL")
		return
	if coins < _shop_price(i):
		_toast("NOT ENOUGH IN THE TIN")
		return
	coins = coins - _shop_price(i)
	hand_kind = HAND_INGREDIENT
	hand_id = i
	_play_ping()
	_toast("THE %s, AND YOUR CHANGE" % Recipes.ingredient_name(i))
	_update_hand_icon()


func _add_prop(tex: Texture2D, pos: Vector2, parent: Node) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.offset = Vector2(-float(tex.get_width()) / 2.0, -float(tex.get_height()))
	s.position = pos
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(s)
	return s


func _make_actor(kind: String, pos: Vector2, parent: Node) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.texture = Art.char_tex(kind, 0, 0)
	s.centered = false
	s.offset = Vector2(-6.0, -16.0)
	s.position = pos
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.set_meta("kind", kind)
	parent.add_child(s)
	return s


func _face_actor(s: Sprite2D, dir: int, frame: int) -> void:
	var kind: String = str(s.get_meta("kind"))
	if kind == "":
		return
	s.texture = Art.char_tex(kind, dir, frame)


func _sit_actor(s: Sprite2D, frame: int) -> void:
	var kind: String = str(s.get_meta("kind"))
	if kind == "":
		return
	s.texture = Art.sit_tex(kind, 0, frame)


func _set_room(r: int) -> void:
	room = r
	var tap: bool = r == Room.TAPROOM
	var kit: bool = r == Room.KITCHEN
	var out: bool = r == Room.VILLAGE
	bg.texture = Art.make_room() if tap else (Art.make_kitchen() if kit else Art.make_village())
	tap_root.visible = tap
	kit_root.visible = kit
	vil_root.visible = out
	tap_fx.visible = tap
	vil_fx.visible = out
	bubble_layer.visible = tap
	if tap:
		_obstacles = _obstacles_tap
	elif kit:
		_obstacles = _obstacles_kit
	else:
		_obstacles = _obstacles_vil
	if is_instance_valid(player):
		var target: Node = tap_root if tap else (kit_root if kit else vil_root)
		var parent: Node = player.get_parent()
		if parent != null and parent != target:
			parent.remove_child(player)
		if player.get_parent() == null:
			target.add_child(player)
	if not kit and is_instance_valid(pot_bubbles):
		pot_bubbles.visible = false
	_update_hand_icon()


# ================================================================ HUD =======

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 10
	add_child(hud)

	var bar: Sprite2D = Sprite2D.new()
	bar.texture = Art.make_panel(320, 28, Color(0.10, 0.086, 0.112, 0.95), Art.AMBER_D)
	bar.centered = false
	bar.position = Vector2(0.0, 152.0)
	bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hud.add_child(bar)

	clock_text = _label(hud, Vector2(6.0, 157.0), 1, Art.CREAM)
	night_text = _label(hud, Vector2(46.0, 157.0), 1, Art.AMBER_D)
	coins_text = _label(hud, Vector2(268.0, 157.0), 1, Art.AMBER)

	var fire_label: PixelText = _label(hud, Vector2(196.0, 157.0), 1, Art.AMBER_D)
	fire_label.set_text("FIRE")

	var fire_bg: ColorRect = ColorRect.new()
	fire_bg.position = Vector2(222.0, 159.0)
	fire_bg.size = Vector2(42.0, 4.0)
	fire_bg.color = Color(0.22, 0.16, 0.14, 1.0)
	hud.add_child(fire_bg)

	fire_bar = ColorRect.new()
	fire_bar.position = Vector2(222.0, 159.0)
	fire_bar.size = Vector2(30.0, 4.0)
	fire_bar.color = Art.AMBER
	hud.add_child(fire_bar)

	hand_icon = Sprite2D.new()
	hand_icon.centered = false
	hand_icon.position = Vector2(298.0, 164.0)
	hand_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hand_icon.visible = false
	hud.add_child(hand_icon)

	prompt_text = _label(hud, Vector2(160.0, 168.0), 1, Art.CREAM)
	prompt_text.centered = true

	# dialogue
	dialogue_box = Node2D.new()
	dialogue_box.visible = false
	hud.add_child(dialogue_box)

	var dpanel: Sprite2D = Sprite2D.new()
	dpanel.texture = Art.make_panel(300, 42, Color(0.11, 0.09, 0.11, 0.96), Art.AMBER_D)
	dpanel.centered = false
	dpanel.position = Vector2(10.0, 104.0)
	dpanel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dialogue_box.add_child(dpanel)

	dialogue_name = _label(dialogue_box, Vector2(18.0, 109.0), 1, Art.AMBER)
	dialogue_line = _label(dialogue_box, Vector2(18.0, 120.0), 1, Art.CREAM)
	dialogue_hint = _label(dialogue_box, Vector2(18.0, 133.0), 1, Art.AMBER_D)
	dialogue_hint.set_text("E   ...")

	_build_ledger()


func _build_ledger() -> void:
	ledger_panel = Node2D.new()
	ledger_panel.visible = false
	hud.add_child(ledger_panel)

	fade = ColorRect.new()
	fade.position = Vector2.ZERO
	fade.size = Vector2(320.0, 180.0)
	fade.color = Color(0.04, 0.035, 0.05, 0.74)
	ledger_panel.add_child(fade)

	var page: Sprite2D = Sprite2D.new()
	page.texture = Art.make_panel(272, 118, Color(0.126, 0.108, 0.104, 0.98), Art.AMBER_D)
	page.centered = false
	page.position = Vector2(24.0, 30.0)
	page.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ledger_panel.add_child(page)

	var head: PixelText = _label(ledger_panel, Vector2(160.0, 40.0), 1, Art.AMBER_D)
	head.set_text("THE LEDGER")
	head.centered = true

	ledger_title = _label(ledger_panel, Vector2(160.0, 52.0), 2, Art.AMBER_L)
	ledger_title.centered = true

	for i in range(3):
		var line: PixelText = _label(ledger_panel, Vector2(38.0, 82.0 + i * 13.0), 1, Art.CREAM)
		ledger_body.append(line)

	ledger_hint = _label(ledger_panel, Vector2(160.0, 132.0), 1, Art.AMBER)
	ledger_hint.set_text("E    SLEEP UNTIL MORNING")
	ledger_hint.centered = true


func _label(parent: Node, pos: Vector2, size: int, col: Color) -> PixelText:
	var t: PixelText = PixelText.new()
	t.position = pos
	t.tint = col
	t.pixel_scale = size
	parent.add_child(t)
	return t


func _hand_tex() -> Texture2D:
	if hand_kind == HAND_INGREDIENT:
		var key: String = "jar_%d" % hand_id
		if not _icon_cache.has(key):
			_icon_cache[key] = Art.make_jar(Recipes.ingredient_col(hand_id))
		return _icon_cache[key]
	if hand_kind == HAND_DISH:
		var key2: String = "plate_%d" % hand_id
		if not _icon_cache.has(key2):
			_icon_cache[key2] = Art.make_plate(Recipes.dish_col(hand_id))
		return _icon_cache[key2]
	return null


func _update_hand_icon() -> void:
	if not is_instance_valid(hand_icon):
		return
	var tex: Texture2D = _hand_tex()
	if tex == null:
		hand_icon.visible = false
		return
	hand_icon.texture = tex
	hand_icon.visible = true


# ================================================================ sound ====

func _build_audio() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -19.0
	add_child(music_player)

	step_player = AudioStreamPlayer.new()
	step_player.volume_db = -17.0
	add_child(step_player)

	sfx_player = AudioStreamPlayer.new()
	sfx_player.volume_db = -11.0
	add_child(sfx_player)

	voice_player = AudioStreamPlayer.new()
	voice_player.volume_db = -15.0
	add_child(voice_player)

	step_player.stream = Audio.step()
	voice_player.stream = Audio.voice()
	sfx_player.stream = Audio.ping()
	_begin_music()


func _begin_music() -> void:
	# let the first frame draw before spending a moment synthesising the loop
	await get_tree().process_frame
	if not is_instance_valid(music_player):
		return
	music_player.stream = Audio.music()
	music_player.play()


func _play_step() -> void:
	if not is_instance_valid(step_player):
		return
	step_player.pitch_scale = 0.90 + randf() * 0.20
	step_player.play()


func _speak(pitch: float) -> void:
	if not is_instance_valid(voice_player):
		return
	voice_player.pitch_scale = clampf(pitch, 0.5, 2.0)
	voice_player.play()


func _play_ping() -> void:
	if not is_instance_valid(sfx_player):
		return
	sfx_player.stream = Audio.ping()
	sfx_player.play()


func _play_chime() -> void:
	if not is_instance_valid(sfx_player):
		return
	sfx_player.stream = Audio.chime()
	sfx_player.play()


# ================================================================= speech ==
# Real speech when the machine has a speech server (speech-dispatcher on
# Linux, SAPI on Windows, say on macOS), and the little synthesised blip when
# it does not, so a guest is never silent.

func _init_tts() -> void:
	if _tts_seen:
		return
	_tts_seen = true
	_tts_voices = DisplayServer.tts_get_voices()


func has_speech() -> bool:
	return _tts_voices.size() > 0


func _say(text: String, pitch: float, voice_index: int) -> void:
	if text.strip_edges() == "":
		return
	if has_speech():
		var v: Dictionary = _tts_voices[voice_index % _tts_voices.size()]
		DisplayServer.tts_speak(text, str(v["id"]), 80, clampf(pitch, 0.5, 1.6), 1.0, 1, true)
		return
	_speak(pitch)


func _hush() -> void:
	if has_speech():
		DisplayServer.tts_stop()


# ============================================================== the night ==

func _start_night() -> void:
	clock_min = START_MIN
	_time_accum = 0.0
	guests_served = 0
	coins_earned = 0
	dishes_cooked = 0
	night_over = false
	toast = ""
	toast_t = 0.0
	fire = 0.75
	_facing = 0
	player_pos = Vector2(64.0, 100.0)

	hand_kind = HAND_EMPTY
	hand_id = -1
	pot_ingredients.clear()
	pot_dish = -1
	pot_cook = 0.0
	if is_instance_valid(pot_fill):
		pot_fill.visible = false
	if is_instance_valid(pot_bubbles):
		pot_bubbles.visible = false

	_dialogue_open = false
	_dialogue_guest = {}
	_dialogue_lines = []
	dialogue_box.visible = false
	ledger_panel.visible = false

	_set_room(Room.TAPROOM)

	_clear_guests()
	guests.clear()
	for i in range(GUEST_DATA.size()):
		var data: Dictionary = GUEST_DATA[i]
		guests.append({
			"index": i,
			"state": GState.AWAY,
			"timer": 0.0,
			"patience": 0.0,
			"line_i": 0,
			"sprite": null,
			"coat": null,
			"bubble": null,
			"path": [],
			"dir": 0,
			"seated": false,
			"arrive": START_MIN + int(data["delay"]),
			"murmur": 2.0,
			"order": (night * 7 + i * 3) % Recipes.count(),
		})

	_update_hand_icon()
	_update_hud()
	_update_dusk()


func _clear_guests() -> void:
	_hush()
	for g in guests:
		if g["sprite"] != null:
			var s: Sprite2D = g["sprite"]
			if is_instance_valid(s):
				s.queue_free()
			g["sprite"] = null
		if g["coat"] != null:
			var c: Sprite2D = g["coat"]
			if is_instance_valid(c):
				c.queue_free()
			g["coat"] = null
		if g["bubble"] != null:
			var b: Sprite2D = g["bubble"]
			if is_instance_valid(b):
				b.queue_free()
			g["bubble"] = null
	for b in _table_bowls:
		if is_instance_valid(b):
			b.queue_free()
	_table_bowls.clear()


func _process(delta: float) -> void:
	if not night_over:
		_handle_movement(delta)
	_handle_keys()
	tick(delta)


func tick(delta: float) -> void:
	_anim_t += delta
	_sync_player()

	_fire_t += delta
	var frames: Array = Art.fire_frames()
	fire_sprite.texture = frames[int(_fire_t * 8.0) % frames.size()]
	fire = maxf(0.0, fire - delta * (0.006 if _has("hearth") else 0.010))
	_update_glow()
	_tick_pot(delta)
	_update_cook(delta)

	if night_over:
		return

	_time_accum += delta * MIN_PER_SEC
	while _time_accum >= 1.0:
		_time_accum -= 1.0
		clock_min += 1

	if toast_t > 0.0:
		toast_t = maxf(0.0, toast_t - delta)

	_update_guests(delta)
	_update_village(delta)
	_update_dusk()
	_update_hud()

	if clock_min >= END_MIN:
		_end_night()


func _sync_player() -> void:
	if is_instance_valid(player):
		player.position = player_pos


func _update_dusk() -> void:
	var t: float = clampf(float(clock_min - START_MIN) / float(END_MIN - START_MIN), 0.0, 1.0)
	var warm: Color = Color(1.0, 0.985, 0.95, 1.0)
	var cold: Color = Color(0.60, 0.62, 0.78, 1.0)
	dusk.color = warm.lerp(cold, t)


func _update_glow() -> void:
	for i in range(glows.size()):
		var entry: Dictionary = glows[i]
		var g: Sprite2D = entry["node"]
		if not is_instance_valid(g):
			continue
		var base: float = entry["base"]
		var flick: float = 0.92 + 0.08 * sin(_anim_t * 4.1 + i * 2.0) + 0.03 * sin(_anim_t * 11.0 + i)
		var strength: float = base
		if bool(entry["hearth"]):
			strength = 0.10 + base * fire
		g.modulate = Color(1.0, 0.86, 0.62, strength * flick)


func _update_hud() -> void:
	clock_text.set_text("%02d:%02d" % [clock_min / 60, clock_min % 60])
	night_text.set_text("NIGHT %d" % night)
	coins_text.set_text("COINS %d" % coins)
	_update_hand_icon()
	fire_bar.size = Vector2(maxf(1.0, 42.0 * fire), 4.0)
	fire_bar.color = Art.AMBER.lerp(Art.RUST, clampf(1.0 - fire, 0.0, 1.0))
	_update_prompt()


func _update_prompt() -> void:
	if toast_t > 0.0:
		prompt_text.set_text(toast)
		return
	if night_over or _dialogue_open:
		prompt_text.set_text("")
		return

	if room == Room.VILLAGE:
		_update_village_prompt()
		return

	if room == Room.KITCHEN:
		_update_kitchen_prompt()
		return

	if _near(PASSAGE_TAP, 22.0):
		prompt_text.set_text("E    THROUGH TO THE KITCHEN")
		return

	if _near(door_pos + Vector2(0.0, 16.0), 24.0):
		prompt_text.set_text("E    OUT INTO THE SNOW")
		return

	var g: Dictionary = _nearest_guest()
	if not g.is_empty():
		var st: int = int(g["state"])
		if st == GState.SITTING:
			var order: int = int(g["order"])
			if hand_kind == HAND_DISH:
				if hand_id == order:
					prompt_text.set_text("E    SERVE THE %s" % Recipes.dish_name(order))
				else:
					prompt_text.set_text("THEY ASKED FOR %s" % Recipes.dish_name(order))
			elif hand_kind == HAND_INGREDIENT:
				prompt_text.set_text("THAT BELONGS IN THE POT")
			else:
				prompt_text.set_text("E    ASK WHAT THEY WANT")
			return
		if st == GState.TALKING:
			prompt_text.set_text("E    LISTEN")
			return

	if _near(counter_pos, 30.0):
		var u: Dictionary = _next_upgrade()
		if u.is_empty():
			prompt_text.set_text("NOTHING LEFT TO BUILD")
		elif coins < int(u["price"]):
			prompt_text.set_text("%s COSTS %d COINS" % [str(u["name"]), int(u["price"])])
		else:
			prompt_text.set_text("E    BUILD %s, %d COINS" % [str(u["name"]), int(u["price"])])
		return

	if _near(hearth_pos, 26.0):
		if fire < 0.85:
			prompt_text.set_text("E    FEED THE FIRE")
		else:
			prompt_text.set_text("THE FIRE IS HOLDING")
		return

	prompt_text.set_text("")


func _update_kitchen_prompt() -> void:
	if _near(PASSAGE_KIT, 22.0):
		prompt_text.set_text("E    BACK TO THE ROOM")
		return
	var jar: int = _near_jar()
	if jar >= 0:
		if hand_kind == HAND_EMPTY:
			prompt_text.set_text("E    TAKE THE %s" % Recipes.ingredient_name(jar))
		else:
			prompt_text.set_text("YOUR HANDS ARE FULL")
		return
	if _near(POT_SPOT, 30.0):
		if pot_cook > 0.0:
			prompt_text.set_text("IT NEEDS A MOMENT")
		elif pot_dish >= 0:
			if hand_kind == HAND_EMPTY:
				prompt_text.set_text("E    TAKE THE %s" % Recipes.dish_name(pot_dish))
			else:
				prompt_text.set_text("THE %s IS READY" % Recipes.dish_name(pot_dish))
		elif hand_kind == HAND_INGREDIENT and pot_ingredients.size() < 2:
			prompt_text.set_text("E    ADD THE %s" % Recipes.ingredient_name(hand_id))
		elif pot_ingredients.size() == 2:
			prompt_text.set_text("E    COOK IT")
		else:
			prompt_text.set_text("TWO THINGS MAKE A DISH")
		return
	prompt_text.set_text("")


# ================================================================ pot ======

func _near_jar() -> int:
	for i in range(JAR_SPOTS.size()):
		if _near(JAR_SPOTS[i], 22.0):
			return i
	return -1


func _tick_pot(delta: float) -> void:
	if pot_cook > 0.0:
		pot_cook = maxf(0.0, pot_cook - delta)
		if is_instance_valid(pot_bubbles):
			var frames: Array = Art.bubbles()
			pot_bubbles.texture = frames[int(_anim_t * 7.0) % frames.size()]
			pot_bubbles.visible = room == Room.KITCHEN
		if pot_cook <= 0.0:
			var a: int = int(pot_ingredients[0])
			var b: int = int(pot_ingredients[1])
			pot_dish = Recipes.dish_for(a, b)
			pot_ingredients.clear()
			dishes_cooked += 1
			_play_ping()
			_toast("THE %s IS READY" % Recipes.dish_name(pot_dish))
	_update_pot_visual()


func _update_pot_visual() -> void:
	if not is_instance_valid(pot_fill):
		return
	if pot_dish >= 0:
		pot_fill.texture = Art.make_pot_fill(Recipes.dish_col(pot_dish))
		pot_fill.visible = room == Room.KITCHEN
	elif pot_ingredients.size() > 0:
		pot_fill.texture = Art.make_pot_fill(_blend_colour())
		pot_fill.visible = room == Room.KITCHEN
	else:
		pot_fill.visible = false
	if pot_cook > 0.0 and room == Room.KITCHEN:
		pot_bubbles.visible = true
	elif pot_cook <= 0.0:
		pot_bubbles.visible = false


func _blend_colour() -> Color:
	var c: Color = Color(0, 0, 0, 0)
	for i in pot_ingredients:
		c = c.lerp(Recipes.ingredient_col(int(i)), 0.5)
	if pot_ingredients.size() == 1:
		c = Recipes.ingredient_col(int(pot_ingredients[0]))
	c.a = 1.0
	return c


# =============================================================== guests ====

func _update_guests(delta: float) -> void:
	for g in guests:
		var st: int = int(g["state"])
		var data: Dictionary = GUEST_DATA[int(g["index"])]

		# guests murmur to themselves while they sit, so the room is never silent
		if st == GState.SITTING or st == GState.EATING or st == GState.TALKING:
			g["murmur"] = float(g["murmur"]) - delta
			if float(g["murmur"]) <= 0.0:
				g["murmur"] = 4.5 + randf() * 6.0
				_speak(float(data.get("pitch", 1.0)) * 0.9)
			_animate_seated(g, st)

		match st:
			GState.AWAY:
				if clock_min >= int(g["arrive"]):
					_spawn_guest(g)
			GState.INBOUND:
				if _walk_guest(g, delta):
					_seat_guest(g)
					_toast("A COAT ON THE RACK")
					_speak(float(data.get("pitch", 1.0)))
			GState.SITTING:
				g["patience"] = float(g["patience"]) - delta
				if float(g["patience"]) <= 0.0:
					_leave(g)
			GState.EATING:
				g["timer"] = float(g["timer"]) - delta
				if float(g["timer"]) <= 0.0:
					g["state"] = GState.TALKING
					g["patience"] = 150.0
					_toast("FINISHED, AND NOT IN A HURRY")
			GState.TALKING:
				if _dialogue_open and _dialogue_guest.get("index", -1) == int(g["index"]):
					continue
				g["patience"] = float(g["patience"]) - delta
				if float(g["patience"]) <= 0.0:
					_leave(g)
			GState.OUTBOUND:
				if _walk_guest(g, delta):
					g["state"] = GState.GONE
					_drop_coat(g)
					_hide_bubble(g)
					if g["sprite"] != null and is_instance_valid(g["sprite"]):
						var s: Sprite2D = g["sprite"]
						s.queue_free()
					g["sprite"] = null


func _animate_seated(g: Dictionary, st: int) -> void:
	var sprite: Sprite2D = g["sprite"]
	if sprite == null or not is_instance_valid(sprite):
		return
	var frame: int = 0
	if st == GState.EATING:
		# chewing: the spoon goes up and down
		frame = 2 + (int(_anim_t * 2.4) % 2)
	else:
		# breathing, slowly
		frame = int(_anim_t * 1.1) % 2
	_sit_actor(sprite, frame)


func _spawn_guest(g: Dictionary) -> void:
	var data: Dictionary = GUEST_DATA[int(g["index"])]
	var sprite: Sprite2D = _make_actor(str(data["kind"]), door_pos + Vector2(0.0, -8.0), tap_root)
	g["sprite"] = sprite
	g["state"] = GState.INBOUND
	g["path"] = [door_pos + Vector2(0.0, 34.0), _seat_position(int(data["table"]))]
	g["dir"] = 3
	_add_coat(g)


func _walk_guest(g: Dictionary, delta: float) -> bool:
	var path: Array = g["path"]
	var sprite: Sprite2D = g["sprite"]
	if sprite == null or not is_instance_valid(sprite):
		return true
	if path.is_empty():
		return true
	var target: Vector2 = path[0]
	var to: Vector2 = target - sprite.position
	var step: float = GUEST_SPEED * delta
	if to.length() <= step:
		sprite.position = target
		path.pop_front()
		if path.is_empty():
			return true
	else:
		sprite.position = sprite.position + to.normalized() * step
		var d: int = _dir_from_vec(to)
		g["dir"] = d
		_face_actor(sprite, d, int(_anim_t * 7.0) % 4)
	return path.is_empty()


func _seat_guest(g: Dictionary) -> void:
	var data: Dictionary = GUEST_DATA[int(g["index"])]
	var seat: Vector2 = _seat_position(int(data["table"]))
	var sprite: Sprite2D = g["sprite"]
	g["state"] = GState.SITTING
	g["patience"] = 300.0
	g["dir"] = 0
	g["seated"] = true
	if sprite != null and is_instance_valid(sprite):
		sprite.position = seat
		_sit_actor(sprite, 0)
	_show_bubble(g)


func _seat_position(table_index: int) -> Vector2:
	var p: Vector2 = TABLES[table_index]
	return p + SEAT_OFFSET


func _show_bubble(g: Dictionary) -> void:
	if g["bubble"] != null and is_instance_valid(g["bubble"]):
		g["bubble"].visible = true
		return
	var seat: Vector2 = _seat_position(int(GUEST_DATA[int(g["index"])]["table"]))
	var b: Sprite2D = Sprite2D.new()
	b.texture = Art.make_order_bubble(Recipes.dish_col(int(g["order"])))
	b.centered = true
	b.position = seat + Vector2(0.0, -26.0)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bubble_layer.add_child(b)
	g["bubble"] = b


func _hide_bubble(g: Dictionary) -> void:
	if g["bubble"] != null and is_instance_valid(g["bubble"]):
		var b: Sprite2D = g["bubble"]
		b.queue_free()
	g["bubble"] = null


func _add_coat(g: Dictionary) -> void:
	var data: Dictionary = GUEST_DATA[int(g["index"])]
	var hook: int = int(data["hook"])
	var coat: Sprite2D = Sprite2D.new()
	coat.texture = Art.make_coat(data["coat"])
	coat.centered = false
	coat.offset = Vector2(-5.0, 0.0)
	coat.position = Vector2(float(Art.RACK_X + 5 + hook * 10), float(Art.RACK_Y + 4))
	coat.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tap_root.add_child(coat)
	g["coat"] = coat


func _drop_coat(g: Dictionary) -> void:
	if g["coat"] != null and is_instance_valid(g["coat"]):
		var c: Sprite2D = g["coat"]
		c.queue_free()
	g["coat"] = null


func _leave(g: Dictionary) -> void:
	g["state"] = GState.OUTBOUND
	g["seated"] = false
	_hide_bubble(g)
	var seat: Vector2 = _seat_position(int(GUEST_DATA[int(g["index"])]["table"]))
	g["path"] = [seat + Vector2(0.0, 18.0), door_pos + Vector2(0.0, 30.0)]
	if _dialogue_open and _dialogue_guest.get("index", -1) == int(g["index"]):
		_close_dialogue()


func coat_count() -> int:
	var n: int = 0
	for g in guests:
		if g["coat"] != null:
			n += 1
	return n


func guest_state_name(index: int) -> String:
	if index < 0 or index >= guests.size():
		return "none"
	return str(STATE_NAMES[int(guests[index]["state"])])


func guest_position(index: int) -> Vector2:
	if index < 0 or index >= guests.size():
		return Vector2.ZERO
	var s: Sprite2D = guests[index]["sprite"]
	if s == null or not is_instance_valid(s):
		return Vector2.ZERO
	return s.position


func guest_order(index: int) -> int:
	if index < 0 or index >= guests.size():
		return -1
	return int(guests[index]["order"])


func guest_seated(index: int) -> bool:
	if index < 0 or index >= guests.size():
		return false
	return bool(guests[index]["seated"])


# ============================================================ interaction ==

func _handle_keys() -> void:
	var down: bool = Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_ENTER)
	if down and not _interact_held:
		interact()
	_interact_held = down


func _handle_movement(delta: float) -> void:
	if _dialogue_open:
		return
	var dir: Vector2 = Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0

	if dir == Vector2.ZERO:
		_walk_t = 0.0
		_last_step_beat = 0
		_face_actor(player, _facing, 0)
		return

	dir = dir.normalized()
	_facing = _dir_from_vec(dir)
	_walk_t += delta * 3.4
	_move_player(dir * _speed() * delta)
	var beat: int = (int(_walk_t) / 2) % 2
	if beat != _last_step_beat:
		_last_step_beat = beat
		_play_step()
	_face_actor(player, _facing, int(_walk_t) % 4)


func _move_player(delta: Vector2) -> void:
	var nx: float = clampf(player_pos.x + delta.x, BOUNDS_MIN.x, BOUNDS_MAX.x)
	if _free(Vector2(nx, player_pos.y)):
		player_pos.x = nx
	var ny: float = clampf(player_pos.y + delta.y, BOUNDS_MIN.y, BOUNDS_MAX.y)
	if _free(Vector2(player_pos.x, ny)):
		player_pos.y = ny


func _free(pos: Vector2) -> bool:
	var foot: Rect2 = Rect2(pos.x - 4.0, pos.y - 5.0, 8.0, 6.0)
	for r in _obstacles:
		if foot.intersects(r):
			return false
	return true


func _near(p: Vector2, reach: float) -> bool:
	return player_pos.distance_to(p) <= reach


func _dir_from_vec(v: Vector2) -> int:
	if absf(v.x) > absf(v.y):
		return 3 if v.x > 0.0 else 2
	return 0 if v.y > 0.0 else 1


func _nearest_guest() -> Dictionary:
	var best: Dictionary = {}
	var best_d: float = REACH
	for g in guests:
		var st: int = int(g["state"])
		if st != GState.SITTING and st != GState.TALKING:
			continue
		var s: Sprite2D = g["sprite"]
		if s == null or not is_instance_valid(s):
			continue
		var d: float = player_pos.distance_to(s.position)
		if d <= best_d:
			best_d = d
			best = g
	return best


func interact() -> void:
	if night_over:
		_next_night()
		return

	if _dialogue_open:
		_advance_dialogue()
		return

	if room == Room.VILLAGE:
		_interact_village()
		return

	if room == Room.KITCHEN:
		_interact_kitchen()
		return

	if _near(PASSAGE_TAP, 22.0):
		player_pos = Vector2(280.0, 92.0)
		_set_room(Room.KITCHEN)
		_toast("THE KITCHEN, WARM AND CLATTERING")
		return

	if _near(door_pos + Vector2(0.0, 16.0), 24.0):
		player_pos = VILLAGE_ENTRY
		_set_room(Room.VILLAGE)
		_toast("OUT INTO THE SNOW")
		return

	var g: Dictionary = _nearest_guest()
	if not g.is_empty():
		var st: int = int(g["state"])
		if st == GState.SITTING:
			if hand_kind == HAND_DISH:
				_serve(g)
			elif hand_kind == HAND_INGREDIENT:
				_toast("THAT BELONGS IN THE POT")
			else:
				_open_order_line(g)
			return
		if st == GState.TALKING:
			_open_dialogue(g)
			return

	if _near(counter_pos, 30.0):
		_buy_upgrade()
		return

	if _near(hearth_pos, 26.0):
		if fire < 0.98:
			fire = minf(1.0, fire + 0.45)
			_toast("THE FIRE TAKES IT")
		return


func _interact_kitchen() -> void:
	if _near(PASSAGE_KIT, 22.0):
		player_pos = Vector2(40.0, 84.0)
		_set_room(Room.TAPROOM)
		_toast("THE ROOM, AND THE RAIN ON THE GLASS")
		return

	var jar: int = _near_jar()
	if jar >= 0:
		if hand_kind == HAND_EMPTY:
			hand_kind = HAND_INGREDIENT
			hand_id = jar
			_play_ping()
			_toast("YOU TAKE THE %s" % Recipes.ingredient_name(jar))
		else:
			_toast("YOUR HANDS ARE FULL")
		_update_hand_icon()
		return

	if _near(POT_SPOT, 30.0):
		_pot_interact()
		return


func _pot_interact() -> void:
	if pot_cook > 0.0:
		_toast("IT NEEDS A MOMENT")
		return

	if pot_dish >= 0:
		if hand_kind == HAND_EMPTY:
			hand_kind = HAND_DISH
			hand_id = pot_dish
			_toast("THE %s, STILL HOT" % Recipes.dish_name(pot_dish))
			pot_dish = -1
			_play_ping()
		else:
			_toast("PUT DOWN WHAT YOU ARE CARRYING")
		_update_hand_icon()
		_update_pot_visual()
		return

	if hand_kind == HAND_INGREDIENT:
		pot_ingredients.append(hand_id)
		var name: String = Recipes.ingredient_name(hand_id)
		hand_kind = HAND_EMPTY
		hand_id = -1
		_update_hand_icon()
		if pot_ingredients.size() == 2:
			_toast("TWO IN THE POT. NOW COOK IT")
		else:
			_toast("THE %s GOES IN" % name)
		_update_pot_visual()
		return

	if pot_ingredients.size() == 2:
		pot_cook = COOK_TIME
		_update_pot_visual()
		_play_ping()
		_toast("IT BEGINS TO SMELL LIKE SOMETHING")
		return

	_toast("TWO THINGS MAKE A DISH")


func _serve(g: Dictionary) -> void:
	var order: int = int(g["order"])
	var dish: int = hand_id
	hand_kind = HAND_EMPTY
	hand_id = -1
	_update_hand_icon()

	var right: bool = dish == order
	var price: int = Recipes.dish_price(dish)
	var paid: int = (price + 2) if right else maxi(3, price - 2)
	coins += paid
	coins_earned += paid
	served_total += 1
	guests_served += 1

	g["state"] = GState.EATING
	g["timer"] = 14.0
	_hide_bubble(g)

	# the plate goes down on their table
	var table: Vector2 = TABLES[int(GUEST_DATA[int(g["index"])]["table"])]
	var plate: Sprite2D = Sprite2D.new()
	plate.texture = Art.make_plate(Recipes.dish_col(dish))
	plate.centered = false
	plate.offset = Vector2(-5.0, -5.0)
	plate.position = table + Vector2(0.0, -7.0)
	plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	plate.z_index = 1
	bubble_layer.add_child(plate)
	_table_bowls.append(plate)

	_play_ping()
	if right:
		_toast("EXACTLY WHAT THEY WANTED")
	else:
		_toast("NOT WHAT THEY ASKED, AND THEY EAT IT ANYWAY")


func _toast(msg: String) -> void:
	toast = msg
	toast_t = 2.4


# ============================================================== dialogue ==

func _open_order_line(g: Dictionary) -> void:
	var order: int = int(g["order"])
	_dialogue_open = true
	_dialogue_guest = g
	_dialogue_lines = ["I was hoping for the %s." % Recipes.dish_name(order)]
	_dialogue_leaves = false
	g["line_i"] = 0
	dialogue_box.visible = true
	_show_dialogue_line()


func _open_dialogue(g: Dictionary) -> void:
	_dialogue_open = true
	_dialogue_guest = g
	_dialogue_lines = GUEST_DATA[int(g["index"])]["lines"]
	_dialogue_leaves = true
	g["line_i"] = 0
	dialogue_box.visible = true
	_show_dialogue_line()


func _show_dialogue_line() -> void:
	var data: Dictionary = GUEST_DATA[int(_dialogue_guest["index"])]
	var i: int = int(_dialogue_guest["line_i"])
	dialogue_name.set_text("%s   %s" % [str(data["name"]), str(data["trade"])])
	var text: String = ""
	if i >= 0 and i < _dialogue_lines.size():
		text = str(_dialogue_lines[i])
	dialogue_line.set_text(text)
	dialogue_hint.set_text("E    ...")
	_say(text, float(data.get("pitch", 1.0)), int(data.get("voice", 0)))


func _advance_dialogue() -> void:
	if _dialogue_guest.is_empty():
		_close_dialogue()
		return
	var i: int = int(_dialogue_guest["line_i"]) + 1
	_dialogue_guest["line_i"] = i
	if i >= _dialogue_lines.size():
		var g: Dictionary = _dialogue_guest
		var leaves: bool = _dialogue_leaves
		_close_dialogue()
		if leaves:
			_leave(g)
		return
	_show_dialogue_line()


func _close_dialogue() -> void:
	_dialogue_open = false
	_dialogue_guest = {}
	_dialogue_lines = []
	dialogue_box.visible = false
	_hush()


# ================================================================ ledger ==

func _end_night() -> void:
	if night_over:
		return
	night_over = true
	clock_min = END_MIN
	_close_dialogue()
	_prompt_clear()

	var line: String = ""
	match guests_served:
		0:
			line = "Nobody came up the pass. The pot stayed cold and the rain kept on."
		1:
			line = "One coat on the rack, and the fire had the room to itself."
		2:
			line = "Two travellers, and the long hours between them."
		_:
			line = "Three coats on the rack. The fire held until the last of them went up."
	line += "  %d coins in the tin." % coins_earned
	if dishes_cooked > 0:
		line += "  %d pots cooked." % dishes_cooked
	if guests_served >= 2:
		line += " The cat did not move."
	ledger_lines.append(line)

	ledger_title.set_text("NIGHT %d" % night)
	var wrapped: Array = _wrap(line, 38)
	for i in range(ledger_body.size()):
		var t: PixelText = ledger_body[i]
		if i < wrapped.size():
			t.set_text(str(wrapped[i]))
		else:
			t.set_text("")
	ledger_panel.visible = true
	_play_chime()
	save_game()


func _prompt_clear() -> void:
	prompt_text.set_text("")


func _wrap(text: String, width: int) -> Array:
	var words: PackedStringArray = text.split(" ")
	var out: Array = []
	var cur: String = ""
	for w in words:
		if cur == "":
			cur = w
		elif cur.length() + 1 + w.length() <= width:
			cur = cur + " " + w
		else:
			out.append(cur)
			cur = w
	if cur != "":
		out.append(cur)
	return out


func _next_night() -> void:
	night += 1
	_start_night()


# ================================================================== save ===

func save_game() -> void:
	var data: Dictionary = {
		"night": night,
		"coins": coins,
		"served": served_total,
		"ledger": ledger_lines,
		"upgrades": bought.keys(),
	}
	var f: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()


func load_game() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var f: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	night = int(data.get("night", 1))
	coins = int(data.get("coins", 0))
	served_total = int(data.get("served", 0))
	var led: Variant = data.get("ledger", [])
	if typeof(led) == TYPE_ARRAY:
		ledger_lines = led
	var ups: Variant = data.get("upgrades", [])
	if typeof(ups) == TYPE_ARRAY:
		for id in ups:
			bought[str(id)] = true
		if _has("cook"):
			_spawn_cook()
