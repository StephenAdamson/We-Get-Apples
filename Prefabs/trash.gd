extends AnimatedSprite2D

@onready var area_2d = $Area2D

func _on_body_entered(body: Node):
	if body.has_node("Trash Holder"):
		area_2d.body_entered.disconnect(_on_body_entered)
		$Area2D/CollisionShape2D.call_deferred("set_disabled", true)
		call_deferred("reparent", body.get_node("Trash Holder"))
		call_deferred("set_position", Vector2.ZERO)
