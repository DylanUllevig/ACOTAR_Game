extends Node
## Everything about Feyre's run. Split into two halves on save:
##   carry_over: what a later book imports (power, inventory, journal, canon choices)
##   progress:   where she is in this book (chapter, region, flags, hp, explored map)

signal changed
signal toast(text: String)
signal inventory_changed
signal hotbar_changed(index: int)
signal hp_changed(old_hp: int, new_hp: int)
signal item_gained(id: String, n: int)

const GAME_ID := "acotar_book1"
## Flags that are canon choices worth remembering in later books.
const CARRY_FLAGS := ["doe_saved", "ch02_snapped", "ch03_isaac_barn", "ch03_kindness", "ch03_acolyte_done", "has_paint_tins"]
## Explored-map grid cell, in world pixels.
const MAP_CELL := 64

var chapter = 1
var region = "forest"
var spawn = "start"
var pos: Variant = null            # exact spot to resume at (Vector2), or null for the spawn point
var hour = 13.0
var tier = 0
var max_hp = 30
var hp = 30
var damage_mult = 1.0
var speed_mult = 1.0
var draw_mult = 1.0
var coins = 0
var inventory: Array = []          # inventory_size entries: null or {"id": String, "n": int}
var hotbar_index = 0
var flags = {}
var journal: Array = []
var objective = ""
var explored = {}                  # region id -> PackedByteArray, one byte per MAP_CELL cell
var places = {}                    # location id -> true once visited or heard of
var stats = {}
var playtime = 0.0
var outfit = "feyre"               # Feyre's walking sprite sheet (actors/<outfit>.png) and portrait set


func _process(delta: float) -> void:
	playtime += delta


func _fresh_stats() -> Dictionary:
	return {"hunts_won": 0, "damage_dealt": 0, "arrows_shot": 0, "arrows_recovered": 0,
		"hares_hunted": 0, "food_eaten": 0, "rose_hips_picked": 0}


func new_game() -> void:
	chapter = 1
	region = "forest"
	spawn = "start"
	pos = null
	hour = 13.0
	coins = 0
	flags = {}
	journal = []
	objective = ""
	explored = {}
	places = {"mortal_forest": true, "archeron_cottage": true, "mortal_village": true}
	stats = _fresh_stats()
	playtime = 0.0
	outfit = "feyre"
	hotbar_index = 0
	apply_tier(0, false)
	hp = max_hp
	_empty_inventory()
	for e in DB.starting_inventory:
		inventory[int(e.slot)] = {"id": String(e.id), "n": int(e.n)}
	inventory_changed.emit()
	changed.emit()


# ------------------------------------------------------------------ power
func apply_tier(n: int, announce := true) -> void:
	var t = DB.tier(n)
	if t.is_empty():
		return
	var old_max = max_hp
	tier = n
	max_hp = int(t.max_hp)
	damage_mult = float(t.get("damage", 1.0))
	speed_mult = float(t.get("speed", 1.0))
	draw_mult = float(t.get("draw", 1.0))
	hp = clamp(hp + max(0, max_hp - old_max), 1, max_hp)
	if announce:
		toast.emit("Power rises: %s. Max HP %d to %d." % [t.name, old_max, max_hp])
	changed.emit()


func tier_progress() -> float:
	## 0..1 position on the whole-book power curve, for the meter.
	var top = 0
	for t in DB.tiers:
		top = max(top, int(t.tier))
	return float(tier) / float(max(1, top))


static func score_for(t: Dictionary) -> int:
	return int(round(float(t.max_hp) * float(t.get("damage", 1.0)) * float(t.get("speed", 1.0)) * float(t.get("draw", 1.0))))


func power_score() -> int:
	## A single number so the player can feel the gap between Tier 0 and Made Fae.
	return int(round(max_hp * damage_mult * speed_mult * draw_mult))


# --------------------------------------------------------------------- hp
func set_hp(v: int) -> void:
	var old = hp
	hp = clamp(v, 0, max_hp)
	if hp != old:
		hp_changed.emit(old, hp)
		changed.emit()


func heal(n: int) -> void:
	set_hp(hp + n)


# -------------------------------------------------------------- inventory
func inv_size() -> int:
	return DB.inventory_size


func hotbar_size() -> int:
	return DB.hotbar_size


func _empty_inventory() -> void:
	inventory = []
	inventory.resize(inv_size())
	for i in inventory.size():
		inventory[i] = null


func slot(i: int) -> Variant:
	if i < 0 or i >= inventory.size():
		return null
	return inventory[i]


func set_slot(i: int, stack: Variant) -> void:
	if i < 0 or i >= inventory.size():
		return
	if stack != null and (int(stack.n) <= 0 or String(stack.id) == ""):
		stack = null
	inventory[i] = stack
	inventory_changed.emit()
	changed.emit()


func stack_limit(id: String) -> int:
	return int(DB.items.get(id, {}).get("stack", 1))


func count(id: String) -> int:
	var n = 0
	for s in inventory:
		if s != null and s.id == id:
			n += int(s.n)
	return n


func has_item(id: String, n := 1) -> bool:
	return count(id) >= n


func space_for(id: String) -> int:
	var lim = stack_limit(id)
	var room = 0
	for s in inventory:
		if s == null:
			room += lim
		elif s.id == id:
			room += max(0, lim - int(s.n))
	return room


## Adds up to n of an item: tops up existing stacks first, then fills empty
## slots (hotbar first, like the bag fills from the top). Returns how many did
## NOT fit. Announces with a toast unless silent.
func add_item(id: String, n := 1, silent := false) -> int:
	if not DB.items.has(id):
		push_error("Unknown item " + id)
		return n
	var left = n
	var lim = stack_limit(id)
	for i in inventory.size():
		if left <= 0:
			break
		var s = inventory[i]
		if s != null and s.id == id and int(s.n) < lim:
			var put = min(left, lim - int(s.n))
			s.n = int(s.n) + put
			left -= put
	for i in inventory.size():
		if left <= 0:
			break
		if inventory[i] == null:
			var put2 = min(left, lim)
			inventory[i] = {"id": id, "n": put2}
			left -= put2
	var added = n - left
	if added > 0 and not silent:
		item_gained.emit(id, added)  # the HUD shows a pickup notice with the icon
	if left > 0 and not silent:
		toast.emit("No room in your satchel for %s." % DB.items[id].name)
	inventory_changed.emit()
	changed.emit()
	return left


## Removes n of an item, taking from the bag before the hotbar and from the end
## of the bag first, so what the player arranged on the hotbar lasts longest.
## Removes nothing and returns false when there are fewer than n.
func remove_item(id: String, n := 1) -> bool:
	if count(id) < n:
		return false
	var left = n
	var order: Array = []
	for i in range(inventory.size() - 1, hotbar_size() - 1, -1):
		order.append(i)
	for i in range(hotbar_size() - 1, -1, -1):
		order.append(i)
	for i in order:
		if left <= 0:
			break
		var s = inventory[i]
		if s != null and s.id == id:
			var take = min(left, int(s.n))
			s.n = int(s.n) - take
			left -= take
			if int(s.n) <= 0:
				inventory[i] = null
	inventory_changed.emit()
	changed.emit()
	return true


## Moves the stack in slot a onto slot b: merges when they match (up to the
## stack limit), otherwise swaps.
func move_slot(a: int, b: int) -> void:
	if a == b or a < 0 or b < 0 or a >= inventory.size() or b >= inventory.size():
		return
	var sa = inventory[a]
	var sb = inventory[b]
	if sa != null and sb != null and sa.id == sb.id:
		var lim = stack_limit(sa.id)
		var put = min(int(sa.n), lim - int(sb.n))
		sb.n = int(sb.n) + put
		sa.n = int(sa.n) - put
		if int(sa.n) <= 0:
			inventory[a] = null
	else:
		inventory[a] = sb
		inventory[b] = sa
	inventory_changed.emit()
	changed.emit()


func select_hotbar(i: int) -> void:
	i = posmod(i, hotbar_size())
	if i == hotbar_index:
		return
	hotbar_index = i
	hotbar_changed.emit(i)


func selected_stack() -> Variant:
	return slot(hotbar_index)


func selected_item_id() -> String:
	var s = selected_stack()
	return "" if s == null else String(s.id)


func item_def(id: String) -> Dictionary:
	return DB.items.get(id, {})


## Total of the ammo a bow-type item fires.
func ammo_for(id: String) -> int:
	var d = item_def(id)
	if d.get("use", "") != "bow":
		return 0
	return count(String(d.get("ammo", "arrow")))


# ------------------------------------------------------------------ coins
func add_coins(n: int) -> void:
	coins = max(0, coins + n)
	if n != 0:
		toast.emit(("+%d" % n if n > 0 else "%d" % n) + " coin")
	changed.emit()


# ------------------------------------------------------------------ flags
func has_flag(f: String) -> bool:
	return bool(flags.get(f, false))


func set_flag(f: String, v := true) -> void:
	flags[f] = v
	changed.emit()


func unlock_lore(id: String) -> void:
	if id in journal or not DB.lore.has(id):
		return
	journal.append(id)
	toast.emit("Journal: " + DB.lore[id].title)
	changed.emit()


func set_objective(text: String) -> void:
	objective = text
	changed.emit()


func discover_place(id: String) -> void:
	if not places.has(id):
		places[id] = true
		changed.emit()


func bump(stat: String, n := 1) -> void:
	stats[stat] = int(stats.get(stat, 0)) + n


# ----------------------------------------------------------- explored map
func explored_grid(region_id: String, cells: Vector2i) -> PackedByteArray:
	var g: PackedByteArray = explored.get(region_id, PackedByteArray())
	if g.size() != cells.x * cells.y:
		g = PackedByteArray()
		g.resize(cells.x * cells.y)
		g.fill(0)
		explored[region_id] = g
	return g


## Marks every cell within radius of a world position as seen. Returns true if
## anything new was revealed.
func reveal(region_id: String, bounds: Rect2, world_pos: Vector2, radius: float) -> bool:
	var cells = Vector2i(ceili(bounds.size.x / MAP_CELL), ceili(bounds.size.y / MAP_CELL))
	var g = explored_grid(region_id, cells)
	var local = world_pos - bounds.position
	var c0 = Vector2i(floori((local.x - radius) / MAP_CELL), floori((local.y - radius) / MAP_CELL))
	var c1 = Vector2i(floori((local.x + radius) / MAP_CELL), floori((local.y + radius) / MAP_CELL))
	var changed_any = false
	for cy in range(max(0, c0.y), min(cells.y - 1, c1.y) + 1):
		for cx in range(max(0, c0.x), min(cells.x - 1, c1.x) + 1):
			var centre = Vector2((cx + 0.5) * MAP_CELL, (cy + 0.5) * MAP_CELL)
			if centre.distance_to(local) <= radius:
				var k = cy * cells.x + cx
				if g[k] == 0:
					g[k] = 1
					changed_any = true
	if changed_any:
		explored[region_id] = g
	return changed_any


# ------------------------------------------------------------ persistence
func _inventory_out() -> Array:
	var out: Array = []
	for s in inventory:
		out.append(null if s == null else {"id": s.id, "n": int(s.n)})
	return out


func carry_over_dict() -> Dictionary:
	var canon = {}
	for f in CARRY_FLAGS:
		if flags.has(f):
			canon[f] = flags[f]
	return {
		"tier": tier, "max_hp": max_hp, "coins": coins,
		"inventory": _inventory_out(), "journal": journal.duplicate(), "canon_choices": canon,
		"places": places.keys(), "stats": stats.duplicate(),
	}


func progress_dict() -> Dictionary:
	var ex = {}
	for k in explored:
		ex[k] = Marshalls.raw_to_base64(explored[k])
	var at = null
	var r = Router.current_region
	if r != null and is_instance_valid(r) and "player" in r and r.player != null and GameState.region == region:
		at = [snappedf(r.player.global_position.x, 0.1), snappedf(r.player.global_position.y, 0.1)]
	return {
		"chapter": chapter, "region": region, "spawn": spawn, "pos": at, "hour": hour, "hp": hp,
		"flags": flags.duplicate(), "objective": objective, "playtime": playtime,
		"explored": ex, "hotbar_index": hotbar_index, "outfit": outfit,
	}


func load_from(carry: Dictionary, progress: Dictionary) -> void:
	apply_tier(int(carry.get("tier", 0)), false)
	max_hp = int(carry.get("max_hp", max_hp))
	coins = int(carry.get("coins", 0))
	_empty_inventory()
	var inv: Array = carry.get("inventory", [])
	for i in min(inv.size(), inventory.size()):
		var s = inv[i]
		if s is Dictionary and DB.items.has(String(s.get("id", ""))) and int(s.get("n", 0)) > 0:
			inventory[i] = {"id": String(s.id), "n": int(s.n)}
	journal = Array(carry.get("journal", []))
	places = {}
	for p in carry.get("places", []):
		places[String(p)] = true
	stats = _fresh_stats()
	var st: Dictionary = carry.get("stats", {})
	for k in st:
		stats[k] = int(st[k])
	chapter = int(progress.get("chapter", 1))
	region = String(progress.get("region", "forest"))
	spawn = String(progress.get("spawn", "start"))
	var at = progress.get("pos", null)
	pos = Vector2(float(at[0]), float(at[1])) if at is Array and at.size() == 2 else null
	hour = float(progress.get("hour", 13.0))
	hp = clamp(int(progress.get("hp", max_hp)), 1, max_hp)
	flags = progress.get("flags", {})
	objective = String(progress.get("objective", ""))
	playtime = float(progress.get("playtime", 0.0))
	hotbar_index = clamp(int(progress.get("hotbar_index", 0)), 0, hotbar_size() - 1)
	outfit = String(progress.get("outfit", "feyre_spring" if chapter >= 6 else "feyre"))
	explored = {}
	var ex: Dictionary = progress.get("explored", {})
	for k in ex:
		explored[k] = Marshalls.base64_to_raw(String(ex[k]))
	inventory_changed.emit()
	changed.emit()
