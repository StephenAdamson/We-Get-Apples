extends AnimatedSprite2D


func _on_body_entered(_body):
	GameManager.score += 1
	queue_free()
