class_name UnregisteredPeer


var peer_id: int
var is_loaded: bool = false
var spawn_data: Dictionary
var join_data_authorised: bool = false


func _init(peer_id: int) -> void:
	self.peer_id = peer_id
