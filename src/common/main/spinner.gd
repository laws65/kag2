extends Sprite2D

func _process(_delta: float) -> void:
	var time := Time.get_ticks_msec()
	position.x = cos(time/1000.0) * 100.0
	position.y = sin(time/1000.0) * 100.0
