extends XRController3D
## Controller logic. Both hands: grip_click grabs the model. Pointer hand (right):
## laser ray + trigger_click drive the UI panel. Action names come from the
## auto-generated openxr_action_map.tres (grip_click, trigger_click, aim_pose).

@export var pointer := false
@export var pointer_range := 4.0

var _held: Node = null
var _pressing := false
var _ptt_held := false
var _ptt_by_ax := false
var _hover_model: Node = null
var _menu_down_ms := -1
const RESET_HOLD_MS := 800
var _last := Vector2.ZERO
@onready var _laser: Node3D = get_node_or_null("Laser")

func _ready() -> void:
	add_to_group("holodeck_hands")
	button_pressed.connect(_on_pressed)
	button_released.connect(_on_released)
	if _laser:
		_laser.visible = pointer

## Round 2 (R2-1): short, distinct haptic confirmations — grab, release,
## select, panel poke, materialize. No-op unless XR is actually live, so
## headless tests and the fallback camera never touch the API.
func buzz(duration := 0.03, amplitude := 0.4) -> void:
	if not XrBoot.ready_ok:
		return
	trigger_haptic_pulse("haptic", 0.0, amplitude, duration, 0.0)

func _on_pressed(action: String) -> void:
	if action == "grip_click" and (_held == null or not is_instance_valid(_held)):
		var m := _nearest_grabbable()
		if m:
			_held = m
			m.begin_grab(self)
	elif action == "menu_button":
		_menu_down_ms = Time.get_ticks_msec()
	elif action == "ax_button":
		# SPEC §5: "trigger (or A/X)". A (right) and X (left) are an additional hold-to-talk binding; neither is used for
		# anything else, so they never fight grip (grab), trigger (UI click / bench select) or menu.
		var va := get_tree().get_first_node_in_group("voice") as VoiceLink
		if va and not _ptt_held:
			_ptt_held = true
			_ptt_by_ax = true
			va.ptt_begin()
	elif action == "trigger_click" and not pointer:
		# push-to-talk, primary controller hold: the LEFT trigger. Conflict-free: the left hand has no pointer role, grip = grab,
		# menu long-press = RESET FLOOR, and the right trigger stays the UI click. Works regardless of where anything is aimed.
		var vl := get_tree().get_first_node_in_group("voice") as VoiceLink
		if vl:
			_ptt_held = true
			vl.ptt_begin()
	elif action == "trigger_click" and pointer:
		var hit = _hit()
		var parked: Node = _hover_model if _hover_model and _hover_model.is_parked() else null
		if hit == null and parked != null:
			# pointing at a parked model: the trigger pulls it back to centre (bench select) instead of talking
			get_tree().get_first_node_in_group("cad_bench").select(parked)
			buzz(0.04, 0.45)  # R2-1: select confirmed in the hand
		elif hit != null:
			_pressing = true
			_send_button(Vector2(hit.x, hit.y), true)
			buzz(0.015, 0.25)  # R2-1: panel poke tick
		else:
			# secondary PTT: the right trigger when aimed off the panel (on the panel it clicks UI)
			var v := get_tree().get_first_node_in_group("voice") as VoiceLink
			if v:
				_ptt_held = true
				v.ptt_begin()

func _on_released(action: String) -> void:
	if action == "menu_button":
		# a TAP (released before the long-press fired) resets the model; the long-press is the floor-height fix
		if _menu_down_ms >= 0 and not pointer:
			var b := get_tree().get_first_node_in_group("cad_bench")
			if b:
				b.reset_active()
		_menu_down_ms = -1
	if action == "ax_button" and _ptt_held and _ptt_by_ax:
		_ptt_held = false
		_ptt_by_ax = false
		var vx := get_tree().get_first_node_in_group("voice") as VoiceLink
		if vx:
			vx.ptt_end()
	if action == "grip_click" and _held:
		if is_instance_valid(_held):      # an in-place CAD edit can free the model under a hand
			_held.end_grab(self)
		_held = null
	elif action == "trigger_click" and _pressing:
		_pressing = false
		_send_button(_last, false)
	elif action == "trigger_click" and _ptt_held and not _ptt_by_ax:
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

var _panel_ray := false

## The locomotion rig asks this each frame: while my ray is on the panel, my thumbstick
## belongs to the panel (list scrolling), not to movement/turning.
func stick_claimed() -> bool:
	return _panel_ray

func _process(_delta: float) -> void:
	# long-press (~0.8 s) of the left menu button = RESET FLOOR (fires once per hold)
	if _menu_down_ms >= 0 and Time.get_ticks_msec() - _menu_down_ms >= RESET_HOLD_MS:
		_menu_down_ms = -1
		XrBoot.reset_floor("menu long-press")
	if not pointer:
		return
	var hit = _hit()
	_panel_ray = hit != null
	_update_hover(hit == null)
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
		_stick_scroll(pos, _delta)
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

## Pointer hover (R1-11): the part under the ray gets its name raised (and its rim lit); a parked model under the ray
## is the bench-select target. Skipped while the ray is on the panel.
func _update_hover(active: bool) -> void:
	var found: Node = null
	var part: MeshInstance3D = null
	if active:
		var best := INF
		for m in get_tree().get_nodes_in_group("grabbable"):
			if not m.has_method("pick_part"):
				continue
			var p: MeshInstance3D = m.pick_part(global_position, -global_basis.z)
			if p:
				var d := global_position.distance_to(p.global_position)
				if d < best:
					best = d
					found = m
					part = p
	if _hover_model and _hover_model != found and is_instance_valid(_hover_model):
		_hover_model.clear_highlight(true)
		if _hover_model.has_method("set_all_hot"):
			_hover_model.set_all_hot(false)
	_hover_model = found
	if found:
		if found.has_method("is_parked") and found.is_parked():
			# R2-2: a parked model under the ray glows as ONE selectable
			# object (bench select), not as a single named part.
			found.set_all_hot(true)
		else:
			found.highlight_part(part)

var _stick_cd := 0.0

## Thumbstick up/down while the ray is on the panel scrolls whatever list is under it (wheel events into the panel).
func _stick_scroll(pos: Vector2, dt: float) -> void:
	_stick_cd = maxf(0.0, _stick_cd - dt)
	var y := get_vector2("primary").y
	if absf(y) < 0.6 or _stick_cd > 0.0:
		return
	_stick_cd = 0.15
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_UP if y > 0.0 else MOUSE_BUTTON_WHEEL_DOWN
	ev.pressed = true
	ev.position = pos
	ev.global_position = pos
	get_tree().get_first_node_in_group("ui_panel").push(ev)
