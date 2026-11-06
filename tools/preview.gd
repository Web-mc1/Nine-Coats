extends SceneTree

# There is no display in the build environment, so this renders the room by
# compositing the game's own images by hand. It is not a screenshot of the
# running game, but every pixel in it comes from the same art code the game
# uses at runtime.

const Art = preload("res://scripts/Art.gd")

var TABLES: Array = [
	Vector2(104.0, 80.0), Vector2(168.0, 80.0), Vector2(232.0, 80.0),
	Vector2(104.0, 106.0), Vector2(168.0, 106.0), Vector2(232.0, 106.0),
	Vector2(104.0, 130.0), Vector2(168.0, 130.0), Vector2(232.0, 130.0),
]


func _initialize() -> void:
	var base: Image = _compose_world()

	var clean: Image = base.duplicate()
	_draw_hud(clean, "19:12", 2, 14, 0.62)
	_text(clean, "E    SERVE THE STEW", Vector2i(160 - Art.text_width("E    SERVE THE STEW") / 2, 168), Art.CREAM)
	_save(clean, "res://preview.png")
	var big: Image = clean.duplicate()
	big.resize(640, 360, Image.INTERPOLATE_NEAREST)
	_save(big, "res://preview_2x.png")

	var talk: Image = base.duplicate()
	_draw_hud(talk, "19:12", 2, 14, 0.62)
	_draw_dialogue(talk)
	_save(talk, "res://preview_dialogue.png")

	print("wrote preview.png and preview_dialogue.png")
	quit()


func _compose_world() -> Image:
	var img: Image = Art.room_image().duplicate()
	# furniture, drawn in y order the way the game sorts it
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
		_blit_base(img, Art.make_table(), t)
		_blit_base(img, Art.make_stool(), t + Vector2(0.0, 2.0))
	for c in [0, 4, 8]:
		_blit_base(img, Art.make_candle(), TABLES[c] + Vector2(0.0, -6.0))
	_blit_base(img, Art.make_counter(), Vector2(46.0, 146.0))

	# the fire
	_blit_at(img, Art.fire_frames()[1].get_image(), Vector2i(25 - 8, 54 - 16))

	# characters: the innkeeper, and three guests at their tables
	_blit_char(img, "player", 0, 0, Vector2(86.0, 120.0))
	_blit_char(img, "badger", 1, 0, TABLES[0] + Vector2(0.0, 15.0))
	_blit_char(img, "heron", 1, 0, TABLES[4] + Vector2(0.0, 15.0))
	_blit_char(img, "mole", 1, 0, TABLES[7] + Vector2(0.0, 15.0))

	# bowls on the served tables
	_blit_base(img, Art.make_bowl(), TABLES[0] + Vector2(0.0, 13.0))
	_blit_base(img, Art.make_bowl(), TABLES[4] + Vector2(0.0, 13.0))

	# coats on the rack
	var coats: Array = [
		[Color8(112, 96, 78), 1],
		[Color8(92, 108, 132), 4],
		[Color8(84, 92, 74), 7],
	]
	for c in coats:
		_blit_at(img, Art.make_coat(c[0]).get_image(), Vector2i(Art.RACK_X + 5 + int(c[1]) * 10 - 5, Art.RACK_Y + 4))

	_tint(img, Color(0.85, 0.85, 0.89, 1.0))
	return img


func _draw_hud(img: Image, clock: String, night: int, coins: int, fire: float) -> void:
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
	_blit_at(img, Art.make_bowl().get_image(), Vector2i(302, 167))
	_text(img, "", Vector2i(0, 0), Art.AMBER_D)


func _draw_dialogue(img: Image) -> void:
	_blit_at(img, Art.make_panel(300, 42, Color(0.11, 0.09, 0.11, 0.96), Art.AMBER_D).get_image(), Vector2i(10, 104))
	_text(img, "BRAMBLE   BADGER, CARTOGRAPHER", Vector2i(18, 109), Art.AMBER)
	_text(img, "I keep redrawing it. It ends in the same place.", Vector2i(18, 120), Art.CREAM)
	_text(img, "E    ...", Vector2i(18, 133), Art.AMBER_D)


func _blit_base(img: Image, tex: Texture2D, pos: Vector2) -> void:
	var src: Image = tex.get_image()
	if src.get_format() != Image.FORMAT_RGBA8:
		src.convert(Image.FORMAT_RGBA8)
	var at: Vector2i = Vector2i(int(pos.x) - src.get_width() / 2, int(pos.y) - src.get_height())
	_blit_at(img, src, at)


func _blit_char(img: Image, kind: String, dir: int, frame: int, pos: Vector2) -> void:
	var src: Image = Art.char_tex(kind, dir, frame).get_image()
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
				var px: int = at.x + i * 6 + x
				var py: int = at.y + y
				if px < 0 or py < 0 or px >= img.get_width() or py >= img.get_height():
					continue
				img.set_pixel(px, py, col)


func _save(img: Image, path: String) -> void:
	var err: int = img.save_png(path)
	if err != OK:
		print("could not save ", path, " err=", err)
