extends Node


var _rpc_queue: Array[Dictionary] # [{sender_id=x, node_path=x, method_name=x, args=x}]
var debug: bool = true


var _current_transmit_time_ticks := -1
var _current_sender_id := -1

var buffer_incoming_rpcs: bool = false
var accept_rpcs_after_time_ticks: int = -1

var buffer_cutoff_time_ticks := -1


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

	var transmit_time_ticks := NetworkedClock.time_ticks

	if method_rpc_config.get("call_local"):
		_generic_receive_rpc_id_safe(multiplayer.get_unique_id(), node_path, method_name, transmit_time_ticks, args)


	match method_rpc_config.transfer_mode:
		MultiplayerPeer.TRANSFER_MODE_RELIABLE:
			_receive_rpc_id_safe_reliable.rpc_id(peer_id, node_path, method_name, transmit_time_ticks, args)
		MultiplayerPeer.TRANSFER_MODE_UNRELIABLE:
			_receive_rpc_id_safe_unreliable.rpc_id(peer_id, node_path, method_name, transmit_time_ticks, args)
		MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED:
			_receive_rpc_id_safe_unreliable_ordered.rpc_id(peer_id, node_path, method_name, transmit_time_ticks, args)


@rpc("reliable", "any_peer")
func _receive_rpc_id_safe_reliable(node_path: NodePath, method_name: StringName, transmit_time_ticks: int, args: Array) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	_generic_receive_rpc_id_safe(sender_id, node_path, method_name, transmit_time_ticks, args)


@rpc("unreliable", "any_peer")
func _receive_rpc_id_safe_unreliable(node_path: NodePath, method_name: StringName, transmit_time_ticks: int, args: Array) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	_generic_receive_rpc_id_safe(sender_id, node_path, method_name, transmit_time_ticks, args)


@rpc("unreliable_ordered", "any_peer")
func _receive_rpc_id_safe_unreliable_ordered(node_path: NodePath, method_name: StringName, transmit_time_ticks: int, args: Array) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	_generic_receive_rpc_id_safe(sender_id, node_path, method_name, transmit_time_ticks, args)


func _should_buffer_incoming_rpc(transmit_time_ticks: int) -> bool:
	return (
		buffer_incoming_rpcs or
		(not multiplayer.is_server() and transmit_time_ticks < accept_rpcs_after_time_ticks) or
		(not multiplayer.is_server() and accept_rpcs_after_time_ticks < 0)
	)


func _generic_receive_rpc_id_safe(sender_id: int, node_path: NodePath, method_name: StringName, transmit_time_ticks: int, args: Array) -> void:
	if not multiplayer.is_server():
		print("%s request call %s on %s" % [multiplayer.get_unique_id(), method_name, node_path])
	if _should_buffer_incoming_rpc(transmit_time_ticks):
		print("%s adding %s to queue" % [multiplayer.get_unique_id(), method_name])
		_rpc_queue.push_back({
			"sender_id": sender_id,
			"node_path": node_path,
			"method_name": method_name,
			"transmit_time_ticks": transmit_time_ticks,
			"args": args
		})
		return

	var node := get_tree().root.get_node_or_null(node_path)
	if not is_instance_valid(node):
		# TODO request node if it doesn't exist for me
		print("Cannot call %s on %s because it doesn't exist in this scene tree" % [method_name, node_path])
		return

	var method_rpc_config := _get_rpc_config_from_node_method_name(node, method_name)
	if method_rpc_config.rpc_mode == MultiplayerAPI.RPC_MODE_AUTHORITY and sender_id != 1:
		print("Received rpc from player %s on server only method %s, REJECTING" % [sender_id, method_name])
		return

	_current_sender_id = sender_id
	_current_transmit_time_ticks = transmit_time_ticks

	if debug:
		print("%s calling %s on %s" % [multiplayer.get_unique_id(), method_name, node_path])
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


func run_old_rpcs() -> void:
	for rpc_data in _rpc_queue:
		if rpc_data.transmit_time_ticks < buffer_cutoff_time_ticks:
			print("%s skipping call %s on %s because it is too old" % [multiplayer.get_unique_id(), rpc_data.method_name, rpc_data.node_path])
			continue

		_generic_receive_rpc_id_safe(
			rpc_data.sender_id,
			rpc_data.node_path,
			rpc_data.method_name,
			rpc_data.transmit_time_ticks,
			rpc_data.args
		)

		if debug:
			print("%s running old rpc %s on %s" % [multiplayer.get_unique_id(), rpc_data.method_name, rpc_data.node_path])

	_rpc_queue.clear()


func get_rpc_transmit_time_ticks() -> int:
	return -1


func get_rpc_sender_id() -> int:
	return -1
