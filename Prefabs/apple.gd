extends AnimatedSprite2D

signal item_deleted(item_id)

var item_id: String  # Unique identifier for this item

func _on_body_entered(_body):
	if is_multiplayer_authority() and _body.is_in_group("players"):  # Check if the body is a player
		# Parent this instance to the player
		get_parent().remove_child(self)  # Remove from current parent
		_body.add_child(self)  # Add this apple as a child of the player
		self.position = Vector2.UP * 96
