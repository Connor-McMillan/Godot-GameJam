extends Node2D

@export var vision_range: float = 140.0
@export var vision_angle_degrees: float = 70.0
@export var segments: int = 24

var facing_direction: Vector2 = Vector2.RIGHT
var alert_amount: float = 0.0
var is_disabled: bool = false

func _ready():
	queue_redraw()

func set_vision_state(new_facing_direction: Vector2, new_alert_amount: float, disabled := false):
	if new_facing_direction.length() > 0.01:
		facing_direction = new_facing_direction.normalized()

	alert_amount = clamp(new_alert_amount, 0.0, 1.0)
	is_disabled = disabled
	queue_redraw()

func _draw():
	if facing_direction.length() <= 0.0:
		return

	var half_angle = deg_to_rad(vision_angle_degrees * 0.5)
	var base_angle = facing_direction.angle()

	var points := PackedVector2Array()
	points.append(Vector2.ZERO)

	for i in range(segments + 1):
		var t = float(i) / float(segments)
		var angle = base_angle - half_angle + (2.0 * half_angle * t)
		points.append(Vector2.RIGHT.rotated(angle) * vision_range)

	var cone_color: Color
	if is_disabled:
		cone_color = Color(0.55, 0.55, 0.55, 0.22)
	else:
		var orange = Color(1.0, 0.65, 0.2, 0.22)
		var red = Color(1.0, 0.0, 0.0, 0.32)
		cone_color = orange.lerp(red, alert_amount)

	draw_colored_polygon(points, cone_color)
