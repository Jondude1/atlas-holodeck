extends XRController3D
## Controller logic. Both hands: grip_click grabs the model. Pointer hand (right):
## laser ray + trigger_click drive the UI panel. Action names come from the
## auto-generated openxr_action_map.tres (grip_click, trigger_click, aim_pose).

@export var pointer := false
@export var pointer_range := 4.0

var _held: Node = null
var _pressing := false
var _ptt_held := false
var _menu_down_ms := -1
const RESET_HOLD_MS := 800
var _last := Vector2.ZERO
@onready var _laser: Node3D = get_node_or_null("Laser")

func _ready() -> void:
	button_pressed.connect(_on_pressed)
	button_released.connect(_on_released)
	if _laser:
		_laser.visible = pointer

func _on_pressed(action: String) -> void:
	if action == "grip_click" and _held == null:
		var m := _nearest_grabbable()
		if m:
			_held = m
			m.begin_grab(self)
	elif action == "menu_button":
		_menu_down_ms = Time.get_ticks_msec()
	elif action == "trigger_click" and not pointer:
		# push-to-talk, primary controller hold: the LEFT trigger. Conflict-free: the left hand has no pointer role, grip = grab,
		# menu long-press = RESET FLOOR, and the right trigger stays the UI click. Works regardless of where anything is aimed.
		var vl := get_tree().get_first_node_in_group("voice") as VoiceLink
		if vl:
			_ptt_held = true
			vl.ptt_begin()
	elif action == "trigger_click" and pointer:
		var hit = _hit()
		if hit != null:
			_pressing = true
			_send_button(Vector2(hit.x, hit.y), true)
		else:
			# secondary PTT: the right trigger when aimed off the panel (on the panel it clicks UI)
			var v := get_tree().get_first_node_in_group("voice") as VoiceLink
			if v:
				_ptt_held = true
				v.ptt_begin()

func _on_released(action: String) -> void:
	if action == "menu_button":
		_menu_down_ms = -1
	if action == "grip_click" and _held:
		_held.end_grab(self)
		_held = null
	elif action == "trigger_click" and _pressing:
		_pressing = false
		_send_button(_last, false)
	elif action == "trigger_click" and _ptt_held:
		_ptt_held = false
		var v := get_tree().get_first_node_in_group("voice") as VoiceLink
		if v:
			v.ptt_end()

## With several models on the bench, the grip takes the nearest one within reach (not just the first in the tree).
func _nearest_grabbable() -> Node:
	var best: Node = null
	var best_d := INF
	for m in get_tree().get_nodes_in_group("grabbable"):
		if m.can_grab(self):
			var d: float = global_position.distance_to(m.global_transform * m.center_local)
			if d < best_d:
				best_d = d
				best = m
	return best

func _hit() -> Variant:
	var panel := get_tree().get_first_node_in_group("ui_panel")
	return panel.pick(global_position, -global_basis.z) if panel else null

func _process(_delta: float) -> void:
	# long-press (~0.8 s) of the left menu button = RESET FLOOR (fires once per hold)
	if _menu_down_ms >= 0 and Time.get_ticks_msec() - _menu_down_ms >= RESET_HOLD_MS:
		_menu_down_ms = -1
		XrBoot.reset_floor("menu long-press")
	if not pointer:
		return
	var hit = _hit()
	var length := pointer_range
	if hit != null and hit.z < pointer_range:
		length = hit.z
		var pos := Vector2(hit.x, hit.y)
		var ev := InputEventMouseMotion.new()
		ev.position = pos
		ev.global_position = pos
		ev.relative = pos - _last
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT if _pressing else 0
		get_tree().get_first_node_in_group("ui_panel").push(ev)
		_last = pos
	if _laser:
		_laser.scale.z = length
		_laser.position.z = -length * 0.5

func _send_button(pos: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = pos
	ev.global_position = pos
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	get_tree().get_first_node_in_group("ui_panel").push(ev)
