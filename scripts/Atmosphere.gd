extends Node2D

# Rain on the glass and steam off the pot: the two small motions that make the
# room feel lived in. Everything else in the inn is still.

const Art = preload("res://scripts/Art.gd")

const POT_POS := Vector2(28.0, 112.0)

var _t: float = 0.0
var _drops: Array = []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_seed_drops()


func _seed_drops() -> void:
	_drops.clear()
	for i in range(30):
		_drops.append({
			"x": float(Art.WIN_X + 3 + randi() % (Art.WIN_W - 6)),
			"y": float(Art.WIN_Y + randi() % Art.WIN_H),
			"v": 22.0 + randf() * 26.0,
			"l": 2 + randi() % 3,
		})


func _process(delta: float) -> void:
	_t += delta
	for d in _drops:
		d["y"] = float(d["y"]) + float(d["v"]) * delta
		if float(d["y"]) > float(Art.WIN_Y + Art.WIN_H):
			d["y"] = float(Art.WIN_Y - 4)
			d["x"] = float(Art.WIN_X + 3 + randi() % (Art.WIN_W - 6))
	queue_redraw()


func _draw() -> void:
	var top: int = Art.WIN_Y
	var bottom: int = Art.WIN_Y + Art.WIN_H
	# rain sliding down the window
	for d in _drops:
		var x: float = float(d["x"])
		var y: float = float(d["y"])
		for k in range(int(d["l"])):
			var py: int = int(floor(y)) + k
			if py > top and py < bottom:
				draw_rect(Rect2(Vector2(floor(x) + k * 0.4, float(py)), Vector2(1, 1)), Color(0.76, 0.85, 0.95, 0.55))
	# steam over the stew, drifting and fading
	for i in range(4):
		var phase: float = fmod(_t * 0.42 + i * 0.25, 1.0)
		var sx: float = POT_POS.x + sin(_t * 1.7 + i * 1.3) * 2.0
		var sy: float = POT_POS.y - phase * 18.0
		var a: float = 0.30 * (1.0 - phase)
		draw_rect(Rect2(Vector2(floor(sx), floor(sy)), Vector2(2, 2)), Color(0.96, 0.93, 0.86, a))
		draw_rect(Rect2(Vector2(floor(sx) + 1, floor(sy) + 2), Vector2(1, 1)), Color(0.96, 0.93, 0.86, a * 0.7))
