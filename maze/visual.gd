extends Node2D

func _ready():
	queue_redraw()

func _draw():
	draw_circle(Vector2.ZERO, 15, Color.BLUE)
