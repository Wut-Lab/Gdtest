extends Node2D

const ROCK := preload("res://rock.tscn")


func _ready() -> void:
	# Place 5 rocks in a ring around the middle, away from the ship.
	var middle := get_viewport_rect().size / 2
	for i in 5:
		var rock := ROCK.instantiate()
		rock.position = middle + Vector2.from_angle(randf() * TAU) * 260
		add_child(rock)
