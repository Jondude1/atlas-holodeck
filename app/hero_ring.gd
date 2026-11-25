extends Node3D
## Round A: slow yaw driver for the hero hologram rings. Lives on the ring pivot
## (a child of the model), NOT on the model root — grabbable.gd toggles
## set_process on the root with grab state, so a root _process would stall the
## rings whenever the model sits idle; children process independently.

var speed_deg := 5.0   # degrees per second; sign picks the direction

func _process(delta: float) -> void:
	rotate_y(deg_to_rad(speed_deg) * delta)
