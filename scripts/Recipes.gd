extends RefCounted

# Nine Coats -- the pantry.
#
# Five things keep in the kitchen through the winter, and any two of them make
# a dish. Five choose two is ten, so the whole menu is exactly the ten pairs:
# there is no recipe book, you learn it by cooking it. Every dish is cookable
# from the first night, and nothing is ever wasted -- a guest who gets the
# wrong bowl still eats it.

const INGREDIENTS: Array = [
	{"name": "MUSHROOM", "col": Color8(168, 126, 104)},
	{"name": "POTATO", "col": Color8(214, 190, 140)},
	{"name": "ONION", "col": Color8(206, 176, 196)},
	{"name": "THYME", "col": Color8(126, 158, 106)},
	{"name": "CHEESE", "col": Color8(242, 204, 110)},
]

const DISHES: Array = [
	{"name": "MUSHROOM POTAGE", "a": 0, "b": 1, "col": Color8(148, 116, 94), "price": 7},
	{"name": "MUSHROOM SOUP", "a": 0, "b": 2, "col": Color8(160, 128, 110), "price": 7},
	{"name": "THYME MUSHROOMS", "a": 0, "b": 3, "col": Color8(136, 126, 98), "price": 8},
	{"name": "MUSHROOM MELT", "a": 0, "b": 4, "col": Color8(198, 164, 112), "price": 8},
	{"name": "POTATO PORRIDGE", "a": 1, "b": 2, "col": Color8(222, 202, 172), "price": 6},
	{"name": "POTATO POTAGE", "a": 1, "b": 3, "col": Color8(212, 196, 148), "price": 6},
	{"name": "POTATO BAKE", "a": 1, "b": 4, "col": Color8(228, 198, 132), "price": 8},
	{"name": "ONION BROTH", "a": 2, "b": 3, "col": Color8(198, 190, 158), "price": 6},
	{"name": "ONION TART", "a": 2, "b": 4, "col": Color8(214, 180, 148), "price": 8},
	{"name": "HERB TOAST", "a": 3, "b": 4, "col": Color8(198, 186, 128), "price": 7},
]


static func count() -> int:
	return DISHES.size()


static func dish_name(id: int) -> String:
	if id < 0 or id >= DISHES.size():
		return ""
	return str(DISHES[id]["name"])


static func dish_col(id: int) -> Color:
	if id < 0 or id >= DISHES.size():
		return Color8(200, 200, 200)
	return DISHES[id]["col"]


static func dish_price(id: int) -> int:
	if id < 0 or id >= DISHES.size():
		return 0
	return int(DISHES[id]["price"])


static func ingredient_name(id: int) -> String:
	if id < 0 or id >= INGREDIENTS.size():
		return ""
	return str(INGREDIENTS[id]["name"])


static func ingredient_col(id: int) -> Color:
	if id < 0 or id >= INGREDIENTS.size():
		return Color8(200, 200, 200)
	return INGREDIENTS[id]["col"]


# Which dish a pair of ingredients makes. Every pair is legal, so this only
# returns -1 for a malformed request.
static func dish_for(a: int, b: int) -> int:
	for i in range(DISHES.size()):
		var d: Dictionary = DISHES[i]
		var da: int = int(d["a"])
		var db: int = int(d["b"])
		if (da == a and db == b) or (da == b and db == a):
			return i
	return -1
