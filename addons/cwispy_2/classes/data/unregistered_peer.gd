class_name UnregisteredPeer


var peer_id: int
var is_loaded: bool = false
var spawn_data: Dictionary


func _init(peer_id: int) -> void:
	self.peer_id = peer_id
