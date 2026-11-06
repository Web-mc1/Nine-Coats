extends Node2D

const Art = preload("res://scripts/Art.gd")

var text: String = ""
var tint: Color = Color(1, 1, 1, 1)
var centered: bool = false
var shadow: bool = true
var pixel_scale: int = 1


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 20


func set_text(value: String) -> void:
	if text == value:
		return
	text = value
	queue_redraw()


func _draw() -> void:
	if text == "":
		return
	var atlas: Texture2D = Art.font_atlas()
	var origin_x: float = 0.0
	if centered:
		origin_x = -float(Art.text_width(text) * pixel_scale) / 2.0
	var step: int = 6 * pixel_scale
	var size_box: Vector2 = Vector2(5 * pixel_scale, 7 * pixel_scale)
	for i in range(text.length()):
		var cell: Vector2i = Art.glyph_cell(text[i])
		if cell.x < 0:
			continue
		var at: Vector2 = Vector2(origin_x + i * step, 0.0)
		var src: Rect2 = Rect2(Vector2(cell.x, cell.y), Vector2(5, 7))
		if shadow:
			draw_texture_rect_region(atlas, Rect2(at + Vector2(1.0, 1.0), size_box), src, Color(0, 0, 0, 0.55))
		draw_texture_rect_region(atlas, Rect2(at, size_box), src, tint)
