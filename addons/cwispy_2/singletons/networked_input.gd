extends Node


var _input_collection: Dictionary[int, RingBuffer] # player id: buffer

var _inputs_to_transmit: Dictionary[int, PackedByteArray] # timestamp : input bytes

var most_recent_consumed_inputs: Dictionary[int, int] # player id : input timestamp


func _ready() -> void:
	NetworkedClock.pretick.connect(_on_pre_tick)
	Players.player_left.connect(_on_player_left)


func _on_pre_tick() -> void:
	if multiplayer.is_server():
		_deserialise_client_inputs_into_blobs()
		return

	if SyncManager.rewinding:
		var blob := Blobs.get_local_blob()
		if not blob:
			return
		var input_at_timestamp := _retrieve_input(multiplayer.get_unique_id(), NetworkedClock.time_ticks)
		blob.input._deserialise_inputs(input_at_timestamp)
		return

	var blob := Blobs.get_local_blob()
	if not blob:
		return

	if not blob.input:
		return

	var input_bytes := blob.input._serialise_inputs()
	blob.input._deserialise_inputs(input_bytes)
	var timestamp := NetworkedClock.time_ticks # consider timestamping the inputs to be the tick of the world state
	# considering that the player does inputs on the world state, which is in the past, not the current world state of the server that they don't know about
	_insert_input_into_collection(multiplayer.get_unique_id(), timestamp, input_bytes)
	_inputs_to_transmit[timestamp] = input_bytes
	_receive_client_input_collection.rpc_id(1, _inputs_to_transmit)


func _on_player_left(player: Player) -> void:
	_input_collection.erase(player.get_id())


func _insert_input_into_collection(player_id: int, timestamp: int, input_bytes: PackedByteArray) -> void:
	if not player_id in _input_collection.keys():
		var buffer := RingBuffer.new()
		_input_collection[player_id] = buffer

	_input_collection[player_id].put([timestamp, input_bytes], timestamp)


func _retrieve_input(player_id: int, target_timestamp: int) -> PackedByteArray:
	if not _input_collection.has(player_id):
		# generate empty input
		return PackedByteArray()
	var timestamp_and_input = _input_collection[player_id].retrieve(target_timestamp)
	if not timestamp_and_input:
		# input doesn't exist at timestamp, predict it
		return PackedByteArray()
	var input_timestamp: int = timestamp_and_input[0]
	if input_timestamp != target_timestamp:
		# input doesn't exist at timestamp, predict it
		return PackedByteArray()
	var input_bytes: PackedByteArray = timestamp_and_input[1]
	return input_bytes


@rpc("unreliable", "any_peer")
func _receive_client_input_collection(timestamped_inputs: Dictionary[int, PackedByteArray]) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	var input_timestamps_received: PackedInt32Array

	for timestamp in timestamped_inputs.keys():
		input_timestamps_received.push_back(timestamp)
		_insert_input_into_collection(sender_id, timestamp, timestamped_inputs[timestamp])

	_receive_server_collected_inputs.rpc_id(sender_id, input_timestamps_received)

	#if not most_recent_consumed_inputs.has(sender_id):
	#	most_recent_consumed_inputs[sender_id] = _input_collection[sender_id].greatest()


@rpc("unreliable", "authority")
func _receive_server_collected_inputs(input_timestamps_received: PackedInt32Array) -> void:
	for input_timestamp in input_timestamps_received:
		_inputs_to_transmit.erase(input_timestamp)


@rpc("unreliable", "authority")
func _acknowledge_input(input_timestamp: int) -> void:
	most_recent_consumed_inputs[multiplayer.get_unique_id()] = input_timestamp


func sort_out_server(player_id: int) -> void:
	if most_recent_consumed_inputs.has(player_id):
		var target_time := most_recent_consumed_inputs[player_id] + 1
		most_recent_consumed_inputs[player_id] = target_time
		#set_target_time(target_time)
		print("target time %s" % target_time)


func _deserialise_client_inputs_into_blobs() -> void:
	var blobs := Blobs.get_blobs()
	for blob in blobs:
		if not blob.input:
			continue

		var player := blob.get_player()
		if not player:
			continue

		var target_timestamp := _get_next_client_input_timestamp(player.get_id())
		var input_bytes := _retrieve_input(player.get_id(), target_timestamp)
		blob.input._deserialise_inputs(input_bytes)


func _get_next_client_input_timestamp(player_id: int) -> int:
	return 1
