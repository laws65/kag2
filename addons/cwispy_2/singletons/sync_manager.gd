extends Node


var snapshot_buffer := []
var _interpolation_buffer_min_size_ticks := 0


func _ready() -> void:
	NetworkedClock.pretick.connect(_on_pre_tick)
	NetworkedClock.posttick.connect(_on_post_tick)


func _on_pre_tick() -> void:
	if not multiplayer.is_server():
		_render_world_snapshot_tick()


func _on_post_tick() -> void:
	if multiplayer.is_server():
		_transmit_blob_snapshots()
	elif Blobs.has_local_blob():
		_transmit_client_snapshot()


func reset() -> void:
	snapshot_buffer.clear()
	_interpolation_buffer_min_size_ticks = 0


func _render_world_snapshot_tick() -> void:
	if snapshot_buffer.size() < 1 + _interpolation_buffer_min_size_ticks:
		return

	var render_snapshot: Dictionary = snapshot_buffer[-1 - _interpolation_buffer_min_size_ticks]["snapshots"]

	for blob_id in render_snapshot.keys():
		var blob := Blobs.get_blob_by_id(blob_id)
		if not is_instance_valid(blob):
			continue
		if blob.is_my_blob():
			_display_ghost_blob(blob_id, render_snapshot[blob_id], render_snapshot[blob_id], 1)
			continue
		blob.set_snapshop(render_snapshot[blob_id])


func _transmit_blob_snapshots() -> void:
	var blobs := Blobs.get_blobs()
	var to_transmit: Dictionary
	for blob in blobs:
		var snapshot := blob.get_snapshot()
		to_transmit[blob.get_id()] = snapshot
	var time_ticks: int = NetworkedClock.time_ticks
	_receive_server_blob_snapshots.rpc_id(0, to_transmit, time_ticks)


@rpc("authority", "unreliable")
func _receive_server_blob_snapshots(blob_snapshots: Dictionary, snapshot_time_ticks: int) -> void:
	var to_insert := {"time": snapshot_time_ticks, "snapshots": blob_snapshots}

	for i in snapshot_buffer.size():
		if snapshot_time_ticks < snapshot_buffer[i]["time"]:
			snapshot_buffer.insert(i, to_insert)
			return

	snapshot_buffer.push_back(to_insert)


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
		blob.set_snapshop(snapshot)


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
