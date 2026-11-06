extends SceneTree

# There is no display in the build environment, so this renders the rooms by
# compositing the game's own images by hand. It is not a screenshot of the
# running game, but every pixel in it comes from the same art code the game
# uses at runtime.

const Art = preload("res://scripts/Art.gd")
const Recipes = preload("res://scripts/Recipes.gd")

var TABLES: Array = [
	Vector2(96.0, 76.0), Vector2(160.0, 76.0), Vector2(224.0, 76.0),
	Vector2(128.0, 106.0), Vector2(192.0, 106.0), Vector2(256.0, 106.0),
	Vector2(96.0, 134.0), Vector2(160.0, 134.0), Vector2(224.0, 134.0),
]

var SEAT_OFFSET := Vector2(0.0, 15.0)


func _initialize() -> void:
	var base: Image = _compose_taproom()

	var clean: Image = base.duplicate()
	_draw_hud(clean, "19:12", 2, 14, 0.62)
	_prompt(clean, "E    SERVE THE MUSHROOM POTAGE")
	_save(clean, "res://preview.png")
	_save(_twice(clean), "res://preview_2x.png")

	var talk: Image = base.duplicate()
	_draw_hud(talk, "19:12", 2, 14, 0.62)
	_draw_dialogue(talk)
	_save(talk, "res://preview_dialogue.png")

	var kitchen: Image = _compose_kitchen()
	_draw_hud_on(kitchen, "19:40", 2, 14, 0.62)
	_prompt(kitchen, "E    ADD THE THYME")
	_save(kitchen, "res://preview_kitchen.png")
	_save(_twice(kitchen), "res://preview_kitchen_2x.png")

	print("wrote the preview images")
	quit()


func _compose_taproom() -> Image:
	var img: Image = Art.room_image().duplicate()
	var props: Array = [
		[Art.make_plant(), Vector2(258.0, 64.0)],
		[Art.make_cat(), Vector2(56.0, 68.0)],
		[Art.make_barrel(), Vector2(78.0, 72.0)],
		[Art.make_crate(), Vector2(78.0, 94.0)],
	]
	for p in props:
		_blit_base(img, p[0], p[1])

	for i in range(TABLES.size()):
		var t: Vector2 = TABLES[i]
		_blit_base(img, Art.make_chair(), t + SEAT_OFFSET)
		_blit_base(img, Art.make_table(), t)

	for c in [0, 4, 8]:
		_blit_base(img, Art.make_candle(), TABLES[c] + Vector2(0.0, -6.0))
	_blit_base(img, Art.make_counter(), Vector2(46.0, 146.0))

	# the fire
	_blit_at(img, Art.fire_frames()[1].get_image(), Vector2i(25 - 8, 54 - 16))

	# the guests, sitting on their chairs, two of them eating
	_blit_sit(img, "badger", 0, TABLES[0] + SEAT_OFFSET)
	_blit_sit(img, "heron", 2, TABLES[3] + SEAT_OFFSET)
	_blit_sit(img, "mole", 0, TABLES[5] + SEAT_OFFSET)
	_blit_base(img, Art.make_plate(Recipes.dish_col(0)), TABLES[0] + Vector2(0.0, -7.0))
	_blit_base(img, Art.make_plate(Recipes.dish_col(5)), TABLES[3] + Vector2(0.0, -7.0))

	# the innkeeper, behind the counter
	_blit_char(img, "player", 0, 0, Vector2(86.0, 120.0))

	# the order bubbles, above everyone
	_blit_center(img, Art.make_order_bubble(Recipes.dish_col(0)), TABLES[0] + SEAT_OFFSET + Vector2(0.0, -26.0))
	_blit_center(img, Art.make_order_bubble(Recipes.dish_col(5)), TABLES[5] + SEAT_OFFSET + Vector2(0.0, -26.0))

	# three coats on the rack
	var coats: Array = [
		[Color8(112, 96, 78), 1],
		[Color8(92, 108, 132), 4],
		[Color8(84, 92, 74), 7],
	]
	for c in coats:
		_blit_at(img, Art.make_coat(c[0]).get_image(), Vector2i(Art.RACK_X + 5 + int(c[1]) * 10 - 5, Art.RACK_Y + 4))

	_tint(img, Color(0.85, 0.85, 0.89, 1.0))
	return img


func _compose_kitchen() -> Image:
	var img: Image = Art.kitchen_image().duplicate()
	_blit_base(img, Art.make_barrel(), Vector2(60.0, 120.0))
	_blit_base(img, Art.make_crate(), Vector2(236.0, 118.0))
	# something bubbling away in the pot
	_blit_center(img, Art.make_pot_fill(Recipes.dish_col(3)), Vector2(253.0, 22.0))
	_blit_center(img, Art.bubbles()[1], Vector2(253.0, 12.0))
	# the innkeeper, thinking about what to cook
	_blit_char(img, "player", 1, 0, Vector2(200.0, 104.0))
	_tint(img, Color(0.85, 0.85, 0.89, 1.0))
	return img


func _twice(img: Image) -> Image:
	var big: Image = img.duplicate()
	big.resize(640, 360, Image.INTERPOLATE_NEAREST)
	return big


func _draw_hud(img: Image, clock: String, night: int, coins: int, fire: float) -> void:
	_draw_hud_on(img, clock, night, coins, fire)


func _draw_hud_on(img: Image, clock: String, night: int, coins: int, fire: float) -> void:
	_blit_at(img, Art.make_panel(320, 28, Color(0.10, 0.086, 0.112, 0.95), Art.AMBER_D).get_image(), Vector2i(0, 152))
	_text(img, clock, Vector2i(6, 157), Art.CREAM)
	_text(img, "NIGHT %d" % night, Vector2i(46, 157), Art.AMBER_D)
	_text(img, "FIRE", Vector2i(196, 157), Art.AMBER_D)
	for y in range(4):
		for x in range(42):
			img.set_pixel(222 + x, 159 + y, Color(0.22, 0.16, 0.14, 1.0))
	var fill: int = int(42.0 * fire)
	for y in range(4):
		for x in range(fill):
			img.set_pixel(222 + x, 159 + y, Art.AMBER)
	var label: String = "COINS %d" % coins
	_text(img, label, Vector2i(314 - Art.text_width(label), 157), Art.AMBER)
	_blit_at(img, Art.make_plate(Recipes.dish_col(0)).get_image(), Vector2i(298, 164))


func _prompt(img: Image, s: String) -> void:
	_text(img, s, Vector2i(160 - Art.text_width(s) / 2, 168), Art.CREAM)


func _draw_dialogue(img: Image) -> void:
	_blit_at(img, Art.make_panel(300, 42, Color(0.11, 0.09, 0.11, 0.96), Art.AMBER_D).get_image(), Vector2i(10, 104))
	_text(img, "BRAMBLE   BADGER, CARTOGRAPHER", Vector2i(18, 109), Art.AMBER)
	_text(img, "I WAS HOPING FOR THE MUSHROOM POTAGE.", Vector2i(18, 120), Art.CREAM)
	_text(img, "E    ...", Vector2i(18, 133), Art.AMBER_D)


func _blit_base(img: Image, tex: Texture2D, pos: Vector2) -> void:
	var src: Image = tex.get_image()
	if src.get_format() != Image.FORMAT_RGBA8:
		src.convert(Image.FORMAT_RGBA8)
	_blit_at(img, src, Vector2i(int(pos.x) - src.get_width() / 2, int(pos.y) - src.get_height()))


func _blit_center(img: Image, tex: Texture2D, pos: Vector2) -> void:
	var src: Image = tex.get_image()
	if src.get_format() != Image.FORMAT_RGBA8:
		src.convert(Image.FORMAT_RGBA8)
	_blit_at(img, src, Vector2i(int(pos.x) - src.get_width() / 2, int(pos.y) - src.get_height() / 2))


func _blit_char(img: Image, kind: String, dir: int, frame: int, pos: Vector2) -> void:
	var src: Image = Art.char_tex(kind, dir, frame).get_image()
	if src.get_format() != Image.FORMAT_RGBA8:
		src.convert(Image.FORMAT_RGBA8)
	_blit_at(img, src, Vector2i(int(pos.x) - 6, int(pos.y) - 16))


func _blit_sit(img: Image, kind: String, frame: int, pos: Vector2) -> void:
	var src: Image = Art.sit_tex(kind, 0, frame).get_image()
	if src.get_format() != Image.FORMAT_RGBA8:
		src.convert(Image.FORMAT_RGBA8)
	_blit_at(img, src, Vector2i(int(pos.x) - 6, int(pos.y) - 16))


func _blit_at(img: Image, src: Image, at: Vector2i) -> void:
	if src.get_format() != Image.FORMAT_RGBA8:
		src.convert(Image.FORMAT_RGBA8)
	img.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), at)


func _tint(img: Image, c: Color) -> void:
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var p: Color = img.get_pixel(x, y)
			img.set_pixel(x, y, Color(p.r * c.r, p.g * c.g, p.b * c.b, p.a))


func _text(img: Image, s: String, at: Vector2i, col: Color) -> void:
	var atlas: Image = Art.font_atlas().get_image()
	if atlas.get_format() != Image.FORMAT_RGBA8:
		atlas.convert(Image.FORMAT_RGBA8)
	for i in range(s.length()):
		var cell: Vector2i = Art.glyph_cell(s[i])
		if cell.x < 0:
			continue
		for y in range(7):
			for x in range(5):
				var a: float = atlas.get_pixel(cell.x + x, cell.y + y).a
				if a <= 0.5:
					continue
				img.set_pixel(at.x + i * 6 + x, at.y + y, col)


func _save(img: Image, path: String) -> void:
	var err: int = img.save_png(path)
	if err != OK:
		print("could not save ", path, " err=", err)
