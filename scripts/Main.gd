extends Node2D

# Nine Coats -- one room, one evening, three guests.
#
# The rules the loop is built to keep: no timers that punish you, no hunger, no
# way to lose, and no guest who ever gets angry. The only pressure is that the
# evening ends at 23:00 whether you were ready or not.

const Art = preload("res://scripts/Art.gd")
const PixelText = preload("res://scripts/PixelText.gd")
const Atmosphere = preload("res://scripts/Atmosphere.gd")

# --------------------------------------------------------------- constants --

const START_MIN := 17 * 60
const END_MIN := 23 * 60
const MIN_PER_SEC := 1.6

const PLAYER_SPEED := 46.0
const GUEST_SPEED := 24.0
const REACH := 28.0
const STEW_PRICE := 7
const STEW_PER_NIGHT := 6

enum GState { AWAY, INBOUND, SITTING, EATING, TALKING, OUTBOUND, GONE }
const STATE_NAMES: Array = ["away", "inbound", "sitting", "eating", "talking", "outbound", "gone"]

var TABLES: Array = [
	Vector2(104.0, 80.0), Vector2(168.0, 80.0), Vector2(232.0, 80.0),
	Vector2(104.0, 106.0), Vector2(168.0, 106.0), Vector2(232.0, 106.0),
	Vector2(104.0, 130.0), Vector2(168.0, 130.0), Vector2(232.0, 130.0),
]

var SEAT_OFFSET := Vector2(0.0, 15.0)
var counter_pos := Vector2(46.0, 122.0)
var hearth_pos := Vector2(24.0, 64.0)
var door_pos := Vector2(289.0, 62.0)

# ------------------------------------------------------------------- state --

var save_path: String = "user://ninecoats_save.json"

var night: int = 1
var clock_min: int = START_MIN
var coins: int = 0
var served_total: int = 0
var ledger_lines: Array = []

var fire: float = 0.75
var hands: int = 0
var stew_left: int = STEW_PER_NIGHT
var guests_served: int = 0
var coins_earned: int = 0
var night_over: bool = false
var toast: String = ""
var toast_t: float = 0.0

var player_pos := Vector2(64.0, 100.0)
var guests: Array = []

var GUEST_DATA: Array = [
	{
		"kind": "badger",
		"name": "BRAMBLE",
		"trade": "BADGER, CARTOGRAPHER",
		"coat": Color8(112, 96, 78),
		"table": 0,
		"hook": 1,
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
		"table": 4,
		"hook": 4,
		"delay": 70,
		"lines": [
			"I'm carrying a letter to a house that isn't there anymore.",
			"I'll knock anyway. It seems rude not to.",
			"...Stew first, though.",
		],
	},
	{
		"kind": "mole",
		"name": "FENN",
		"trade": "MOLE, AWAKE",
		"coat": Color8(84, 92, 74),
		"table": 7,
		"hook": 7,
		"delay": 132,
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
var ysort: Node2D
var coat_layer: Node2D
var fire_sprite: Sprite2D
var dusk: CanvasModulate
var glows: Array = []
var player: Sprite2D
var fade: ColorRect

var hud: CanvasLayer
var clock_text: PixelText
var night_text: PixelText
var coins_text: PixelText
var prompt_text: PixelText
var bowl_icon: Sprite2D
var fire_bar: ColorRect

var dialogue_box: Node2D
var dialogue_name: PixelText
var dialogue_line: PixelText
var dialogue_hint: PixelText

var ledger_panel: Node2D
var ledger_title: PixelText
var ledger_body: Array = []
var ledger_hint: PixelText

# ------------------------------------------------------------------ runtime --

var _time_accum: float = 0.0
var _walk_t: float = 0.0
var _fire_t: float = 0.0
var _anim_t: float = 0.0
var _facing: int = 0
var _interact_held: bool = false
var _dialogue_open: bool = false
var _dialogue_guest: Dictionary = {}
var _obstacles: Array = []
var _table_bowls: Array = []


# =============================================================== boot ======

func _ready() -> void:
	_build_world()
	_build_hud()
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

	coat_layer = Node2D.new()
	coat_layer.z_index = -5
	world.add_child(coat_layer)

	ysort = Node2D.new()
	ysort.y_sort_enabled = true
	world.add_child(ysort)

	fire_sprite = Sprite2D.new()
	fire_sprite.texture = Art.fire_frames()[0]
	fire_sprite.centered = false
	fire_sprite.offset = Vector2(-8.0, -16.0)
	fire_sprite.position = Vector2(25.0, 54.0)
	fire_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fire_sprite.z_index = -3
	world.add_child(fire_sprite)

	# furniture, all of it sorted with the characters so you can walk behind it
	var counter: Sprite2D = _add_prop(Art.make_counter(), Vector2(46.0, 146.0))
	counter.name = "Counter"
	_add_prop(Art.make_barrel(), Vector2(78.0, 72.0))
	_add_prop(Art.make_crate(), Vector2(78.0, 94.0))
	_add_prop(Art.make_plant(), Vector2(258.0, 64.0))
	_add_prop(Art.make_cat(), Vector2(56.0, 68.0))

	for i in range(TABLES.size()):
		var p: Vector2 = TABLES[i]
		_add_prop(Art.make_table(), p)
		_add_prop(Art.make_stool(), p + Vector2(0.0, 2.0))
		_obstacles.append(Rect2(p.x - 11.0, p.y - 9.0, 22.0, 11.0))
		_obstacles.append(Rect2(p.x + 5.0, p.y + 4.0, 10.0, 8.0))

	# a candle on a few tables, not all of them
	for t in [0, 4, 8]:
		var tp: Vector2 = TABLES[t]
		_add_prop(Art.make_candle(), tp + Vector2(0.0, -6.0))

	_obstacles.append(Rect2(16.0, 118.0, 60.0, 28.0))
	_obstacles.append(Rect2(70.0, 62.0, 16.0, 10.0))
	_obstacles.append(Rect2(70.0, 84.0, 16.0, 10.0))
	_obstacles.append(Rect2(251.0, 54.0, 14.0, 10.0))

	player = _make_actor("player", player_pos)

	dusk = CanvasModulate.new()
	dusk.color = Color(1.0, 0.98, 0.94, 1.0)
	world.add_child(dusk)

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
		world.add_child(g)
		glows.append({"node": g, "base": float(s[2]), "hearth": s[0].x < 40.0})

	var air: Node2D = Atmosphere.new()
	air.z_index = 6
	world.add_child(air)


func _add_prop(tex: Texture2D, pos: Vector2) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.offset = Vector2(-float(tex.get_width()) / 2.0, -float(tex.get_height()))
	s.position = pos
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ysort.add_child(s)
	return s


func _make_actor(kind: String, pos: Vector2) -> Sprite2D:
	var s: Sprite2D = Sprite2D.new()
	s.texture = Art.char_tex(kind, 0, 0)
	s.centered = false
	s.offset = Vector2(-6.0, -16.0)
	s.position = pos
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.set_meta("kind", kind)
	ysort.add_child(s)
	return s


func _face_actor(s: Sprite2D, dir: int, frame: int) -> void:
	var kind: String = str(s.get_meta("kind"))
	if kind == "":
		return
	s.texture = Art.char_tex(kind, dir, frame)


# ================================================================ HUD ======

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

	bowl_icon = Sprite2D.new()
	bowl_icon.texture = Art.make_bowl()
	bowl_icon.centered = false
	bowl_icon.position = Vector2(302.0, 167.0)
	bowl_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bowl_icon.visible = false
	hud.add_child(bowl_icon)

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


# ============================================================== the night ==

func _start_night() -> void:
	clock_min = START_MIN
	_time_accum = 0.0
	hands = 0
	stew_left = STEW_PER_NIGHT
	guests_served = 0
	coins_earned = 0
	night_over = false
	toast = ""
	toast_t = 0.0
	fire = 0.75
	_facing = 0
	player_pos = Vector2(64.0, 100.0)

	_dialogue_open = false
	_dialogue_guest = {}
	dialogue_box.visible = false
	ledger_panel.visible = false

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
			"path": [],
			"dir": 0,
			"arrive": START_MIN + int(data["delay"]),
		})

	_update_hud()
	_update_dusk()


func _clear_guests() -> void:
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
	fire = maxf(0.0, fire - delta * 0.010)
	_update_glow()

	if night_over:
		return

	_time_accum += delta * MIN_PER_SEC
	while _time_accum >= 1.0:
		_time_accum -= 1.0
		clock_min += 1
		pass

	if toast_t > 0.0:
		toast_t = maxf(0.0, toast_t - delta)

	_update_guests(delta)
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
	bowl_icon.visible = hands > 0
	fire_bar.size = Vector2(maxf(1.0, 42.0 * fire), 4.0)
	fire_bar.color = Art.AMBER.lerp(Art.RUST, clampf(1.0 - fire, 0.0, 1.0))

	if toast_t > 0.0:
		prompt_text.set_text(toast)
		return
	if night_over or _dialogue_open:
		prompt_text.set_text("")
		return

	var g: Dictionary = _nearest_guest()
	if not g.is_empty():
		var st: int = int(g["state"])
		if st == GState.SITTING:
			if hands > 0:
				prompt_text.set_text("E    SERVE THE STEW")
			else:
				prompt_text.set_text("THEY ARE WAITING ON A BOWL")
			return
		if st == GState.TALKING:
			prompt_text.set_text("E    LISTEN")
			return

	if _near(counter_pos, 30.0):
		if hands > 0:
			prompt_text.set_text("CARRY IT TO A TABLE")
		elif stew_left > 0:
			prompt_text.set_text("E    TAKE A BOWL OF STEW")
		else:
			prompt_text.set_text("THE POT IS EMPTY")
		return

	if _near(hearth_pos, 26.0):
		if fire < 0.85:
			prompt_text.set_text("E    FEED THE FIRE")
		else:
			prompt_text.set_text("THE FIRE IS HOLDING")
		return

	prompt_text.set_text("")


# =============================================================== guests ====

func _update_guests(delta: float) -> void:
	for g in guests:
		match int(g["state"]):
			GState.AWAY:
				if clock_min >= int(g["arrive"]):
					_spawn_guest(g)
			GState.INBOUND:
				if _walk_guest(g, delta):
					g["state"] = GState.SITTING
					g["patience"] = 260.0
					g["dir"] = 1
					_face_actor(g["sprite"], 1, 0)
					_toast("A COAT ON THE RACK")
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
					if g["sprite"] != null and is_instance_valid(g["sprite"]):
						var s: Sprite2D = g["sprite"]
						s.queue_free()
					g["sprite"] = null


func _spawn_guest(g: Dictionary) -> void:
	var data: Dictionary = GUEST_DATA[int(g["index"])]
	var sprite: Sprite2D = _make_actor(str(data["kind"]), door_pos + Vector2(0.0, -8.0))
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
		_face_actor(sprite, d, int(_anim_t * 8.0) % 2)
	return path.is_empty()


func _seat_position(table_index: int) -> Vector2:
	var p: Vector2 = TABLES[table_index]
	return p + SEAT_OFFSET


func _add_coat(g: Dictionary) -> void:
	var data: Dictionary = GUEST_DATA[int(g["index"])]
	var hook: int = int(data["hook"])
	var coat: Sprite2D = Sprite2D.new()
	coat.texture = Art.make_coat(data["coat"])
	coat.centered = false
	coat.offset = Vector2(-5.0, 0.0)
	coat.position = Vector2(float(Art.RACK_X + 5 + hook * 10), float(Art.RACK_Y + 4))
	coat.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	coat_layer.add_child(coat)
	g["coat"] = coat


func _drop_coat(g: Dictionary) -> void:
	if g["coat"] != null and is_instance_valid(g["coat"]):
		var c: Sprite2D = g["coat"]
		c.queue_free()
	g["coat"] = null


func _leave(g: Dictionary) -> void:
	g["state"] = GState.OUTBOUND
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
		_face_actor(player, _facing, 0)
		return

	dir = dir.normalized()
	_facing = _dir_from_vec(dir)
	_walk_t += delta * 7.0
	_move_player(dir * PLAYER_SPEED * delta)
	_face_actor(player, _facing, int(_walk_t) % 2)


func _move_player(delta: Vector2) -> void:
	var nx: float = clampf(player_pos.x + delta.x, 10.0, 310.0)
	if _free(Vector2(nx, player_pos.y)):
		player_pos.x = nx
	var ny: float = clampf(player_pos.y + delta.y, 62.0, 146.0)
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

	var g: Dictionary = _nearest_guest()
	if not g.is_empty():
		var st: int = int(g["state"])
		if st == GState.SITTING:
			if hands > 0:
				_serve(g)
			else:
				_toast("THEY ARE IN NO RUSH")
		elif st == GState.TALKING:
			_open_dialogue(g)
		return

	if _near(counter_pos, 30.0):
		if hands == 0 and stew_left > 0:
			hands = 1
			stew_left -= 1
			_toast("WARM THROUGH THE BOWL")
		return

	if _near(hearth_pos, 26.0):
		if fire < 0.98:
			fire = minf(1.0, fire + 0.45)
			_toast("THE FIRE TAKES IT")
		return


func _serve(g: Dictionary) -> void:
	hands = 0
	coins += STEW_PRICE
	coins_earned += STEW_PRICE
	served_total += 1
	guests_served += 1
	g["state"] = GState.EATING
	g["timer"] = 13.0
	var seat: Vector2 = _seat_position(int(GUEST_DATA[int(g["index"])]["table"]))
	var bowl: Sprite2D = Sprite2D.new()
	bowl.texture = Art.make_bowl()
	bowl.centered = false
	bowl.offset = Vector2(-4.0, -6.0)
	bowl.position = seat + Vector2(0.0, -2.0)
	bowl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ysort.add_child(bowl)
	_table_bowls.append(bowl)
	_toast("THEY NOD AND EAT")


func _toast(msg: String) -> void:
	toast = msg
	toast_t = 2.4


# ============================================================== dialogue ==

func _open_dialogue(g: Dictionary) -> void:
	_dialogue_open = true
	_dialogue_guest = g
	g["line_i"] = 0
	dialogue_box.visible = true
	_show_dialogue_line()


func _show_dialogue_line() -> void:
	var data: Dictionary = GUEST_DATA[int(_dialogue_guest["index"])]
	var lines: Array = data["lines"]
	var i: int = int(_dialogue_guest["line_i"])
	dialogue_name.set_text("%s   %s" % [str(data["name"]), str(data["trade"])])
	if i >= 0 and i < lines.size():
		dialogue_line.set_text(str(lines[i]))
	dialogue_hint.set_text("E    ...")


func _advance_dialogue() -> void:
	if _dialogue_guest.is_empty():
		_close_dialogue()
		return
	var data: Dictionary = GUEST_DATA[int(_dialogue_guest["index"])]
	var lines: Array = data["lines"]
	var i: int = int(_dialogue_guest["line_i"]) + 1
	_dialogue_guest["line_i"] = i
	if i >= lines.size():
		var g: Dictionary = _dialogue_guest
		_close_dialogue()
		_leave(g)
		return
	_show_dialogue_line()


func _close_dialogue() -> void:
	_dialogue_open = false
	_dialogue_guest = {}
	dialogue_box.visible = false


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
			line = "Nobody came up the pass. The stew stayed warm and the rain kept on."
		1:
			line = "One coat on the rack, and the fire had the room to itself."
		2:
			line = "Two travellers, and the long hours between them."
		_:
			line = "Three coats on the rack. The fire held until the last of them went up."
	line += "  %d coins in the tin." % coins_earned
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
