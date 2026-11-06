extends RefCounted

# Nine Coats -- all of the art, generated in code.
#
# Every pixel in this game comes from this file: the room, the furniture, the
# animals, the fire, and a hand-built 5x7 bitmap font. Nothing is loaded from
# disk, which keeps the slice tiny and lets real art drop in later by swapping
# a single function.

# ---------------------------------------------------------------- geometry --

const W := 320
const H := 180
const WALL_H := 56
const HUD_Y := 152

const WIN_X := 74
const WIN_Y := 14
const WIN_W := 66
const WIN_H := 32

const HEARTH_X := 6
const HEARTH_Y := 12
const HEARTH_W := 38
const HEARTH_H := 44

const DOOR_X := 274
const DOOR_Y := 16
const DOOR_W := 30
const DOOR_H := 40

const RACK_X := 176
const RACK_Y := 24
const RACK_W := 94
const RACK_H := 32

const LANTERN_XS := [58, 160]

# ------------------------------------------------------------------ palette --
# Slate and wet stone outside, one warm amber pool inside. The whole game is
# the contrast between those two ends of the palette.

const INK := Color8(24, 20, 28)
const NIGHT := Color8(40, 42, 60)
const STONE_D := Color8(58, 64, 78)
const STONE := Color8(80, 86, 100)
const STONE_L := Color8(102, 108, 122)
const MORTAR := Color8(44, 50, 62)
const PLANK_D := Color8(104, 68, 46)
const PLANK := Color8(134, 90, 60)
const PLANK_L := Color8(160, 112, 76)
const WOOD_D := Color8(78, 50, 38)
const WOOD := Color8(126, 84, 58)
const WOOD_L := Color8(166, 120, 82)
const AMBER_D := Color8(198, 116, 46)
const AMBER := Color8(240, 166, 74)
const AMBER_L := Color8(254, 216, 146)
const CREAM := Color8(248, 230, 196)
const RUST := Color8(146, 66, 58)
const RUST_D := Color8(100, 46, 48)
const SAGE := Color8(112, 132, 98)
const SAGE_D := Color8(76, 94, 74)
const SLATE := Color8(104, 122, 142)
const SLATE_D := Color8(66, 80, 100)
const FOG := Color8(158, 172, 186)
const CATFUR := Color8(216, 146, 70)
const PINK := Color8(214, 132, 116)
const GLASS := Color8(46, 58, 78)
const GLASS_L := Color8(70, 86, 110)
const IRON := Color8(52, 50, 62)

# ------------------------------------------------------------------ helpers --

static var _seed: int = 7717
static var _room_tex: Texture2D = null
static var _room_img: Image = null
static var _kitchen_tex: Texture2D = null
static var _kitchen_img: Image = null
static var _ing_icon_cache: Array = []
static var _bubble_cache: Array = []
static var _village_img: Image = null
static var _village_tex: Texture2D = null
static var _char_cache: Dictionary = {}
static var _font_tex: Texture2D = null
static var _glyph_index: Dictionary = {}
static var _fire_cache: Array = []


static func _reset(value: int) -> void:
	_seed = value


static func _rnd(n: int) -> int:
	if n <= 0:
		return 0
	_seed = (_seed * 1103515245 + 12345) & 0x7fffffff
	return _seed % n


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, c)


static func _mix(img: Image, x: int, y: int, c: Color, t: float) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	if t <= 0.0:
		return
	var base: Color = img.get_pixel(x, y)
	img.set_pixel(x, y, base.lerp(c, clampf(t, 0.0, 1.0)))


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(img, xx, yy, c)


static func _hline(img: Image, x: int, y: int, w: int, c: Color) -> void:
	for xx in range(x, x + w):
		_px(img, xx, y, c)


static func _vline(img: Image, x: int, y: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		_px(img, x, yy, c)


static func _frame(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	_hline(img, x, y, w, c)
	_hline(img, x, y + h - 1, w, c)
	_vline(img, x, y, h, c)
	_vline(img, x + w - 1, y, h, c)


static func _ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color, t: float) -> void:
	for y in range(int(cy - ry), int(cy + ry) + 1):
		for x in range(int(cx - rx), int(cx + rx) + 1):
			var dx: float = (x - cx) / rx
			var dy: float = (y - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				_mix(img, x, y, c, t)


static func _outline(img: Image, c: Color) -> void:
	var copy: Image = img.duplicate()
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			if copy.get_pixel(x, y).a > 0.05:
				continue
			var touching: bool = false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx < 0 or ny < 0 or nx >= img.get_width() or ny >= img.get_height():
					continue
				if copy.get_pixel(nx, ny).a > 0.05:
					touching = true
					break
			if touching:
				img.set_pixel(x, y, c)


# --------------------------------------------------------------- the room ---

static func room_image() -> Image:
	if _room_img != null:
		return _room_img
	_reset(7717)
	var img: Image = Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(INK)
	_draw_wall(img)
	_draw_floor(img)
	_draw_rug(img)
	_draw_beam(img)
	_draw_window(img)
	_draw_hearth(img)
	_draw_door(img)
	_draw_rack(img)
	_draw_herbs(img)
	_draw_wall_art(img)
	_draw_passage(img, 0, true)
	_warm_grade(img)
	_room_img = img
	return _room_img


static func make_room() -> Texture2D:
	if _room_tex == null:
		_room_tex = ImageTexture.create_from_image(room_image())
	return _room_tex


static func _draw_wall(img: Image) -> void:
	for y in range(0, WALL_H - 6):
		var course: int = y / 7
		var shift: int = (course % 2) * 8
		for x in range(0, W):
			var bx: int = (x + shift) / 16
			var mortar: bool = ((x + shift) % 16) == 0 or (y % 7) == 0
			var col: Color
			if mortar:
				col = MORTAR
			else:
				var h: int = (bx * 37 + course * 13) % 6
				match h:
					0:
						col = STONE_D
					1:
						col = STONE_D.lerp(STONE, 0.5)
					2:
						col = STONE
					3:
						col = STONE_L.lerp(STONE, 0.35)
					_:
						col = STONE_D.darkened(0.08)
			_px(img, x, y, col)
	# baseboard: a warm line where the stone meets the boards
	_rect(img, 0, WALL_H - 6, W, 6, WOOD_D)
	_hline(img, 0, WALL_H - 6, W, WOOD)
	_hline(img, 0, WALL_H - 1, W, INK)


static func _draw_floor(img: Image) -> void:
	var top: int = WALL_H
	for y in range(top, H):
		var row: int = (y - top) / 9
		var base: Color
		match row % 3:
			0:
				base = PLANK
			1:
				base = PLANK_L.darkened(0.10)
			_:
				base = PLANK_D
		for x in range(0, W):
			var col: Color = base
			if (y - top) % 9 == 0:
				col = WOOD_D.darkened(0.18)
			elif ((x + row * 37) % 83) == 0:
				col = WOOD_D.darkened(0.12)
			elif ((x * 11 + y * 7) % 59) == 0:
				col = base.darkened(0.06)
			_px(img, x, y, col)
	# shadow where the wall meets the floor
	for x in range(0, W):
		for dy in range(0, 5):
			_mix(img, x, top + dy, INK, 0.30 - dy * 0.06)


static func _draw_rug(img: Image) -> void:
	var cx := 176.0
	var cy := 106.0
	# a warm rust rug, so the boards have somewhere soft to sit
	_ellipse(img, cx, cy, 90.0, 40.0, RUST_D, 0.86)
	_ellipse(img, cx, cy, 86.0, 37.0, RUST, 0.50)
	for i in range(3):
		var rx: float = 30.0 + i * 22.0
		var ry: float = 13.0 + i * 10.0
		for a in range(0, 360, 2):
			var rad: float = deg_to_rad(float(a))
			_px(img, int(cx + cos(rad) * rx), int(cy + sin(rad) * ry), RUST_D.darkened(0.18))
	# a cream border band
	for a in range(0, 360, 1):
		var rad: float = deg_to_rad(float(a))
		_px(img, int(cx + cos(rad) * 82.0), int(cy + sin(rad) * 34.0), CREAM.lerp(RUST_D, 0.6))
	# worn through in the middle
	_ellipse(img, cx, cy + 3.0, 24.0, 10.0, PLANK, 0.18)


static func _draw_beam(img: Image, lanterns: Array = LANTERN_XS) -> void:
	_rect(img, 0, 0, W, 3, INK)
	_rect(img, 0, 3, W, 7, WOOD)
	_hline(img, 0, 3, W, WOOD_L)
	_hline(img, 0, 7, W, WOOD_D)
	_hline(img, 0, 9, W, INK)
	# the beam lays a soft shadow down the stone
	for x in range(0, W):
		for dy in range(0, 4):
			_mix(img, x, 10 + dy, INK, 0.26 - dy * 0.06)
	# a few bolt heads
	for x in range(18, W, 46):
		_px(img, x, 5, WOOD_D)
		_px(img, x + 1, 5, WOOD_L)
	# lantern chains and lanterns
	for lx in lanterns:
		var x: int = lx
		_vline(img, x, 10, 8, IRON)
		_px(img, x - 1, 18, IRON)
		_px(img, x + 1, 18, IRON)
		# lantern body
		_rect(img, x - 4, 18, 9, 2, IRON)
		_rect(img, x - 5, 20, 11, 9, WOOD_D)
		_rect(img, x - 4, 21, 9, 7, AMBER)
		_rect(img, x - 3, 22, 7, 5, AMBER_L)
		_rect(img, x - 1, 23, 3, 3, CREAM)
		_vline(img, x - 4, 21, 7, WOOD_D)
		_vline(img, x + 4, 21, 7, WOOD_D)
		_rect(img, x - 4, 29, 9, 2, IRON)


static func _draw_window(img: Image) -> void:
	var x: int = WIN_X
	var y: int = WIN_Y
	var w: int = WIN_W
	var h: int = WIN_H
	# the night outside
	for yy in range(h):
		var t: float = float(yy) / float(h)
		var col: Color = GLASS.lerp(NIGHT, 1.0 - t * 0.7)
		for xx in range(w):
			_px(img, x + xx, y + yy, col)
	# far pines and a hill
	for i in range(9):
		var px: int = x + 3 + i * 7
		var ph: int = 5 + _rnd(6)
		for k in range(ph):
			_hline(img, px - k / 2, y + h - 1 - k, k + 1, SLATE_D)
	_hline(img, x, y + h - 1, w, SLATE_D.darkened(0.15))
	# rain on the glass
	for i in range(30):
		var rx: int = x + 2 + _rnd(w - 4)
		var ry: int = y + 1 + _rnd(h - 4)
		var ln: int = 2 + _rnd(4)
		for k in range(ln):
			_px(img, rx + k / 3, ry + k, GLASS_L)
	# glass condensation
	for i in range(20):
		_px(img, x + _rnd(w), y + _rnd(h), GLASS_L.lerp(FOG, 0.35))
	# frame
	_frame(img, x - 3, y - 3, w + 6, h + 6, WOOD_D)
	_frame(img, x - 2, y - 2, w + 4, h + 4, WOOD)
	_vline(img, x + w / 2, y, h, WOOD_D)
	_hline(img, x, y + h / 2, w, WOOD_D)
	# sill
	_rect(img, x - 6, y + h + 3, w + 12, 4, WOOD_L)
	_hline(img, x - 6, y + h + 6, w + 12, WOOD_D)
	# two cups and a candle on the sill
	_rect(img, x + 2, y + h, 4, 3, CREAM)
	_rect(img, x + 9, y + h, 4, 3, CREAM)
	_rect(img, x + 9, y + h + 1, 4, 1, PINK)
	_vline(img, x + 46, y + h, 3, CREAM)
	_px(img, x + 46, y + h - 1, AMBER_L)
	# curtains, tied back at the middle
	_draw_curtain(img, x - 14, y - 10, 14, h + 22)
	_draw_curtain(img, x + w + 1, y - 10, 14, h + 22)


static func _draw_curtain(img: Image, x: int, y: int, w: int, h: int) -> void:
	for yy in range(h):
		var t: float = float(yy) / float(h)
		var pinch: float = 1.0 - 0.45 * sin(t * PI)
		var ww: int = int(round(float(w) * pinch))
		for xx in range(ww):
			var fold: int = (xx + yy / 4) % 5
			var col: Color = RUST if fold < 3 else RUST_D
			if yy == h - 1:
				col = RUST_D
			_px(img, x + xx, y + yy, col)
	# tie band
	var band_y: int = y + h / 2
	for xx in range(w):
		_px(img, x + xx, band_y, RUST_D.darkened(0.15))
		_px(img, x + xx, band_y + 1, AMBER_D)
	# rod
	_hline(img, x - 1, y - 2, w + 2, WOOD_L)


static func _draw_hearth(img: Image) -> void:
	var x: int = HEARTH_X
	var y: int = HEARTH_Y
	var w: int = HEARTH_W
	var h: int = HEARTH_H
	# stone surround
	_rect(img, x, y, w, h, STONE_D)
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if ((xx - x) % 9) == 0 or ((yy - y) % 9) == 0:
				_px(img, xx, yy, MORTAR)
	# stone courses, with a little variation
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if ((xx - x) * 7 + (yy - y) * 3) % 19 == 0:
				_px(img, xx, yy, STONE)
	# mantle shelf
	_rect(img, x - 3, y + 6, w + 6, 4, WOOD)
	_hline(img, x - 3, y + 6, w + 6, WOOD_L)
	_hline(img, x - 3, y + 9, w + 6, WOOD_D)
	# the opening, low in the wall so the fire is at floor level
	_rect(img, x + 6, y + 20, w - 12, h - 20, INK)
	_rect(img, x + 7, y + 21, w - 14, h - 22, IRON)
	_hline(img, x + 5, y + 19, w - 10, STONE_L)
	_hline(img, x + 5, y + 20, w - 10, MORTAR)
	# soot and glow inside
	_ellipse(img, float(x + w / 2), float(y + h - 8), 10.0, 7.0, AMBER_D, 0.45)
	# grate bars
	for i in range(4):
		_vline(img, x + 10 + i * 6, y + h - 12, 11, IRON.darkened(0.25))
	_hline(img, x + 8, y + h - 13, w - 16, IRON)
	# logs
	_rect(img, x + 10, y + h - 7, 16, 3, WOOD_D)
	_rect(img, x + 12, y + h - 10, 13, 3, WOOD)
	_px(img, x + 15, y + h - 10, AMBER_D)
	_px(img, x + 21, y + h - 9, AMBER_D)
	# a candle and a pot on the mantle
	_rect(img, x + 5, y + 2, 3, 4, CREAM)
	_px(img, x + 6, y + 1, AMBER_L)
	_rect(img, x + 24, y + 1, 6, 5, IRON)
	_rect(img, x + 25, y, 4, 1, IRON.darkened(0.2))
	# hearth apron stones on the floor
	_rect(img, x + 2, y + h, w - 4, 4, STONE)
	_hline(img, x + 2, y + h, w - 4, STONE_L)


static func _draw_door(img: Image) -> void:
	var x: int = DOOR_X
	var y: int = DOOR_Y
	var w: int = DOOR_W
	var h: int = DOOR_H
	# frame
	_rect(img, x - 4, y - 4, w + 8, h + 5, WOOD_D)
	_frame(img, x - 4, y - 4, w + 8, h + 5, WOOD)
	# planks
	_rect(img, x, y, w, h, WOOD)
	for i in range(1, 4):
		_vline(img, x + i * 7, y, h, WOOD_D)
	_vline(img, x + 1, y + 1, h - 2, WOOD_L)
	# iron bands
	_rect(img, x, y + 8, w, 2, IRON)
	_rect(img, x, y + 30, w, 2, IRON)
	for i in range(3):
		_px(img, x + 3 + i * 10, y + 8, STONE_L)
		_px(img, x + 3 + i * 10, y + 30, STONE_L)
	# handle
	_rect(img, x + w - 6, y + 20, 2, 3, AMBER_D)
	# a crack of amber light under the door
	_rect(img, x, y + h - 2, w, 1, AMBER)
	# a mat, and the wet the road brought in
	_rect(img, x + 4, WALL_H + 5, 24, 8, WOOD_D)
	_frame(img, x + 4, WALL_H + 5, 24, 8, WOOD)
	_hline(img, x + 7, WALL_H + 8, 18, WOOD)
	_ellipse(img, float(x + 20), float(WALL_H + 20), 10.0, 4.0, SLATE_D, 0.40)
	_ellipse(img, float(x + 20), float(WALL_H + 20), 6.0, 2.0, SLATE, 0.30)
	# the wedge of warm light and fog that spills in
	for yy in range(0, 30):
		var ww: int = int(12.0 + yy * 2.4)
		var t: float = 0.26 * (1.0 - float(yy) / 30.0)
		for xx in range(ww):
			var sx: int = x + w / 2 - ww / 2 + xx
			_mix(img, sx, WALL_H + yy, AMBER_D, t)
			if yy < 6:
				_mix(img, sx, WALL_H + yy, FOG, 0.12)


static func _draw_rack(img: Image) -> void:
	var x: int = RACK_X
	var y: int = RACK_Y
	var w: int = RACK_W
	# rail on the wall
	_rect(img, x, y, w, 3, WOOD)
	_hline(img, x, y, w, WOOD_L)
	# nine pegs
	for i in range(9):
		var px: int = x + 5 + i * 10
		_rect(img, px, y + 3, 2, 3, WOOD_D)
		_px(img, px + 1, y + 6, AMBER_D)
	# a shelf under the rail with boots and a hat
	_rect(img, x, y + 22, w, 3, WOOD)
	_hline(img, x, y + 22, w, WOOD_L)
	_hline(img, x, y + 24, w, WOOD_D)
	for i in range(3):
		var bx: int = x + 10 + i * 26
		_rect(img, bx, y + 17, 6, 5, WOOD_D)
		_rect(img, bx + 1, y + 16, 4, 2, WOOD_D)
		_rect(img, bx, y + 21, 7, 1, IRON)
	# a hat on the far end
	_rect(img, x + w - 18, y + 18, 12, 4, RUST_D)
	_rect(img, x + w - 15, y + 14, 6, 4, RUST)


static func _draw_herbs(img: Image) -> void:
	for hx in [46, 172]:
		var x: int = hx
		_vline(img, x, 10, 4, WOOD_D)
		for i in range(5):
			var lx: int = x - 2 + (i % 3)
			var ly: int = 14 + i * 3
			_rect(img, lx, ly, 4, 2, SAGE)
			_px(img, lx + 1, ly, SAGE_D)
			_px(img, lx + 3, ly + 1, SAGE_D)
		_rect(img, x - 1, 14, 4, 1, RUST)


static func _draw_wall_art(img: Image) -> void:
	# a small framed picture between the hearth and the curtain
	var x: int = 46
	var y: int = 27
	_rect(img, x, y, 12, 11, WOOD)
	_frame(img, x, y, 12, 11, WOOD_L)
	_rect(img, x + 2, y + 2, 8, 7, SLATE_D)
	_rect(img, x + 3, y + 5, 6, 3, SLATE)
	_hline(img, x + 3, y + 4, 6, SLATE.lightened(0.15))
	_px(img, x + 8, y + 3, AMBER_L)
	# and a nail above it
	_px(img, x + 6, y - 2, IRON)


static func _warm_grade(img: Image) -> void:
	var lights: Array = [
		[LANTERN_XS[0], 25, 52.0, AMBER, 0.34],
		[LANTERN_XS[1], 25, 52.0, AMBER, 0.34],
		[HEARTH_X + HEARTH_W / 2, HEARTH_Y + HEARTH_H - 10, 56.0, AMBER_D, 0.46],
		[DOOR_X + DOOR_W / 2, WALL_H + 8, 34.0, AMBER_D, 0.20],
	]
	for entry in lights:
		var lx: int = entry[0]
		var ly: int = entry[1]
		var r: float = entry[2]
		var col: Color = entry[3]
		var strength: float = entry[4]
		for y in range(max(0, ly - int(r)), min(H, ly + int(r))):
			for x in range(max(0, lx - int(r)), min(W, lx + int(r))):
				var d: float = Vector2(float(x - lx), float(y - ly)).length()
				if d < r:
					var t: float = 1.0 - d / r
					_mix(img, x, y, col, t * t * strength)
	# hearth warmth across the wall
	for y in range(0, WALL_H):
		for x in range(0, 120):
			var d: float = Vector2(float(x - 30), float(y - 40)).length()
			if d < 96.0:
				_mix(img, x, y, AMBER_D, (1.0 - d / 96.0) * 0.10)
	# pools of lamplight on the boards
	_ellipse(img, float(LANTERN_XS[0]), 86.0, 34.0, 20.0, AMBER, 0.18)
	_ellipse(img, float(LANTERN_XS[1]), 86.0, 34.0, 20.0, AMBER, 0.18)
	_ellipse(img, 40.0, 74.0, 40.0, 22.0, AMBER_D, 0.24)
	# vignette, gentle
	for y in range(H):
		for x in range(W):
			var dx: float = (float(x) - W / 2.0) / (W * 0.66)
			var dy: float = (float(y) - H / 2.0) / (H * 0.66)
			var d: float = sqrt(dx * dx + dy * dy)
			if d > 0.78:
				_mix(img, x, y, INK, min(0.38, (d - 0.78) * 0.8))


# -------------------------------------------------------------- furniture ---

static func make_table() -> Texture2D:
	var img: Image = Image.create(22, 18, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# a soft shadow on the boards
	for x in range(1, 21):
		_mix(img, x, 15, INK, 0.26)
		_mix(img, x, 16, INK, 0.14)
	# legs
	_rect(img, 3, 12, 2, 6, WOOD_D)
	_rect(img, 17, 12, 2, 6, WOOD_D)
	# top
	_rect(img, 1, 5, 20, 8, PLANK_L)
	_rect(img, 1, 5, 20, 2, CREAM.lerp(PLANK_L, 0.55))
	_hline(img, 3, 9, 15, WOOD_D.lerp(PLANK_L, 0.45))
	_hline(img, 6, 11, 10, WOOD_D.lerp(PLANK_L, 0.40))
	_hline(img, 1, 12, 20, WOOD_D)
	_frame(img, 1, 5, 20, 8, WOOD_D)
	# boards
	_vline(img, 8, 6, 6, WOOD_D)
	_vline(img, 15, 6, 6, WOOD_D)
	_outline(img, INK)
	return ImageTexture.create_from_image(img)


static func make_candle() -> Texture2D:
	var img: Image = Image.create(5, 9, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_rect(img, 1, 4, 3, 5, CREAM)
	_rect(img, 1, 4, 3, 1, CREAM.darkened(0.18))
	_px(img, 2, 3, AMBER_L)
	_px(img, 2, 2, AMBER)
	_outline(img, INK)
	return ImageTexture.create_from_image(img)


static func make_stool() -> Texture2D:
	var img: Image = Image.create(9, 11, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_rect(img, 1, 2, 7, 4, WOOD)
	_hline(img, 1, 2, 7, WOOD_L)
	_rect(img, 2, 6, 1, 5, WOOD_D)
	_rect(img, 6, 6, 1, 5, WOOD_D)
	_outline(img, INK)
	return ImageTexture.create_from_image(img)


static func make_counter() -> Texture2D:
	var img: Image = Image.create(60, 34, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in range(2, 58):
		_mix(img, x, 32, INK, 0.30)
		_mix(img, x, 33, INK, 0.16)
	# front panel
	_rect(img, 2, 6, 56, 26, WOOD)
	for i in range(0, 56, 9):
		_vline(img, 2 + i, 7, 25, WOOD_D)
	# top
	_rect(img, 0, 2, 60, 6, WOOD_L)
	_hline(img, 0, 2, 60, CREAM.lerp(WOOD_L, 0.55))
	_hline(img, 0, 7, 60, WOOD_D)
	# brass rail
	_hline(img, 3, 26, 54, AMBER_D)
	_hline(img, 3, 27, 54, AMBER)
	# a pot of stew
	_rect(img, 6, 0, 13, 9, IRON)
	_rect(img, 7, 1, 11, 2, IRON.darkened(0.25))
	_rect(img, 8, 0, 9, 1, AMBER)
	_px(img, 6, 0, IRON)
	# a stack of bowls
	for i in range(3):
		_rect(img, 26, 4 - i * 2, 9, 2, CREAM)
		_px(img, 27, 4 - i * 2, AMBER)
	# a cutting board with a knife
	_rect(img, 42, 4, 13, 4, WOOD_D)
	_rect(img, 42, 4, 13, 1, WOOD_L)
	_hline(img, 45, 3, 7, STONE_L)
	_outline(img, INK)
	return ImageTexture.create_from_image(img)


static func make_barrel() -> Texture2D:
	var img: Image = Image.create(16, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in range(1, 15):
		_mix(img, x, 19, INK, 0.32)
	_rect(img, 2, 2, 12, 17, WOOD)
	_rect(img, 1, 5, 14, 12, WOOD)
	_hline(img, 1, 8, 14, IRON)
	_hline(img, 1, 14, 14, IRON)
	_rect(img, 2, 2, 12, 2, WOOD_L)
	for i in range(2, 14, 3):
		_vline(img, i, 4, 15, WOOD_D)
	_outline(img, INK)
	return ImageTexture.create_from_image(img)


static func make_crate() -> Texture2D:
	var img: Image = Image.create(16, 15, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in range(1, 15):
		_mix(img, x, 14, INK, 0.30)
	_rect(img, 1, 2, 14, 12, WOOD)
	_frame(img, 1, 2, 14, 12, WOOD_D)
	_rect(img, 1, 2, 14, 2, WOOD_L)
	for i in range(9):
		_px(img, 2 + i, 4 + i, WOOD_D)
		_px(img, 12 - i, 4 + i, WOOD_D)
	_outline(img, INK)
	return ImageTexture.create_from_image(img)


static func make_plant() -> Texture2D:
	var img: Image = Image.create(14, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in range(2, 12):
		_mix(img, x, 19, INK, 0.28)
	# terracotta pot
	_rect(img, 3, 13, 8, 7, RUST)
	_rect(img, 2, 12, 10, 2, RUST_D)
	_hline(img, 4, 15, 6, RUST_D)
	# leaves
	for i in range(7):
		var lx: int = 2 + (i * 3) % 10
		var ly: int = 2 + (i * 5) % 10
		_rect(img, lx, ly, 3, 3, SAGE)
		_px(img, lx, ly + 2, SAGE_D)
	_vline(img, 7, 6, 8, SAGE_D)
	_outline(img, INK)
	return ImageTexture.create_from_image(img)


static func make_cat() -> Texture2D:
	var img: Image = Image.create(18, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# curled body
	_ellipse(img, 8.0, 7.0, 7.0, 4.0, CATFUR, 1.0)
	_ellipse(img, 7.0, 6.0, 4.0, 2.0, CATFUR.lightened(0.12), 1.0)
	# darker stripes
	for i in range(3):
		_px(img, 4 + i * 3, 5, CATFUR.darkened(0.25))
		_px(img, 5 + i * 3, 9, CATFUR.darkened(0.25))
	# head
	_ellipse(img, 13.0, 6.0, 3.5, 3.0, CATFUR, 1.0)
	# ears
	_px(img, 11, 2, CATFUR)
	_px(img, 12, 3, CATFUR)
	_px(img, 15, 2, CATFUR)
	_px(img, 14, 3, CATFUR)
	# closed eyes, a nose, whiskers
	_hline(img, 12, 5, 2, INK)
	_hline(img, 15, 5, 2, INK)
	_px(img, 14, 6, PINK)
	_px(img, 9, 7, PINK)
	# tail curled round
	_rect(img, 2, 9, 5, 1, CATFUR.darkened(0.15))
	_rect(img, 1, 7, 1, 3, CATFUR.darkened(0.15))
	_outline(img, INK)
	return ImageTexture.create_from_image(img)


static func make_coat(tint: Color) -> Texture2D:
	var img: Image = Image.create(10, 15, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# hanger
	_hline(img, 3, 0, 4, IRON)
	_px(img, 4, 1, IRON)
	# shoulders
	_rect(img, 1, 2, 8, 2, tint)
	# body, tapering
	_rect(img, 2, 4, 6, 9, tint)
	_rect(img, 3, 13, 4, 2, tint.darkened(0.18))
	# collar
	_rect(img, 3, 2, 4, 1, tint.lightened(0.22))
	# buttons and a fold
	_px(img, 5, 6, tint.darkened(0.35))
	_px(img, 5, 9, tint.darkened(0.35))
	_vline(img, 7, 5, 7, tint.darkened(0.2))
	_outline(img, INK)
	return ImageTexture.create_from_image(img)


static func make_bowl() -> Texture2D:
	var img: Image = Image.create(9, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_rect(img, 1, 1, 7, 2, CREAM)
	_rect(img, 2, 3, 5, 2, CREAM.darkened(0.12))
	_rect(img, 2, 1, 5, 1, AMBER)
	_px(img, 3, 0, AMBER_L)
	_outline(img, INK)
	return ImageTexture.create_from_image(img)


static func make_glow() -> Texture2D:
	var size := 64
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := float(size) / 2.0
	for y in range(size):
		for x in range(size):
			var d: float = Vector2(x - c, y - c).length() / c
			if d < 1.0:
				var a: float = pow(1.0 - d, 2.0)
				img.set_pixel(x, y, Color(1.0, 0.86, 0.62, a))
	return ImageTexture.create_from_image(img)


static func fire_frames() -> Array:
	if _fire_cache.size() > 0:
		return _fire_cache
	_reset(4242)
	var profiles: Array = [
		[3, 3, 2, 3, 2, 2, 1, 2, 1, 1, 0, 1],
		[4, 3, 3, 2, 3, 2, 2, 1, 1, 2, 1, 0],
		[3, 4, 3, 2, 2, 3, 1, 2, 2, 1, 1, 0],
		[3, 3, 3, 3, 2, 2, 2, 1, 1, 1, 0, 1],
	]
	for f in range(4):
		var img: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		# a bed of embers
		_rect(img, 4, 13, 8, 3, AMBER_D)
		_rect(img, 5, 12, 6, 2, AMBER)
		# the flame: one tongue of fire, narrowing as it rises
		var prof: Array = profiles[f]
		for i in range(prof.size()):
			var w: int = prof[i]
			if w <= 0:
				continue
			var col: Color = AMBER_L
			if i > 3:
				col = AMBER
			if i > 7:
				col = AMBER_D
			_rect(img, 8 - w / 2, 13 - i, w, 1, col)
		# a second, shorter flame leaning off to one side
		var lean: int = 5 if f % 2 == 0 else 11
		_rect(img, lean, 11, 1, 2, AMBER)
		_px(img, lean, 10, AMBER_L)
		# a spark
		_px(img, 5 + _rnd(6), 2 + _rnd(4), AMBER_L)
		_fire_cache.append(ImageTexture.create_from_image(img))
	return _fire_cache


# -------------------------------------------------------------- characters --

static func _char_spec(kind: String) -> Dictionary:
	match kind:
		"badger":
			return {
				"fur": Color8(128, 124, 134),
				"fur_d": Color8(88, 84, 96),
				"body": Color8(130, 90, 64),
				"body_d": Color8(92, 60, 46),
				"accent": CREAM,
			}
		"heron":
			return {
				"fur": Color8(198, 210, 220),
				"fur_d": Color8(148, 162, 176),
				"body": Color8(88, 104, 132),
				"body_d": Color8(62, 76, 100),
				"accent": AMBER,
			}
		"mole":
			return {
				"fur": Color8(108, 88, 76),
				"fur_d": Color8(74, 58, 50),
				"body": Color8(120, 142, 108),
				"body_d": Color8(84, 102, 80),
				"accent": PINK,
			}
		"hare":
			return {
				"fur": Color8(178, 168, 158),
				"fur_d": Color8(128, 120, 116),
				"body": Color8(92, 106, 122),
				"body_d": Color8(66, 78, 94),
				"accent": PINK,
			}
		"fox":
			return {
				"fur": Color8(196, 116, 66),
				"fur_d": Color8(148, 82, 48),
				"body": Color8(120, 96, 82),
				"body_d": Color8(88, 68, 60),
				"accent": CREAM,
			}
		_:
			return {
				"fur": Color8(228, 150, 74),
				"fur_d": Color8(170, 100, 52),
				"body": Color8(112, 132, 98),
				"body_d": Color8(80, 96, 74),
				"accent": CREAM,
			}


static func make_char(kind: String, dir: int, frame: int, seated: bool = false) -> Texture2D:
	var spec: Dictionary = _char_spec(kind)
	var fur: Color = spec["fur"]
	var fur_d: Color = spec["fur_d"]
	var body: Color = spec["body"]
	var body_d: Color = spec["body_d"]
	var accent: Color = spec["accent"]
	var img: Image = Image.create(12, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var f: int = frame % 4
	var side: bool = dir == 2 or dir == 3
	var eat: bool = seated and frame >= 2

	# a soft contact shadow so feet sit on the boards
	for x in range(2, 10):
		_mix(img, x, 15, INK, 0.30)

	# legs: head 1-7, body 8-12, so there are three rows left for a step
	if seated:
		_rect(img, 2, 12, 8, 2, body)
		_rect(img, 3, 14, 6, 2, body_d)
		_rect(img, 3, 15, 2, 1, fur_d)
		_rect(img, 7, 15, 2, 1, fur_d)
	else:
		var lift_l: int = 1 if f == 0 else 0
		var lift_r: int = 1 if f == 2 else 0
		if side:
			_rect(img, 3, 13 - lift_l, 3, 3, fur_d)
			_rect(img, 7, 13 - lift_r, 3, 3, fur_d)
			_rect(img, 2, 15 - lift_l, 5, 1, fur_d.darkened(0.28))
			_rect(img, 7, 15 - lift_r, 5, 1, fur_d.darkened(0.28))
		else:
			_rect(img, 3, 13 - lift_l, 2, 3, fur_d)
			_rect(img, 7, 13 - lift_r, 2, 3, fur_d)
			_rect(img, 2, 15 - lift_l, 3, 1, fur_d.darkened(0.28))
			_rect(img, 8, 15 - lift_r, 3, 1, fur_d.darkened(0.28))

	# body / clothing
	_rect(img, 2, 8, 8, 5, body)
	_rect(img, 2, 11, 8, 1, body_d)
	if kind == "player":
		_rect(img, 4, 9, 4, 3, accent)
		_px(img, 5, 8, accent)
	elif kind == "fox":
		_rect(img, 4, 9, 4, 3, accent)
		_px(img, 5, 10, fur_d)

	# arms
	if side:
		_rect(img, 6, 9, 3, 4, body_d)
	elif seated:
		_rect(img, 1, 9, 2, 3, body)
		_rect(img, 9, 9, 2, 3, body)
		_px(img, 1, 11, fur)
		_px(img, 10, 11, fur)
	else:
		_rect(img, 1, 9, 2, 4, body)
		_rect(img, 9, 9, 2, 4, body)
		_px(img, 1, 12, fur)
		_px(img, 10, 12, fur)

	if eat:
		# a spoon making its way up to the mouth
		_rect(img, 9, 7, 1, 4, WOOD_L)
		_px(img, 8, 6, CREAM)
		_px(img, 9, 6, CREAM)
		_px(img, 8, 5, CREAM.darkened(0.1))

	# head
	_rect(img, 3, 1, 6, 7, fur)
	_rect(img, 3, 1, 6, 2, fur.lightened(0.08))

	if kind == "badger":
		_vline(img, 5, 1, 7, accent)
		if side:
			_vline(img, 6, 1, 7, accent)
	elif kind == "heron":
		if side:
			_rect(img, 8, 4, 4, 2, accent)
			_px(img, 11, 5, accent.darkened(0.2))
		else:
			_rect(img, 5, 6, 2, 3, accent)
		_px(img, 4, 0, fur_d)
	elif kind == "mole":
		if side:
			_rect(img, 8, 5, 2, 1, accent)
		else:
			_rect(img, 5, 6, 2, 1, accent)
		_hline(img, 3, 7, 6, fur_d)
	elif kind == "hare":
		# long ears, straight up
		_rect(img, 4, -1, 1, 4, fur)
		_rect(img, 7, -1, 1, 4, fur)
		_px(img, 4, -1, fur_d)
		_px(img, 7, -1, fur_d)
		if not side:
			_rect(img, 5, 6, 2, 1, accent)
	elif kind == "fox":
		# a pointed muzzle
		if side:
			_rect(img, 8, 5, 3, 2, fur)
			_px(img, 11, 5, INK)
		else:
			_rect(img, 5, 5, 2, 2, fur.lightened(0.15))
			_px(img, 5, 6, INK)
		_px(img, 3, 0, fur_d)
		_px(img, 8, 0, fur_d)

	if dir == 0:
		_px(img, 4, 4, INK)
		_px(img, 7, 4, INK)
		_px(img, 4, 3, CREAM)
		_px(img, 7, 3, CREAM)
		_rect(img, 5, 6, 2, 1, fur_d)
		if kind != "hare":
			_px(img, 3, 0, fur)
			_px(img, 8, 0, fur)
			_px(img, 3, 1, fur_d)
			_px(img, 8, 1, fur_d)
	elif dir == 1:
		_hline(img, 3, 1, 6, fur_d)
		if kind != "hare":
			_px(img, 3, 0, fur)
			_px(img, 8, 0, fur)
		_rect(img, 5, 5, 2, 3, fur_d)
	elif side:
		_px(img, 4, 4, INK)
		_px(img, 3, 4, CREAM)
		_rect(img, 2, 6, 3, 1, fur_d)
		if kind != "hare":
			_px(img, 3, 0, fur)
			_px(img, 4, 0, fur)
			_px(img, 3, 1, fur_d)
		if kind == "player":
			_rect(img, 9, 10, 2, 3, fur)
			_rect(img, 10, 8, 2, 3, fur)
			_px(img, 11, 8, accent)
		elif kind == "fox":
			_rect(img, 9, 9, 3, 3, fur)
			_px(img, 11, 8, CREAM)
		else:
			_rect(img, 9, 11, 1, 3, body_d)

	_outline(img, INK)
	if dir == 3:
		img.flip_x()
	return ImageTexture.create_from_image(img)


static func char_tex(kind: String, dir: int, frame: int, seated: bool = false) -> Texture2D:
	var key: String = "%s_%d_%d_%s" % [kind, dir, frame, str(seated)]
	if _char_cache.has(key):
		return _char_cache[key]
	var tex: Texture2D = make_char(kind, dir, frame, seated)
	_char_cache[key] = tex
	return tex


# Frames 0-1 are sitting still, 2-3 are eating.
static func sit_tex(kind: String, dir: int, frame: int) -> Texture2D:
	return char_tex(kind, dir, frame, true)


static func make_panel(w: int, h: int, fill: Color, border: Color) -> Texture2D:
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_rect(img, 1, 1, w - 2, h - 2, fill)
	_frame(img, 0, 0, w, h, border)
	_hline(img, 1, 1, w - 2, fill.lightened(0.10))
	_hline(img, 1, h - 2, w - 2, fill.darkened(0.25))
	return ImageTexture.create_from_image(img)


# ------------------------------------------------------------ new pieces ---

static func make_chair() -> Texture2D:
	var img: Image = Image.create(12, 11, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in range(1, 11):
		_mix(img, x, 10, INK, 0.26)
	# back
	_rect(img, 2, 0, 8, 5, WOOD)
	_hline(img, 2, 0, 8, WOOD_L)
	_vline(img, 3, 1, 4, WOOD_D)
	_vline(img, 8, 1, 4, WOOD_D)
	# seat
	_rect(img, 1, 5, 10, 3, WOOD)
	_hline(img, 1, 5, 10, WOOD_L)
	_hline(img, 1, 7, 10, WOOD_D)
	# legs
	_rect(img, 2, 8, 2, 3, WOOD_D)
	_rect(img, 8, 8, 2, 3, WOOD_D)
	_outline(img, INK)
	return ImageTexture.create_from_image(img)


static func make_jar(col: Color) -> Texture2D:
	var img: Image = Image.create(8, 10, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_rect(img, 1, 2, 6, 8, col)
	_rect(img, 1, 2, 6, 1, col.lightened(0.28))
	_hline(img, 2, 6, 4, col.darkened(0.22))
	_rect(img, 0, 2, 1, 8, GLASS_L)
	_rect(img, 7, 2, 1, 8, GLASS_L)
	_rect(img, 0, 1, 8, 1, WOOD_D)
	_rect(img, 1, 0, 6, 1, WOOD)
	_frame(img, 0, 0, 8, 10, GLASS_L.darkened(0.45))
	return ImageTexture.create_from_image(img)


static func make_order_bubble(col: Color) -> Texture2D:
	# a thought bubble with the dish they are hoping for in it
	var img: Image = Image.create(15, 15, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_rect(img, 0, 0, 15, 11, CREAM)
	_frame(img, 0, 0, 15, 11, WOOD_D)
	_hline(img, 1, 1, 13, CREAM.lightened(0.2))
	# a bowl holding the colour of the dish
	_rect(img, 3, 4, 9, 3, col)
	_rect(img, 3, 4, 9, 1, col.lightened(0.3))
	_rect(img, 4, 7, 7, 2, CREAM.darkened(0.12))
	_frame(img, 3, 4, 9, 5, WOOD_D)
	# tail
	_rect(img, 6, 11, 3, 2, CREAM)
	_px(img, 6, 13, CREAM)
	_px(img, 7, 14, CREAM)
	_frame(img, 6, 11, 3, 1, WOOD_D)
	return ImageTexture.create_from_image(img)


static func make_plate(col: Color) -> Texture2D:
	var img: Image = Image.create(11, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in range(0, 11):
		_mix(img, x, 5, INK, 0.24)
	_rect(img, 1, 1, 9, 3, CREAM)
	_rect(img, 2, 1, 7, 2, col)
	_px(img, 4, 0, AMBER_L)
	_hline(img, 1, 3, 9, CREAM.darkened(0.15))
	_outline(img, INK)
	return ImageTexture.create_from_image(img)


static func make_ingredient_icon(id: int) -> Texture2D:
	while _ing_icon_cache.size() <= id:
		_ing_icon_cache.append(null)
	if _ing_icon_cache[id] == null:
		var img: Image = Image.create(9, 9, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		_draw_ingredient_mark(img, 1, 1, id)
		_ing_icon_cache[id] = ImageTexture.create_from_image(img)
	return _ing_icon_cache[id]


static func make_block(col: Color, w: int, h: int) -> Texture2D:
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(col)
	return ImageTexture.create_from_image(img)


# The whole menu on one page: each dish with the two things that make it, what
# it pays, and a mark if you have cooked it before.
static func make_book(cooked: Dictionary, dishes: Array) -> Texture2D:
	var img: Image = Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(H):
		for x in range(W):
			_mix(img, x, y, INK, 0.74)
	_rect(img, 8, 8, W - 16, H - 18, Color8(24, 19, 20))
	_frame(img, 8, 8, W - 16, H - 18, AMBER_D)
	_rect(img, 9, 9, W - 18, H - 20, Color8(36, 29, 28))
	_hline(img, 9, 9, W - 18, Color8(56, 44, 40))
	_draw_text(img, "THE BOOK", 20, 16, AMBER)
	_draw_text(img, "B  CLOSE", W - 68, 16, AMBER_D)
	_hline(img, 18, 26, W - 36, AMBER_D)
	for i in range(dishes.size()):
		var d: Dictionary = dishes[i]
		var cx: int = 20 + (i / 5) * 148
		var cy: int = 34 + (i % 5) * 22
		var known: bool = cooked.has(str(i))
		var ink: Color = CREAM if known else FOG.darkened(0.34)
		_draw_ingredient_mark(img, cx, cy, int(d["a"]))
		_draw_ingredient_mark(img, cx + 8, cy, int(d["b"]))
		_draw_text(img, str(d["name"]), cx + 20, cy - 1, ink)
		_draw_text(img, "%d" % int(d["price"]), cx + 118, cy - 1, AMBER_D if known else FOG.darkened(0.44))
		if known:
			_rect(img, cx - 5, cy + 1, 2, 2, AMBER)
	_draw_text(img, "TEN FROM FIVE", 20, 142, FOG.darkened(0.28))
	_draw_text(img, "%d/10 COOKED" % cooked.size(), 214, 142, AMBER_D)
	return ImageTexture.create_from_image(img)


static func make_pot_fill(col: Color) -> Texture2D:
	var img: Image = Image.create(22, 7, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_rect(img, 1, 2, 20, 4, col)
	_rect(img, 2, 2, 18, 1, col.lightened(0.22))
	_hline(img, 3, 4, 6, col.darkened(0.18))
	_px(img, 15, 5, col.darkened(0.14))
	_frame(img, 1, 1, 20, 5, IRON.darkened(0.2))
	return ImageTexture.create_from_image(img)


static func bubbles() -> Array:
	if _bubble_cache.size() > 0:
		return _bubble_cache
	for f in range(3):
		var img: Image = Image.create(24, 12, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for i in range(4):
			var bx: int = 3 + i * 5
			var by: int = 8 - ((i + f) % 3) * 3
			_px(img, bx, by, FOG)
			_px(img, bx + 1, by, CREAM)
			if i % 2 == 0:
				_px(img, bx, by - 1, FOG)
				_px(img, bx + 1, by - 1, FOG)
		_bubble_cache.append(ImageTexture.create_from_image(img))
	return _bubble_cache


# ------------------------------------------------------------- the kitchen --

static func kitchen_image() -> Image:
	if _kitchen_img != null:
		return _kitchen_img
	_reset(3131)
	var img: Image = Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(INK)
	_draw_wall(img)
	_draw_floor(img)
	_draw_beam(img, [40, 286])
	_draw_kitchen_runner(img)
	_draw_kitchen_mat(img)
	_draw_kitchen_sideboard(img)
	_draw_kitchen_shelf(img)
	_draw_kitchen_pans(img)
	_draw_kitchen_prep(img)
	_draw_kitchen_stove(img)
	# the grade goes on the light, then the signs and the doorway stay crisp on
	# top of it, the way paint on a board should
	_kitchen_grade(img)
	_draw_passage(img, W - 28, false, 28)
	_draw_kitchen_signs(img)
	_kitchen_img = img
	return _kitchen_img


static func make_kitchen() -> Texture2D:
	if _kitchen_tex == null:
		_kitchen_tex = ImageTexture.create_from_image(kitchen_image())
	return _kitchen_tex


static func _draw_passage(img: Image, x: int, opening_left: bool, w: int = 14) -> void:
	# a low doorway through to the kitchen: dark, with warm light coming out
	var top: int = WALL_H - 2
	var h: int = 48
	_rect(img, x, top, w, h, INK)
	# the far wall of the passage, a step or two in
	_rect(img, x + 2, top + 3, w - 4, h - 6, INK.darkened(0.4))
	# stone frame on the room side
	var fx: int = x + w - 1 if opening_left else x
	_rect(img, fx, top - 3, 3, h + 3, STONE)
	_hline(img, fx, top - 3, 3, STONE_L)
	# a step
	_rect(img, x + 1, top + h - 4, w - 2, 4, STONE_D)
	_hline(img, x + 1, top + h - 4, w - 2, STONE)
	# the light that leaks into this room
	var lx: int = x + w if opening_left else x - 1
	for i in range(10):
		var sx: int = lx + i if opening_left else lx - i
		for yy in range(top, top + h):
			_mix(img, sx, yy, AMBER_D, 0.16 - i * 0.016)
	# a curtain bunched at the side
	if opening_left:
		_rect(img, x + w - 4, top, 4, 26, RUST_D)
	else:
		_rect(img, x, top, 4, 26, RUST_D)


static func _draw_kitchen_mat(img: Image) -> void:
	# a rag mat where you stand to cook
	_rect(img, 226, 96, 46, 14, RUST_D)
	_rect(img, 228, 98, 42, 10, RUST)
	_frame(img, 228, 98, 42, 10, RUST_D)
	_hline(img, 232, 102, 34, RUST_D.darkened(0.1))


static func _draw_kitchen_shelf(img: Image) -> void:
	# one long dresser: five jars on the board, and under each jar its own card
	var x0: int = 74
	var w: int = 150
	var cols: Array = [
		Color8(168, 126, 104), Color8(214, 190, 140), Color8(206, 176, 196),
		Color8(126, 158, 106), Color8(242, 204, 110),
	]
	_rect(img, x0, 38, w, 5, WOOD)
	_hline(img, x0, 38, w, WOOD_L)
	_hline(img, x0, 42, w, WOOD_D)
	for bx in [x0 + 8, x0 + w / 2 - 1, x0 + w - 10]:
		_rect(img, bx, 43, 2, 7, WOOD_D)
	for i in range(5):
		var jx: int = x0 + 15 + i * 30
		_draw_jar_at(img, jx, 28, cols[i])
		_kitchen_card(img, jx - 4, 44, i)
	# a crock of spoons at the far end
	_rect(img, x0 + w + 4, 54, 12, 12, SLATE_D)
	_rect(img, x0 + w + 4, 54, 12, 1, SLATE)
	_vline(img, x0 + w + 8, 46, 9, WOOD_L)
	_vline(img, x0 + w + 11, 48, 7, WOOD_L)


static func _kitchen_card(img: Image, x: int, y: int, id: int) -> void:
	_rect(img, x, y, 16, 9, CREAM)
	_frame(img, x, y, 16, 9, WOOD_D)
	_hline(img, x + 1, y + 1, 14, CREAM.lightened(0.2))
	_draw_ingredient_mark(img, x + 4, y + 1, id)


static func _draw_kitchen_sideboard(img: Image) -> void:
	# a tall sideboard down the left wall, so the room is not just floor
	var x: int = 4
	var y: int = 148
	_rect(img, x, y - 46, 24, 46, WOOD)
	_rect(img, x, y - 46, 24, 3, WOOD_L)
	for band in [30, 14]:
		_hline(img, x, y - band, 24, WOOD_D)
	for i in range(2):
		_vline(img, x + 4 + i * 16, y - 44, 42, WOOD_D)
	_px(img, x + 12, y - 34, AMBER_D)
	_px(img, x + 12, y - 18, AMBER_D)
	# bowls and a crock on top
	_rect(img, x + 4, y - 52, 8, 6, CREAM)
	_rect(img, x + 14, y - 50, 7, 4, SLATE_D)
	_rect(img, x + 3, y - 56, 4, 4, CREAM)
	# a flour barrel and a crate beside it
	_rect(img, 38, 132, 14, 16, WOOD)
	_rect(img, 38, 132, 14, 2, WOOD_L)
	_hline(img, 38, 136, 14, WOOD_D)
	_hline(img, 38, 143, 14, WOOD_D)
	_rect(img, 39, 131, 12, 1, WOOD_D)
	_rect(img, 58, 136, 12, 12, WOOD)
	_frame(img, 58, 136, 12, 12, WOOD_D)
	_vline(img, 59, 137, 10, WOOD_D)
	_vline(img, 68, 137, 10, WOOD_D)
	_hline(img, 59, 141, 10, WOOD_D)


static func _draw_kitchen_runner(img: Image) -> void:
	# a worn runner from the doorway towards the stove
	var wool: Color = Color8(80, 56, 54)
	var weave: Color = Color8(98, 70, 62)
	_rect(img, 150, 132, 152, 18, WOOD_D)
	_rect(img, 152, 134, 148, 14, wool)
	for i in range(6):
		_vline(img, 158 + i * 24, 134, 14, weave)
	_hline(img, 152, 134, 148, weave)
	_hline(img, 152, 147, 148, WOOD_D)


static func _draw_village_signs(img: Image) -> void:
	_sign(img, 34, 46, 32, 16, ["NINE", "COATS"])
	_sign(img, 196, 22, 78, 14, ["GROCER"])


static func _draw_jar_at(img: Image, x: int, y: int, col: Color) -> void:
	_rect(img, x + 1, y + 2, 6, 8, col)
	_rect(img, x + 1, y + 2, 6, 1, col.lightened(0.28))
	_hline(img, x + 2, y + 6, 4, col.darkened(0.22))
	_rect(img, x, y + 2, 1, 8, GLASS_L)
	_rect(img, x + 7, y + 2, 1, 8, GLASS_L)
	_rect(img, x, y + 1, 8, 1, WOOD_D)
	_rect(img, x + 1, y, 6, 1, WOOD)
	_frame(img, x, y, 8, 10, GLASS_L.darkened(0.45))


static func _draw_kitchen_pans(img: Image) -> void:
	# pans and a ladle hanging off the beam
	_hline(img, 172, 18, 12, IRON)
	for i in range(3):
		var px: int = 176 + i * 5
		_vline(img, px, 10, 8, IRON)
		_rect(img, px - 3, 18, 7, 6, IRON)
		_hline(img, px - 3, 18, 7, STONE_L.darkened(0.3))
		_px(img, px, 24, IRON.darkened(0.3))
	# a bundle of thyme drying
	_vline(img, 196, 10, 5, WOOD_D)
	for i in range(4):
		_rect(img, 194 + i, 15 + i, 2, 4, SAGE_D)


static func _draw_kitchen_prep(img: Image) -> void:
	# a chopping table standing in the middle of the floor
	var x: int = 126
	var y: int = 126
	for xx in range(2, 46):
		_mix(img, x + xx, y, INK, 0.26)
	_rect(img, x + 5, y - 8, 3, 8, WOOD_D)
	_rect(img, x + 40, y - 8, 3, 8, WOOD_D)
	_rect(img, x, y - 22, 48, 14, WOOD)
	_rect(img, x, y - 22, 48, 2, WOOD_L)
	_hline(img, x, y - 9, 48, WOOD_D)
	# a board, a knife, and something being cut
	_rect(img, x + 5, y - 18, 19, 6, WOOD_L)
	_rect(img, x + 5, y - 18, 19, 1, CREAM.lerp(WOOD_L, 0.45))
	_hline(img, x + 20, y - 20, 9, STONE_L)
	_px(img, x + 29, y - 20, WOOD_D)
	_rect(img, x + 9, y - 17, 4, 3, Color8(168, 126, 104))
	_rect(img, x + 15, y - 17, 3, 2, Color8(206, 176, 196))
	# a bowl of odds and ends
	_rect(img, x + 31, y - 20, 9, 4, CREAM)
	_rect(img, x + 32, y - 21, 7, 1, SAGE)
	_hline(img, x + 31, y - 17, 9, CREAM.darkened(0.18))


static func _draw_kitchen_stove(img: Image) -> void:
	var x: int = 222
	var top: int = 34
	# chimney into the wall
	_rect(img, x + 22, 0, 18, top, STONE_D)
	_frame(img, x + 22, 0, 18, top, MORTAR)
	for yy in range(0, top, 7):
		_hline(img, x + 22, yy, 18, MORTAR)
	# iron range
	_rect(img, x, top, 62, 42, IRON)
	_rect(img, x, top, 62, 3, STONE_D)
	_hline(img, x, top + 3, 62, IRON.darkened(0.3))
	_rect(img, x, top + 41, 62, 3, IRON.darkened(0.35))
	# hot plate ring
	_ellipse(img, float(x + 31), float(top + 3), 18.0, 3.0, IRON.darkened(0.5), 0.9)
	# fire door with light behind it
	_rect(img, x + 18, top + 18, 26, 18, INK)
	_rect(img, x + 19, top + 19, 24, 16, AMBER_D)
	_ellipse(img, float(x + 31), float(top + 30), 9.0, 5.0, AMBER, 0.75)
	for i in range(3):
		_vline(img, x + 24 + i * 7, top + 19, 16, IRON)
	_frame(img, x + 18, top + 18, 26, 18, IRON.darkened(0.3))
	# a ladle hanging on the front
	_vline(img, x + 8, top + 12, 8, WOOD_L)
	_rect(img, x + 6, top + 20, 5, 4, IRON)
	# the pot, sitting on the ring
	_rect(img, x + 14, top - 16, 34, 16, IRON)
	_rect(img, x + 14, top - 16, 34, 2, IRON.darkened(0.3))
	_hline(img, x + 14, top - 2, 34, IRON.darkened(0.45))
	_rect(img, x + 30, top - 18, 2, 2, IRON.darkened(0.2))
	_vline(img, x + 14, top - 14, 12, IRON.darkened(0.18))
	_vline(img, x + 47, top - 14, 12, IRON.darkened(0.18))


static func _kitchen_grade(img: Image) -> void:
	var lights: Array = [
		[LANTERN_XS[0], 25, 46.0, AMBER, 0.26],
		[LANTERN_XS[1], 25, 46.0, AMBER, 0.26],
		[275, 46, 62.0, AMBER_D, 0.40],
		[7, 80, 40.0, AMBER_D, 0.22],
	]
	for entry in lights:
		var lx: int = entry[0]
		var ly: int = entry[1]
		var r: float = entry[2]
		var col: Color = entry[3]
		var strength: float = entry[4]
		for y in range(max(0, ly - int(r)), min(H, ly + int(r))):
			for x in range(max(0, lx - int(r)), min(W, lx + int(r))):
				var d: float = Vector2(float(x - lx), float(y - ly)).length()
				if d < r:
					var t: float = 1.0 - d / r
					_mix(img, x, y, col, t * t * strength)
	_ellipse(img, 275.0, 92.0, 44.0, 24.0, AMBER, 0.14)
	for y in range(H):
		for x in range(W):
			var dx: float = (float(x) - W / 2.0) / (W * 0.66)
			var dy: float = (float(y) - H / 2.0) / (H * 0.66)
			var d: float = sqrt(dx * dx + dy * dy)
			if d > 0.78:
				_mix(img, x, y, INK, min(0.40, (d - 0.78) * 0.85))


# ------------------------------------------------------------ the village --

static func village_image() -> Image:
	if _village_img != null:
		return _village_img
	_reset(9091)
	var img: Image = Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(INK)
	_draw_sky(img)
	_draw_ridges(img)
	_draw_snow(img)
	_draw_inn_front(img)
	_draw_shut_house(img)
	_draw_shop_front(img)
	_draw_street_lamp(img)
	_village_grade(img)
	_draw_village_signs(img)
	_village_img = img
	return _village_img


static func make_village() -> Texture2D:
	if _village_tex == null:
		_village_tex = ImageTexture.create_from_image(village_image())
	return _village_tex


static func _draw_text(img: Image, s: String, x: int, y: int, col: Color) -> void:
	var cx: int = x
	for i in range(s.length()):
		var ch: String = s[i].to_upper()
		if GLYPHS.has(ch):
			var lines: PackedStringArray = String(GLYPHS[ch]).split("/")
			for yy in range(min(7, lines.size())):
				var bits: String = lines[yy]
				for xx in range(min(5, bits.length())):
					if bits[xx] == "1":
						_px(img, cx + xx, y + yy, col)
		cx += 6


static func _sign(img: Image, x: int, y: int, w: int, h: int, lines: Array) -> void:
	_rect(img, x, y, w, h, WOOD)
	_frame(img, x, y, w, h, WOOD_D)
	_hline(img, x + 1, y + 1, w - 2, WOOD_L)
	_rect(img, x - 1, y - 2, 2, 3, IRON)
	for i in range(lines.size()):
		var s: String = str(lines[i])
		var tw: int = s.length() * 6 - 1
		_draw_text(img, s, x + (w - tw) / 2, y + 3 + i * 8, INK.darkened(0.3))


static func _draw_sky(img: Image) -> void:
	for y in range(0, 96):
		var t: float = float(y) / 96.0
		var col: Color = Color8(30, 34, 54).lerp(Color8(58, 66, 92), t)
		for x in range(0, W):
			_px(img, x, y, col)
	# a low moon over the pass
	_ellipse(img, 272.0, 24.0, 14.0, 14.0, FOG, 0.18)
	_ellipse(img, 272.0, 24.0, 9.0, 9.0, CREAM, 0.42)
	# stars, and snow coming down
	for i in range(46):
		_px(img, 2 + _rnd(W - 4), 2 + _rnd(64), FOG.lerp(CREAM, 0.5))
	for i in range(120):
		var sx: int = _rnd(W)
		var sy: int = _rnd(160)
		_px(img, sx, sy, FOG.lerp(CREAM, 0.55))
		_px(img, sx, sy + 1, FOG)


static func _draw_ridges(img: Image) -> void:
	var base: int = 96
	for x in range(0, W):
		var h: int = 20 + int(9.0 * sin(float(x) * 0.028)) + int(5.0 * sin(float(x) * 0.09 + 1.1))
		for y in range(base - h, base):
			var col: Color = SLATE_D.darkened(0.36)
			if (x + y) % 11 == 0:
				col = SLATE_D.darkened(0.28)
			_px(img, x, y, col)
		_px(img, x, base - h, FOG.lerp(CREAM, 0.25))
		_px(img, x, base - h + 1, FOG.darkened(0.2))


static func _draw_snow(img: Image) -> void:
	for y in range(92, H):
		var t: float = float(y - 92) / float(H - 92)
		var col: Color = FOG.darkened(0.34).lerp(SLATE.darkened(0.30), t * 0.55)
		for x in range(0, W):
			_px(img, x, y, col)
	# drifts along the walls
	for i in range(16):
		_ellipse(img, float(_rnd(W)), 96.0 + float(_rnd(16)), 18.0, 5.0, FOG.darkened(0.16), 0.5)
	# the road through the village
	_rect(img, 0, 112, W, 34, SLATE_D.darkened(0.30))
	_hline(img, 0, 112, W, SLATE.darkened(0.34))
	_hline(img, 0, 145, W, SLATE.darkened(0.34))
	for i in range(2):
		var ty: int = 124 + i * 10
		_hline(img, 0, ty, W, SLATE.darkened(0.46))
		_hline(img, 0, ty + 1, W, SLATE_D.darkened(0.16))
	_rect(img, 0, 108, W, 4, FOG.darkened(0.22))
	_rect(img, 0, 146, W, 4, FOG.darkened(0.22))
	for i in range(70):
		_px(img, _rnd(W), 116 + _rnd(28), SLATE.darkened(0.4))


static func _draw_inn_front(img: Image) -> void:
	_rect(img, 0, 14, 96, 94, STONE_D)
	_rect(img, 0, 14, 96, 5, FOG.darkened(0.18))
	_rect(img, 0, 19, 96, 3, WOOD_D)
	for yy in range(22, 108):
		for xx in range(0, 96):
			if xx % 12 == 0 or (yy - 22) % 8 == 0:
				_px(img, xx, yy, MORTAR)
	for wx in [8, 68]:
		_rect(img, wx, 40, 24, 22, WOOD_D)
		_rect(img, wx + 2, 42, 20, 18, AMBER_D)
		_rect(img, wx + 3, 43, 18, 16, AMBER)
		_vline(img, wx + 11, 42, 18, WOOD_D)
		_hline(img, wx + 2, 50, 20, WOOD_D)
		_ellipse(img, float(wx + 12), 106.0, 24.0, 8.0, AMBER_D, 0.16)
	_rect(img, 32, 64, 30, 40, WOOD_D)
	_rect(img, 34, 66, 26, 38, WOOD)
	_vline(img, 47, 66, 38, WOOD_D)
	_rect(img, 54, 84, 2, 3, AMBER_D)
	_hline(img, 32, 103, 30, AMBER)
	_rect(img, 28, 104, 38, 4, FOG.darkened(0.3))
	_sign(img, 34, 46, 32, 16, ["NINE", "COATS"])


static func _draw_shut_house(img: Image) -> void:
	_rect(img, 104, 22, 56, 86, STONE_D)
	_rect(img, 104, 22, 56, 5, FOG.darkened(0.2))
	for yy in range(27, 108):
		for xx in range(104, 160):
			if (xx - 104) % 10 == 0 or (yy - 27) % 8 == 0:
				_px(img, xx, yy, MORTAR)
	_rect(img, 112, 44, 40, 26, WOOD_D)
	_rect(img, 114, 46, 36, 22, INK)
	for i in range(2):
		_rect(img, 110, 51 + i * 9, 44, 3, WOOD)
	_rect(img, 122, 78, 20, 30, WOOD_D)
	_rect(img, 124, 80, 16, 28, WOOD_D.darkened(0.12))
	_px(img, 137, 94, STONE_L)
	_rect(img, 118, 104, 28, 4, FOG.darkened(0.25))


static func _draw_shop_front(img: Image) -> void:
	_rect(img, 168, 16, 144, 92, STONE_D)
	_rect(img, 168, 16, 144, 5, FOG.darkened(0.2))
	for yy in range(21, 108):
		for xx in range(168, 312):
			if (xx - 168) % 12 == 0 or (yy - 21) % 8 == 0:
				_px(img, xx, yy, MORTAR)
	for wx in [176, 236]:
		_rect(img, wx, 44, 52, 28, WOOD_D)
		_rect(img, wx + 2, 46, 48, 24, AMBER_D)
		_rect(img, wx + 3, 47, 46, 22, AMBER)
		_vline(img, wx + 25, 46, 24, WOOD_D)
		_rect(img, wx + 6, 60, 10, 9, RUST_D)
		_rect(img, wx + 8, 57, 8, 3, RUST)
		_rect(img, wx + 30, 62, 12, 7, WOOD)
		_ellipse(img, float(wx + 26), 108.0, 28.0, 8.0, AMBER_D, 0.15)
	_rect(img, 292, 52, 22, 56, WOOD_D)
	_rect(img, 294, 54, 18, 54, WOOD)
	_rect(img, 306, 78, 2, 3, AMBER_D)
	for i in range(18):
		var ax: int = 168 + i * 8
		_rect(img, ax, 34, 8, 7, RUST if i % 2 == 0 else CREAM.lerp(RUST, 0.75))
	_hline(img, 168, 41, 144, RUST_D)
	# the stall, where you buy things
	_rect(img, 176, 92, 114, 12, WOOD)
	_rect(img, 176, 92, 114, 2, WOOD_L)
	_rect(img, 176, 101, 114, 3, WOOD_D)
	for i in range(8):
		_vline(img, 180 + i * 15, 94, 8, WOOD_D)
	_rect(img, 172, 104, 122, 3, FOG.darkened(0.25))


static func _draw_street_lamp(img: Image) -> void:
	var x: int = 100
	_rect(img, x, 96, 3, 54, IRON)
	_rect(img, x - 1, 146, 5, 3, IRON.darkened(0.2))
	_rect(img, x - 5, 88, 13, 3, IRON)
	_rect(img, x - 4, 91, 11, 8, WOOD_D)
	_rect(img, x - 3, 92, 9, 6, AMBER)
	_rect(img, x - 2, 93, 7, 4, AMBER_L)
	_px(img, x, 94, CREAM)
	_ellipse(img, float(x), 104.0, 20.0, 10.0, AMBER, 0.16)


static func _village_grade(img: Image) -> void:
	var lights: Array = [
		[20, 50, 34.0, AMBER_D, 0.22],
		[80, 50, 34.0, AMBER_D, 0.22],
		[48, 98, 26.0, AMBER_D, 0.20],
		[200, 56, 40.0, AMBER_D, 0.20],
		[262, 56, 40.0, AMBER_D, 0.20],
		[100, 94, 30.0, AMBER, 0.26],
	]
	for e in lights:
		var lx: int = e[0]
		var ly: int = e[1]
		var r: float = e[2]
		var col: Color = e[3]
		var st: float = e[4]
		for y in range(max(0, ly - int(r)), min(H, ly + int(r))):
			for x in range(max(0, lx - int(r)), min(W, lx + int(r))):
				var d: float = Vector2(float(x - lx), float(y - ly)).length()
				if d < r:
					var t: float = 1.0 - d / r
					_mix(img, x, y, col, t * t * st)
	for y in range(H):
		for x in range(W):
			var dx: float = (float(x) - W / 2.0) / (W * 0.60)
			var dy: float = (float(y) - H / 2.0) / (H * 0.60)
			var d2: float = sqrt(dx * dx + dy * dy)
			if d2 > 0.72:
				_mix(img, x, y, INK, min(0.42, (d2 - 0.72) * 0.9))


static func _draw_kitchen_signs(img: Image) -> void:
	# painted boards, not floating letters
	_sign(img, 96, 12, 62, 14, ["PANTRY"])
	_sign(img, 232, 10, 34, 13, ["POT"])
	_sign(img, 284, 108, 32, 13, ["ROOM"])


static func _draw_ingredient_mark(img: Image, x: int, y: int, id: int) -> void:
	match id:
		0:
			_rect(img, x, y + 2, 8, 3, Color8(168, 126, 104))
			_rect(img, x + 1, y + 1, 6, 1, Color8(190, 150, 126))
			_rect(img, x + 3, y + 5, 2, 3, CREAM.darkened(0.1))
		1:
			_ellipse(img, float(x + 4), float(y + 4), 4.0, 3.0, Color8(200, 176, 128), 1.0)
			_px(img, x + 2, y + 3, CREAM.darkened(0.2))
		2:
			_ellipse(img, float(x + 4), float(y + 4), 3.5, 3.5, Color8(206, 176, 196), 1.0)
			_vline(img, x + 4, y, 2, SAGE_D)
		3:
			_vline(img, x + 4, y + 1, 6, SAGE_D)
			for i in range(3):
				_px(img, x + 2 + i, y + 2 + i, SAGE)
				_px(img, x + 6 - i, y + 2 + i, SAGE)
		4:
			for i in range(6):
				_hline(img, x + 1 + i, y + 1 + i, 7 - i, Color8(242, 204, 110))
			_px(img, x + 3, y + 3, AMBER_D)
			_px(img, x + 5, y + 2, AMBER_D)


static func make_basket(col: Color) -> Texture2D:
	var img: Image = Image.create(16, 12, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_rect(img, 3, 2, 10, 5, col)
	_rect(img, 4, 1, 8, 2, col.lightened(0.18))
	_px(img, 6, 1, col.darkened(0.2))
	_px(img, 10, 2, col.darkened(0.2))
	_rect(img, 2, 6, 12, 5, WOOD)
	_rect(img, 2, 6, 12, 1, WOOD_L)
	for i in range(3):
		_hline(img, 3, 8 + i, 10, WOOD_D)
	_px(img, 2, 11, WOOD_D)
	_px(img, 13, 11, WOOD_D)
	_outline(img, INK)
	return ImageTexture.create_from_image(img)


static func make_car() -> Texture2D:
	var img: Image = Image.create(34, 15, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in range(2, 32):
		_mix(img, x, 14, INK, 0.28)
	_ellipse(img, 9.0, 12.0, 3.5, 2.5, INK, 1.0)
	_ellipse(img, 25.0, 12.0, 3.5, 2.5, INK, 1.0)
	_ellipse(img, 9.0, 12.0, 1.5, 1.0, STONE_L, 0.7)
	_ellipse(img, 25.0, 12.0, 1.5, 1.0, STONE_L, 0.7)
	_rect(img, 1, 5, 32, 7, RUST_D)
	_rect(img, 1, 5, 32, 2, RUST)
	_rect(img, 7, 1, 15, 5, RUST_D)
	_rect(img, 8, 2, 13, 3, GLASS_L)
	_vline(img, 14, 2, 3, RUST_D)
	_rect(img, 31, 7, 2, 2, AMBER_L)
	_rect(img, 1, 7, 1, 2, CREAM)
	_hline(img, 1, 11, 32, RUST_D.darkened(0.3))
	_outline(img, INK)
	return ImageTexture.create_from_image(img)


# --------------------------------------------------------------- text ------

const GLYPHS := {
	"A": "01110/10001/10001/11111/10001/10001/10001",
	"B": "11110/10001/10001/11110/10001/10001/11110",
	"C": "01110/10001/10000/10000/10000/10001/01110",
	"D": "11110/10001/10001/10001/10001/10001/11110",
	"E": "11111/10000/10000/11110/10000/10000/11111",
	"F": "11111/10000/10000/11110/10000/10000/10000",
	"G": "01110/10001/10000/10111/10001/10001/01110",
	"H": "10001/10001/10001/11111/10001/10001/10001",
	"I": "11111/00100/00100/00100/00100/00100/11111",
	"J": "00111/00010/00010/00010/00010/10010/01100",
	"K": "10001/10010/10100/11000/10100/10010/10001",
	"L": "10000/10000/10000/10000/10000/10000/11111",
	"M": "10001/11011/10101/10101/10001/10001/10001",
	"N": "10001/11001/10101/10011/10001/10001/10001",
	"O": "01110/10001/10001/10001/10001/10001/01110",
	"P": "11110/10001/10001/11110/10000/10000/10000",
	"Q": "01110/10001/10001/10001/10101/10011/01101",
	"R": "11110/10001/10001/11110/10100/10010/10001",
	"S": "01111/10000/10000/01110/00001/00001/11110",
	"T": "11111/00100/00100/00100/00100/00100/00100",
	"U": "10001/10001/10001/10001/10001/10001/01110",
	"V": "10001/10001/10001/10001/10001/01010/00100",
	"W": "10001/10001/10001/10101/10101/11011/10001",
	"X": "10001/10001/01010/00100/01010/10001/10001",
	"Y": "10001/10001/01010/00100/00100/00100/00100",
	"Z": "11111/00001/00010/00100/01000/10000/11111",
	"0": "01110/10001/10011/10101/11001/10001/01110",
	"1": "00100/01100/00100/00100/00100/00100/01110",
	"2": "01110/10001/00001/00010/00100/01000/11111",
	"3": "11110/00001/00001/01110/00001/00001/11110",
	"4": "00010/00110/01010/10010/11111/00010/00010",
	"5": "11111/10000/11110/00001/00001/10001/01110",
	"6": "00110/01000/10000/11110/10001/10001/01110",
	"7": "11111/00001/00010/00100/01000/01000/01000",
	"8": "01110/10001/10001/01110/10001/10001/01110",
	"9": "01110/10001/10001/01111/00001/00010/01100",
	".": "00000/00000/00000/00000/00000/01100/01100",
	",": "00000/00000/00000/00000/01100/01100/01000",
	":": "00000/01100/01100/00000/01100/01100/00000",
	"!": "00100/00100/00100/00100/00100/00000/00100",
	"?": "01110/10001/00001/00110/00100/00000/00100",
	"'": "00100/00100/00000/00000/00000/00000/00000",
	"-": "00000/00000/00000/11111/00000/00000/00000",
	"/": "00001/00010/00010/00100/01000/01000/10000",
	"\"": "01010/01010/00000/00000/00000/00000/00000",
	"(": "00010/00100/01000/01000/01000/00100/00010",
	")": "01000/00100/00010/00010/00010/00100/01000",
	"*": "00000/01010/00100/11111/00100/01010/00000",
	"+": "00000/00100/00100/11111/00100/00100/00000",
	"=": "00000/00000/11111/00000/11111/00000/00000",
	" ": "00000/00000/00000/00000/00000/00000/00000",
}

const ATLAS_COLS := 12
const CELL_W := 6
const CELL_H := 8


static func _ensure_font() -> void:
	if _font_tex != null:
		return
	var keys: Array = GLYPHS.keys()
	keys.sort()
	var rows: int = int(ceil(float(keys.size()) / float(ATLAS_COLS)))
	var img: Image = Image.create(ATLAS_COLS * CELL_W, rows * CELL_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in range(keys.size()):
		var ch: String = keys[i]
		var col: int = i % ATLAS_COLS
		var row: int = i / ATLAS_COLS
		_glyph_index[ch] = Vector2i(col * CELL_W, row * CELL_H)
		var lines: PackedStringArray = String(GLYPHS[ch]).split("/")
		for y in range(min(7, lines.size())):
			var bits: String = lines[y]
			for x in range(min(5, bits.length())):
				if bits[x] == "1":
					img.set_pixel(col * CELL_W + x, row * CELL_H + y, Color(1, 1, 1, 1))
	_font_tex = ImageTexture.create_from_image(img)


static func font_atlas() -> Texture2D:
	_ensure_font()
	return _font_tex


static func glyph_cell(ch: String) -> Vector2i:
	_ensure_font()
	var key: String = ch.to_upper()
	if _glyph_index.has(key):
		return _glyph_index[key]
	return Vector2i(-1, -1)


static func text_width(s: String) -> int:
	return max(0, s.length() * 6 - 1)
