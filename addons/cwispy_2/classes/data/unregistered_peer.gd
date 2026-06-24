class_name UnregisteredPeer


var peer_id: int
var is_loaded: bool = false
var spawn_data: Dictionary


func _init(peer_id: int) -> void:
	self.peer_id = peer_id


static func erase_peer(
	target_id: int, unregistered_peers: Array[UnregisteredPeer]
) -> void:
	for peer in unregistered_peers:
		if peer.peer_id == target_id:
			unregistered_peers.erase(peer)
			return


static func get_peer(
	target_id: int, unregistered_peers: Array[UnregisteredPeer]
) -> UnregisteredPeer:
	for peer in unregistered_peers:
		if peer.peer_id == target_id:
			return peer
	return null
