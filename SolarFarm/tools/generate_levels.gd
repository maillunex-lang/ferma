extends SceneTree
## Offline level generator for levels 11..500.
##
## Every level is built deterministically from its number (board shape,
## colours, weeds, ice, goals) and then CALIBRATED: the greedy bot plays it
## several times without helpers and the move limit is adjusted until the
## level is reliably winnable but not trivial. Star thresholds are derived
## from the measured result. Output: JSON list of levels.
##
## Usage: godot --headless --path . -s tools/generate_levels.gd -- <first> <last> <out.json>

const CHAPTERS := [
	"Солнечная долина", "Медовый луг", "Тыквенная грядка", "Яблоневая роща", "Ягодная поляна",
	"Мельничный холм", "Тихий пруд", "Подсолнуховое поле", "Грибной лес", "Ярмарка урожая",
	"Клубничный берег", "Виноградная терраса", "Морковные холмы", "Пасека", "Ромашковый луг",
	"Кукурузный лабиринт", "Черничный бор", "Вишнёвый сад", "Овечье пастбище", "Радужный ручей",
	"Звёздная опушка", "Осенний сад", "Зимний огород", "Весенняя капель", "Большой фестиваль",
]
const HELPERS := ["rooster", "squirrel", "hedgehog", "bee"]
const GAMES := 6

var rng := RandomNumberGenerator.new()
var first_ice_level := 13


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args[0] == "debug":
		var lv := build_level(int(args[1]))
		print("mask ", lv.mask, "\nweeds ", lv.weeds, "\nice ", lv.ice, "\ngoals ", lv.goals, " colors ", lv.colors)
		lv.moves = 80
		for i in 6:
			var r := Match3Bot.play_level(lv, int(args[1]) * 131 + i * 17)
			print("won=", r.won, " weeds_left=", r.weeds_left, " ice_left=", r.ice_left, " left=", r.moves_left)
		quit()
		return
	var first := int(args[0])
	var last := int(args[1])
	var out_path: String = args[2]
	var levels := []
	var t0 := Time.get_ticks_msec()
	for n in range(first, last + 1):
		var lv := build_level(n)
		calibrate(lv)
		levels.append(lv)
		print("L%d moves=%d stars=%d/%d win=%s left=%.1f goals=%s shape=%s (%ds)" % [n, lv.moves, lv.stars.two, lv.stars.three,
			lv._win, lv._left, _goal_str(lv), lv._shape, (Time.get_ticks_msec() - t0) / 1000])
		lv.erase("_win")
		lv.erase("_left")
		lv.erase("_shape")
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(levels, " "))
	f.close()
	quit()


func _goal_str(lv: Dictionary) -> String:
	var parts := []
	for g in lv.goals:
		parts.append("%s%s:%d" % [g.type, str(g.colors) if g.type == "collect" else "", g.target])
	return ",".join(parts)


# ------------------------------------------------------------------ shapes

func shape_mask(kind: String) -> Array:
	var m := {}
	var add := func(x: int, y: int) -> void:
		m[Vector2i(x, y)] = true
	match kind:
		"full":
			pass
		"corners1":
			for p in [[0, 0], [7, 0], [0, 7], [7, 7]]:
				add.call(p[0], p[1])
		"cross":  # 2x2 bites from every corner
			for x in [0, 1, 6, 7]:
				for y in [0, 1, 6, 7]:
					add.call(x, y)
		"plus_wide":
			for x in [0, 7]:
				for y in [0, 1, 6, 7]:
					add.call(x, y)
		"diamond":
			for x in 8:
				for y in 8:
					if absf(x - 3.5) + absf(y - 3.5) > 5.0:
						add.call(x, y)
		"hole":
			for x in [3, 4]:
				for y in [3, 4]:
					add.call(x, y)
		"ring":
			for x in [3, 4]:
				for y in [3, 4]:
					add.call(x, y)
			for p in [[0, 0], [7, 0], [0, 7], [7, 7]]:
				add.call(p[0], p[1])
		"hourglass":
			for y in [3, 4]:
				for x in [0, 1, 6, 7]:
					add.call(x, y)
		"side_notch":
			for y in [3, 4]:
				add.call(0, y)
				add.call(7, y)
		"top_notch":
			for x in [3, 4]:
				add.call(x, 0)
		"pillars":
			for y in [0, 1, 6, 7]:
				add.call(3, y)
				add.call(4, y)
		"arch":
			for x in [0, 1, 6, 7]:
				for y in [6, 7]:
					add.call(x, y)
			for x in [3, 4]:
				add.call(x, 7)
		"heart":
			for p in [[0, 0], [3, 0], [4, 0], [7, 0], [0, 6], [0, 7], [1, 7], [7, 6], [7, 7], [6, 7], [2, 7], [5, 7]]:
				add.call(p[0], p[1])
		"tower":
			for x in [0, 7]:
				for y in 8:
					if y < 2 or y > 5:
						add.call(x, y)
		"steps":
			for p in [[0, 0], [1, 0], [0, 1], [7, 0], [6, 0], [7, 1], [0, 7], [7, 7]]:
				add.call(p[0], p[1])
		"windows":
			for p in [[2, 2], [5, 2], [2, 5], [5, 5]]:
				add.call(p[0], p[1])
		"random_sym":
			var k := rng.randi_range(2, 5)
			for i in k:
				var x := rng.randi_range(0, 3)
				var y := rng.randi_range(0, 7)
				add.call(x, y)
				add.call(7 - x, y)
	var out := []
	for p in m:
		out.append([p.x, p.y])
	return out


func pick_shape(n: int, d: float) -> String:
	if n % 10 == 1 and n < 60:
		return "full"
	var kinds := ["full", "corners1", "cross", "plus_wide", "diamond", "hole", "ring", "hourglass", "side_notch",
		"top_notch", "pillars", "arch", "heart", "tower", "steps", "windows", "random_sym"]
	# Full boards become rarer as the game progresses.
	if rng.randf() < 0.3 - 0.25 * d:
		return "full"
	return kinds[rng.randi_range(1, kinds.size() - 1)]


# ------------------------------------------------------------------ level

func build_level(n: int) -> Dictionary:
	rng.seed = hash("solar-farm-level-%d" % n)
	var d := clampf((n - 11) / 489.0, 0.0, 1.0)
	var hard := n % 10 == 0
	var breather := n % 10 == 3 or n % 10 == 7
	var shape := pick_shape(n, d)
	var mask := shape_mask(shape)
	var masked := {}
	for c in mask:
		masked[Vector2i(c[0], c[1])] = true
	var free_cells := []
	for x in 8:
		for y in 8:
			if not masked.has(Vector2i(x, y)):
				free_cells.append(Vector2i(x, y))

	var five_colors := n < 25 or breather or rng.randf() < 0.18
	var colors := [0, 1, 2, 3, 4, 5]
	if five_colors:
		colors.remove_at(rng.randi_range(0, 5))

	# Obstacles, placed mirror-symmetric for a tidy look.
	var weeds := []
	var ice := []
	var used := {}
	var want_weeds := n >= 11 and rng.randf() < 0.35 + 0.25 * d
	var want_ice := n >= first_ice_level and rng.randf() < 0.35 + 0.3 * d
	if breather:
		want_ice = want_ice and rng.randf() < 0.5
		want_weeds = want_weeds and rng.randf() < 0.5
	if want_weeds:
		var pairs := rng.randi_range(2, 3 + int(3 * d) + (1 if hard else 0))
		for p in _symmetric_cells(free_cells, used, pairs, 1, 7):
			var hp := 2 if rng.randf() < 0.3 * d else 1
			weeds.append([p.x, p.y, hp] if hp > 1 else [p.x, p.y])
	if want_ice:
		var pairs := rng.randi_range(3, 4 + int(4 * d) + (1 if hard else 0))
		for p in _symmetric_cells(free_cells, used, pairs, 0, 7, true):
			var hp := 2 if rng.randf() < 0.25 * d else 1
			ice.append([p.x, p.y, hp] if hp > 1 else [p.x, p.y])

	var goals := []
	if not weeds.is_empty():
		goals.append({"type": "weeds", "colors": [], "target": weeds.size()})
	if not ice.is_empty():
		goals.append({"type": "ice", "colors": [], "target": ice.size()})
	var n_collect := 1
	if goals.is_empty():
		n_collect = 1 if rng.randf() < 0.45 else 2
	elif rng.randf() < 0.35:
		n_collect = 0
	var palette := colors.duplicate()
	for i in n_collect:
		var c: int = palette.pop_at(rng.randi_range(0, palette.size() - 1))
		var base := 14 if n_collect == 1 else 10
		var target := base + int(rng.randi_range(0, 4) + d * (8 if n_collect == 1 else 5))
		if hard:
			target += 3
		goals.append({"type": "collect", "colors": [c], "target": target})
	if goals.size() < 3 and rng.randf() < 0.18 + 0.1 * d:
		goals.append({"type": "rockets", "colors": [], "target": 2 + int(rng.randi_range(0, 1) + d * 2)})
	elif five_colors and goals.size() < 3 and rng.randf() < 0.07:
		goals.append({"type": "rainbow", "colors": [], "target": 1})
	if goals.is_empty():
		goals.append({"type": "collect", "colors": [colors[0]], "target": 16})

	var extras := [
		{"type": "no_helpers", "target": 0, "text": "Пройти без помощников"},
		{"type": "specials_created", "target": 2, "text": "Создать 2 усилителя"},
		{"type": "cascade", "target": 3, "text": "Цепочка из 3 волн за один ход"},
		{"type": "rockets_created", "target": 1, "text": "Создать ракету"},
		{"type": "baskets_created", "target": 1, "text": "Создать корзину (Т или Г)"},
		{"type": "specials_created", "target": 3, "text": "Создать 3 усилителя"},
	]
	if n % 25 == 0:
		extras = [{"type": "booster_combo", "target": 1, "text": "Поменять местами два усилителя"}]
	var extra: Dictionary = extras[rng.randi_range(0, extras.size() - 1)]

	var chapter := (n - 1) / 20
	var reward := {"coins": 80 + mini(n, 200) / 4 + (120 if hard else 0), "helpers": {}, "three_star": {}}
	if n % 10 == 5:
		reward.helpers[HELPERS[(n / 10) % 4]] = 1
	if n % 50 == 0:
		for h in HELPERS:
			reward.helpers[h] = 1
	if n % 4 == 0:
		reward.three_star[HELPERS[(n / 4) % 4]] = 1

	var tip := ""
	if n == first_ice_level or (not ice.is_empty() and n == first_ice_level):
		tip = "Новинка — лёд! Он тает, когда на нём исчезает плод. Собирай совпадения прямо на льду."
	elif shape != "full" and n == 11:
		tip = "Поля бывают разной формы. Плоды падают сквозь пустые места — следи за краями!"

	var moves := 16 + int(d * 4)
	for g in goals:
		match g.type:
			"collect":
				moves += int(g.target / 3.0)
			"weeds":
				moves += int(g.target * 0.6)
			"ice":
				moves += int(g.target * 0.45)
			"rockets":
				moves += g.target * 2
			"rainbow":
				moves += 6
	return {
		"id": n, "name": CHAPTERS[mini(chapter, CHAPTERS.size() - 1)], "chapter": chapter + 1,
		"moves": moves, "colors": colors, "goals": goals,
		"stars": {"two": 3, "three": 6, "extra": extra},
		"reward": reward, "tip": tip, "mask": mask, "weeds": weeds, "ice": ice,
		"hard": hard, "_shape": shape,
	}


## Ice needs a possible line of 3 through its own cell; a weed needs such a
## line through one of its neighbours. This keeps every obstacle clearable by
## ordinary matches (not only by boosters).
func _reachable(p: Vector2i, free_cells: Array, used: Dictionary, need_line: bool) -> bool:
	if need_line:
		return _line3(p, free_cells, used)
	for d in BoardModel.DIRS:
		var n: Vector2i = p + d
		if free_cells.has(n) and not used.has(n) and _line3(n, free_cells, used):
			return true
	return false


func _line3(p: Vector2i, free_cells: Array, used: Dictionary) -> bool:
	for axis in [Vector2i(1, 0), Vector2i(0, 1)]:
		for off in range(-2, 1):
			var ok := true
			for k in 3:
				var c: Vector2i = p + axis * (off + k)
				if c != p and (not free_cells.has(c) or used.has(c)):
					ok = false
					break
			if ok:
				return true
	return false


func _symmetric_cells(free_cells: Array, used: Dictionary, pairs: int, min_y: int, max_y: int, need_line := false) -> Array:
	var out := []
	var tries := 0
	while out.size() < pairs * 2 and tries < 200:
		tries += 1
		var p: Vector2i = free_cells[rng.randi_range(0, free_cells.size() - 1)]
		if p.x > 3 or p.y < min_y or p.y > max_y:
			continue
		var q := Vector2i(7 - p.x, p.y)
		if used.has(p) or used.has(q) or not free_cells.has(q):
			continue
		if not (_reachable(p, free_cells, used, need_line) and _reachable(q, free_cells, used, need_line)):
			continue
		used[p] = true
		used[q] = true
		out.append(p)
		out.append(q)
	return out


## Measures how many moves the bot needs (with an unlimited budget), then
## sets the limit so that the bot finishes with ~55% of moves to spare (45% on hard levels) —
## roughly what the hand-made levels 1-10 give. People play less efficiently
## than the bot, so this keeps levels winnable without helpers but not trivial.
## Star thresholds come from the expected number of spare moves.
func calibrate(lv: Dictionary) -> void:
	var ratio := 0.45 if lv.hard else 0.55
	if int(lv.id) % 10 == 3 or int(lv.id) % 10 == 7:
		ratio = 0.62
	for attempt in 6:
		var used := []
		var probe := lv.duplicate(true)
		probe.moves = 80
		for i in GAMES:
			var r := Match3Bot.play_level(probe, int(lv.id) * 131 + i * 17 + attempt * 1009)
			if r.won:
				used.append(80 - r.moves_left)
		if used.size() == GAMES:
			used.sort()
			var avg := 0.0
			for u in used:
				avg += u
			avg /= used.size()
			var moves := maxi(int(ceil(avg / (1.0 - ratio))), used[-2] + 3)
			if moves > 50:
				_simplify(lv)
				continue
			lv.moves = maxi(moves, 18 if not lv.hard else 16)
			var left: float = lv.moves - avg
			lv.stars.two = maxi(1, int(left * 0.4))
			lv.stars.three = maxi(lv.stars.two + 1, int(round(left * 0.8)))
			lv._win = "%d/%d" % [GAMES, GAMES]
			lv._left = left
			return
		# The bot could not finish within 80 moves: simplify the level.
		_simplify(lv)
	if not lv.get("_stripped", false):
		# Last resort: drop obstacles, keep a plain collection level.
		lv._stripped = true
		lv.weeds = []
		lv.ice = []
		var keep := []
		for g in lv.goals:
			if g.type == "collect":
				keep.append(g)
		if keep.is_empty():
			keep.append({"type": "collect", "colors": [lv.colors[0]], "target": 14})
		lv.goals = keep
		calibrate(lv)
		lv.erase("_stripped")
		return
	push_error("level %d could not be calibrated" % lv.id)
	lv._win = "FAIL"
	lv._left = 0.0


func _simplify(lv: Dictionary) -> void:
	var keep := []
	for g in lv.goals:
		if g.type == "rainbow":
			continue
		if g.type == "collect":
			g.target = maxi(6, int(g.target * 0.75))
		elif g.type == "rockets":
			g.target = maxi(1, g.target - 1)
		keep.append(g)
	lv.goals = keep
	if lv.weeds.size() > 2:
		lv.weeds.resize(lv.weeds.size() - 2)
	if lv.ice.size() > 2:
		lv.ice.resize(lv.ice.size() - 2)
	var final := []
	for g in lv.goals:
		if g.type == "weeds":
			g.target = lv.weeds.size()
		elif g.type == "ice":
			g.target = lv.ice.size()
		if g.target > 0:
			final.append(g)
	lv.goals = final
	if lv.goals.is_empty():
		lv.goals.append({"type": "collect", "colors": [lv.colors[0]], "target": 12})
