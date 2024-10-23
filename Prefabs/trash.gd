extends AnimatedSprite2D

signal item_deleted(item_id)

var item_id : String  # Unique identifier for this item

func _on_body_entered(_body):
	if is_multiplayer_authority():
		# Emit the signal with the unique item_id
		emit_signal("item_deleted", item_id)

	# Queue this instance for deletion
	call_deferred("queue_free")
