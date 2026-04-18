extends Node2D

@export var shadow_range: float = 55.0
@export var shadow_angle_degrees: float = 110.0
@export var segments: int = 20

@export var normal_color: Color = Color(0.1, 0.1, 0.1, 0.18)
@export var disabled_color: Color = Color(0.5, 0.5, 0.5, 0.18)

var facing_direction: Vector2 = Vector2.RIGHT
var current_range: float = 55.0
var current_color: Color

func _ready():
	current_color = normal_color
	queue_redraw()

func set_shadow_state(new_facing_direction: Vector2, new_range: float, is_disabled: bool):
	if new_facing_direction.length() > 0.01:
		facing_direction = new_facing_direction.normalized()

	current_range = new_range
	current_color = disabled_color if is_disabled else normal_color
	queue_redraw()

func _draw():
	var back_direction = -facing_direction.normalized()
	var center_angle = back_direction.angle()
	var half_angle = deg_to_rad(shadow_angle_degrees * 0.5)

	var points := PackedVector2Array()
	points.append(Vector2.ZERO)

	for i in range(segments + 1):
		var t = float(i) / float(segments)
		var angle = center_angle - half_angle + (half_angle * 2.0 * t)
		points.append(Vector2.RIGHT.rotated(angle) * current_range)

	draw_colored_polygon(points, current_color)
