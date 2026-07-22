extends Node


var _world_state_buffer := RingBuffer.new(50)
var _interpolation_buffer_min_size_ticks := 0


var _complete_world_state_providers: Array[Node] # [[node, node_name], [node, node_name]]
var rewinding := false

var _networked_input := NetworkedInput.new()

var world_tick: int = -1


func _ready() -> void:
	add_child(_networked_input, true)
	NetworkedClock.pretick.connect(_on_pre_tick)
	NetworkedClock.posttick.connect(_on_post_tick)


	register_complete_world_state_provider(Players)
	register_complete_world_state_provider(Blobs)
	register_complete_world_state_provider(GamemodeManager)
	register_complete_world_state_provider(MapManager)
	register_complete_world_state_provider(NetworkedClock)


func register_complete_world_state_provider(node: Node) -> void:
	assert(node.has_method("get_complete_state_serialised"))
	assert(node.has_method("deserialise_complete_state"))

	_complete_world_state_providers.push_back(node)


func _on_pre_tick() -> void:
	if not multiplayer.is_server() and not rewinding:
		_render_world_snapshot_tick()
	_networked_input.prepare_player_inputs()


func _on_post_tick() -> void:
	if multiplayer.is_server():
		_transmit_world_state()
	elif Blobs.has_local_blob():
		_transmit_client_snapshot()


func reset() -> void:
	_world_state_buffer.clear()
	_interpolation_buffer_min_size_ticks = 0

# receive world snapshot
# tick it all the way back to the present
func _render_world_snapshot_tick() -> void:
	#if snapshot_buffer.size() < 1 + _interpolation_buffer_min_size_ticks:
	#	return

	var render_time_ticks: int = _world_state_buffer.greatest()
	var target_world_state: Dictionary = _world_state_buffer.retrieve(render_time_ticks)
	if target_world_state["time"] != render_time_ticks:
		return
	world_tick = render_time_ticks
	var render_snapshot: Dictionary = target_world_state["snapshots"]
	#var render_snapshot: Dictionary = snapshot_buffer[-1 - _interpolation_buffer_min_size_ticks]["snapshots"]

	for blob_id in render_snapshot.keys():
		var blob := Blobs.get_blob_by_id(blob_id)
		if not is_instance_valid(blob):
			continue
		if blob.is_my_blob():
			_display_ghost_blob(blob_id, render_snapshot[blob_id], render_snapshot[blob_id], 1)
		else:
			blob.set_snapshot(render_snapshot[blob_id])

	var tick_difference := NetworkedClock.time_ticks - render_time_ticks
	if tick_difference > 1000:
		return
	return
	var saved_tick := NetworkedClock.time_ticks
	NetworkedClock.broadcast_time = false
	rewinding = true
	for _i in range(render_time_ticks + 1, saved_tick + 1):
		NetworkedClock.run_tick()

	rewinding = false

	NetworkedClock.time_ticks = saved_tick
	NetworkedClock.broadcast_time = true


func _transmit_world_state() -> void:
	var blobs := Blobs.get_blobs()
	var to_transmit: Dictionary
	for blob in blobs:
		var snapshot := blob.get_snapshot()
		to_transmit[blob.get_id()] = snapshot
	var time_ticks: int = NetworkedClock.time_ticks

	_networked_input.transmit_consumed_inputs()
	_receive_server_blob_snapshots.rpc_id(0, to_transmit, time_ticks)


@rpc("authority", "unreliable")
func _receive_server_blob_snapshots(blob_snapshots: Dictionary, snapshot_time_ticks: int) -> void:
	var to_insert := {"time": snapshot_time_ticks, "snapshots": blob_snapshots, "authority": true}
	_world_state_buffer.put(to_insert, snapshot_time_ticks)

	print("receiving world state %s at time %s and acked input %s" % [snapshot_time_ticks, NetworkedClock.time_ticks, _networked_input._most_recent_consumed_inputs.get(multiplayer.get_unique_id())])

 # MAKE A SYSTEM WHERE THE SERVER RUNS 1 TICK FOR EACH 1 INPUT
# USE THE CLIENT CALCULATED PING TO DETERMINE WHICH INPUT THE SERVER SHOULD BE USING
# IF INPUT IS MISSING, INSERT A PREDICTED INPUT INTO THE INPUT COLLECTION
# IF TOO MANY ARE MISSING, THAT'S OKAY, BECAUSE IT WILL BE CAUSED BY PING AND THIS PING CALCULATION WILL CHANGE
# IF THE GAP BETWEEN THE MOST RECENTLY USED AND THE MOST RECENTLY AVAILABLE IS TOO LARGE, RUN MULTIPLE TICKS IN 1 FRAME
func _transmit_client_snapshot() -> void:
	var my_blob := Blobs.get_local_blob()
	if is_instance_valid(my_blob):
		var blob_snapshot := my_blob.get_snapshot()
		_receive_client_blob_snapshot.rpc_id(1, blob_snapshot)


@rpc("any_peer", "unreliable_ordered")
func _receive_client_blob_snapshot(snapshot: Dictionary) -> void:
	var player_id := multiplayer.get_remote_sender_id()
	var player := Players.get_player_by_id(player_id)

	if is_instance_valid(player) and player.has_blob():
		var blob := player.get_blob()
		#blob.set_snapshot(snapshot)


func _display_ghost_blob(blob_id: int, past_snapshot: Dictionary, future_snapshot: Dictionary, interpolation_delta: float) -> void:
	var blob := Blobs.get_blob_by_id(blob_id)

	if not blob:
		return
	if not past_snapshot.has("snapshots"):
		return
	if not past_snapshot["snapshots"].has(blob_id):
		return

	blob.get_node("Ghost").show()
	blob.get_node("Ghost").global_position = lerp(
		past_snapshot["snapshots"][blob_id]["position"],
		future_snapshot["snapshots"][blob_id]["position"],
		interpolation_delta
	)


#region STATE
func get_complete_world_state() -> Dictionary:
	var out: Dictionary
	for node in _complete_world_state_providers:
		out[node.name] = node.get_complete_state_serialised()
	return out


func set_complete_world_state(world_state: Dictionary) -> void:
	for node in _complete_world_state_providers:
		node.deserialise_complete_state(world_state[node.name])


func merge_complete_world_state(world_state: Dictionary) -> void:
	for node in _complete_world_state_providers:
		node.merge_complete_state(world_state[node.name])
#endregion
