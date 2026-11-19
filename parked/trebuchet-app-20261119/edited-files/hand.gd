extends XRController3D
## Controller logic. Both hands: grip_click grabs the model. Pointer hand (right):
## laser ray + trigger_click drive the UI panel. Action names come from the
## auto-generated openxr_action_map.tres (grip_click, trigger_click, aim_pose).

@export var pointer := false
@export var pointer_range := 4.0

var _held: Node = null
var _pressing := false
var _last := Vector2.ZERO
@onready var _laser: Node3D = get_node_or_null("Laser")

func _ready() -> void:
	button_pressed.connect(_on_pressed)
	button_released.connect(_on_released)
	if _laser:
		_laser.visible = pointer

func _on_pressed(action: String) -> void:
	if action == "grip_click" and _held == null:
		var pin := _pin_owner()
		if pin and pin.pin_near(global_position):   # a hand on the release pin pulls it, not the model
			pin.pin_select()
			return
		for m in get_tree().get_nodes_in_group("grabbable"):
			if m.visible and m.can_grab(self):
				_held = m
				m.begin_grab(self)
				break
	elif action == "trigger_click" and pointer:
		var hit = _hit()
		if hit != null:
			_pressing = true
			_send_button(Vector2(hit.x, hit.y), true)
		else:
			var pin := _pin_owner()
			if pin and pin.pin_ray_hit(global_position, -global_basis.z):
				pin.pin_select()

func _on_released(action: String) -> void:
	if action == "grip_click" and _held:
		_held.end_grab(self)
		_held = null
	elif action == "trigger_click" and _pressing:
		_pressing = false
		_send_button(_last, false)

## The grabbable that has a release pin (the trebuchet), if any.
func _pin_owner() -> Node:
	for m in get_tree().get_nodes_in_group("grabbable"):
		if m.has_method("pin_select"):
			return m
	return null

func _hit() -> Variant:
	var panel := get_tree().get_first_node_in_group("ui_panel")
	return panel.pick(global_position, -global_basis.z) if panel else null

func _process(_delta: float) -> void:
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
