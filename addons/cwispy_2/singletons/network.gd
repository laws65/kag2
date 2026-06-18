extends Node


func rpc_id_safe(peer_id: int, method: Callable, ...args: Array) -> void:
	var node: Node = method.get_object()
	assert(
		is_instance_valid(node),
		"Cannot rpc a callable on its own, it must be a node's method"
	)

	var node_path := node.get_path()
	var method_name := method.get_method()

	var method_rpc_config := _get_rpc_config_from_node_method_name(node, method_name)
	assert(
		method_rpc_config.rpc_mode != MultiplayerAPI.RPC_MODE_AUTHORITY
		or multiplayer.get_unique_id() == 1,
		"Cannot call remote function %s as a client" % method_name
	)

	if method_rpc_config.get("call_local"):
		_receive_rpc_id_safe_reliable(node_path, method_name, args)

	match method_rpc_config.transfer_mode:
		MultiplayerPeer.TRANSFER_MODE_RELIABLE:
			_receive_rpc_id_safe_reliable.rpc_id(peer_id, node_path, method_name, args)
		MultiplayerPeer.TRANSFER_MODE_UNRELIABLE:
			_receive_rpc_id_safe_unreliable.rpc_id(peer_id, node_path, method_name, args)
		MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED:
			_receive_rpc_id_safe_unreliable_ordered.rpc_id(peer_id, node_path, method_name, args)


@rpc("reliable", "any_peer")
func _receive_rpc_id_safe_reliable(node_path: NodePath, method_name: StringName, args: Array) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	_generic_receive_rpc_id_safe(sender_id, node_path, method_name, args)


@rpc("unreliable", "any_peer")
func _receive_rpc_id_safe_unreliable(node_path: NodePath, method_name: StringName, args: Array) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	_generic_receive_rpc_id_safe(sender_id, node_path, method_name, args)


@rpc("unreliable_ordered", "any_peer")
func _receive_rpc_id_safe_unreliable_ordered(node_path: NodePath, method_name: StringName, args: Array) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	_generic_receive_rpc_id_safe(sender_id, node_path, method_name, args)


func _generic_receive_rpc_id_safe(sender_id: int, node_path: NodePath, method_name: StringName, args: Array) -> void:
	if not multiplayer.is_server() and not Client.has_joined_server:
		print("Received call %s on %s but I am not set up yet, REJECTING" % [method_name, node_path])
		return

	var node := get_tree().root.get_node_or_null(node_path)
	if not is_instance_valid(node):
		print("Cannot call %s on %s because it doesn't exist in this scene tree" % [method_name, node_path])
		return

	var method_rpc_config := _get_rpc_config_from_node_method_name(node, method_name)
	if method_rpc_config.rpc_mode == MultiplayerAPI.RPC_MODE_AUTHORITY and sender_id != 1:
		print("Received rpc from player %s on server only method %s, REJECTING" % [sender_id, method_name])
		return

	if method_rpc_config.rpc_mode == MultiplayerAPI.RPC_MODE_ANY_PEER:
		args.push_front(sender_id)

	node.callv(method_name, args)


func _get_rpc_config_from_node_method_name(node: Node, method_name: StringName) -> Dictionary:
	var node_script: Script = node.get_script()
	assert(
		is_instance_valid(node_script),
		"Node must have a script attached so that it can be called"
	)

	var config := node_script.get_rpc_config()
	assert(
		config.has(method_name),
		"Method %s is not configured for rpc on node %s " % [method_name, node.get_path()]
	)

	return config[method_name]
