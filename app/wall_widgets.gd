class_name WallWidgets
extends Node3D
## Round 6-2 — the wall widgets' owner: builds Jon's five wall panels at their default
## spots (or where he left them), feeds them REAL data (bench overview/model/library,
## hub link/brain, the clock), and persists the layout to user://wall_layout.json —
## the same versioned-store pattern as the world placements. Refresh runs on a 1 s
## timer and each panel repaints only when its lines actually change.

const STORE_PATH := "user://wall_layout.json"
const PICTURE_PATHS := [
	"res://pictures/vista-coast.png",
	"res://pictures/vista-lake.png",
	"res://pictures/vista-valley.png",
	"res://pictures/suit-01-hero.png",
	"res://pictures/suit-04-heroine.png",
	"res://pictures/v2-vision-solid.png",
]
# id, size, wall, u, v, default state (ring index into WallPanel.TYPES / pictures)
const DEFAULTS := [
	["w1", "large", "left", -2.6, 2.0, 0],    # OVERVIEW
	["w2", "small", "left", -2.6, 1.02, 4],   # CLOCK
	["w3", "small", "left", -0.85, 1.02, 5],  # PICTURE (first)
	["w4", "large", "right", -2.6, 2.0, 1],   # MODEL
	["w5", "small", "right", -0.85, 2.0, 3],  # HUB
]

var _bench: Node
var _panels: Array[WallPanel] = []
var _pictures: Array = []

func build(bench: Node) -> void:
	_bench = bench
	for p in PICTURE_PATHS:
		if ResourceLoader.exists(p):
			_pictures.append(p)
	var saved := _load_store()
	for d in DEFAULTS:
		var panel := WallPanel.new()
		panel.pid = String(d[0])
		panel.size_kind = String(d[1])
		add_child(panel)
		panel.build(_pictures)
		var spot: Dictionary = saved.get(panel.pid, {})
		if not spot.is_empty():
			panel.state = int(spot.get("state", int(d[5])))
			panel.set_spot(String(spot.get("wall", String(d[2]))), float(spot.get("u", float(d[3]))), float(spot.get("v", float(d[4]))))
			panel._apply_content()
		else:
			panel.state = int(d[5])
			panel.set_spot(String(d[2]), float(d[3]), float(d[4]))
			panel._apply_content()
		panel.changed.connect(_on_panel_changed)
		_panels.append(panel)
	_refresh_all()
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_refresh_all)
	add_child(timer)

func _on_panel_changed(_panel: WallPanel) -> void:
	_save_store()
	_refresh_all()

func _refresh_all() -> void:
	if _bench == null:
		return
	for panel in _panels:
		match panel.type_name():
			"OVERVIEW":
				panel.set_lines(_bench.overview_lines())
			"MODEL":
				panel.set_lines(_bench.model_lines())
			"LIBRARY":
				panel.set_lines(_bench.library_lines())
			"HUB":
				panel.set_lines(["ATLAS LINK", "LINK — %s" % (Hub.link if Hub.link != "" else "—"), "BRAIN — %s" % (Hub.brain if Hub.brain != "" else "—")])
			"CLOCK":
				var t := Time.get_time_dict_from_system()
				var d := Time.get_date_dict_from_system()
				panel.set_lines(["%02d:%02d" % [int(t["hour"]), int(t["minute"])],
					"%04d-%02d-%02d" % [int(d["year"]), int(d["month"]), int(d["day"])]])

func _save_store() -> void:
	var out := {"version": 1, "panels": {}}
	for panel in _panels:
		out["panels"][panel.pid] = panel.spot()
	var f := FileAccess.open(STORE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(out))
		f.close()

func _load_store() -> Dictionary:
	if not FileAccess.file_exists(STORE_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STORE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	if int((parsed as Dictionary).get("version", 0)) != 1:
		return {}
	return (parsed as Dictionary).get("panels", {})
