extends Node


var snapshot_buffer := []

var latest_snapshot_received: float = 0.0
var time_since_latest_snapshot : float = 0.0

var interpolation_buffer_ms := 100.0


func _process(delta: float) -> void:
	time_since_latest_snapshot += delta * 1000.0
	if multiplayer.multiplayer_peer == null:
		return

	if multiplayer.is_server():
		return

	if snapshot_buffer.size() < 2:
		return


	#var render_time := latest_snapshot_received - interpolation_buffer_ms + time_since_latest_snapshot
	var render_time := NetworkedClock.client_clock - interpolation_buffer_ms
	while snapshot_buffer.size() > 100 and snapshot_buffer[1]["time"] < render_time:
		snapshot_buffer.pop_front()

	var past_snapshot: Dictionary
	var future_snapshot: Dictionary

	for i in snapshot_buffer.size() - 1:
		if (snapshot_buffer[i]["time"] <= render_time
		and snapshot_buffer[i+1]["time"] >= render_time):
			past_snapshot = snapshot_buffer[i]
			future_snapshot = snapshot_buffer[i+1]
			break

	if not past_snapshot:
		print("breaking")
		return

	var interpolation_delta: float = (render_time - past_snapshot["time"]) / float(future_snapshot["time"] - past_snapshot["time"])

	for blob_id in future_snapshot["snapshots"].keys():
		if blob_id == Client.get_my_blob_id(): continue

		var blob := Blobs.get_blob_by_id(blob_id)
		if not blob: continue
		if not past_snapshot["snapshots"].has(blob_id): continue

		blob.interpolate_snapshot(
			past_snapshot["snapshots"][blob_id],
			future_snapshot["snapshots"][blob_id],
			interpolation_delta
		)

func _physics_process(_delta: float) -> void:
	if multiplayer.multiplayer_peer == null:
		return
	if multiplayer.is_server():
		_transmit_blob_snapshots()
	elif Client.connected_to_server and Client.has_blob():
		_transmit_client_snapshot()


func _transmit_blob_snapshots() -> void:
	var blobs := Blobs.get_blobs()
	var to_transmit: Dictionary
	for blob in blobs:
		var snapshot := blob.get_snapshot()
		to_transmit[blob.get_id()] = snapshot
	var time: float = Time.get_ticks_usec() / 1000.0
	_receive_server_blob_snapshots.rpc_id(0, to_transmit, time)


@rpc("authority", "unreliable")
func _receive_server_blob_snapshots(blob_snapshots: Dictionary, snapshot_time: float) -> void:
	if not Client.connected_to_server: return
	#if "--playerone" in OS.get_cmdline_args():
	#		print(snapshot_time)

	latest_snapshot_received = max(latest_snapshot_received, snapshot_time)
	time_since_latest_snapshot = 0.0

	var to_insert := {"time": snapshot_time, "snapshots": blob_snapshots}
	if snapshot_buffer.is_empty():
		snapshot_buffer.push_back(to_insert)
		return

	for i in snapshot_buffer.size():
		if snapshot_time < snapshot_buffer[i]["time"]:
			snapshot_buffer.insert(i, to_insert)
			return

	snapshot_buffer.push_back(to_insert)


func _transmit_client_snapshot() -> void:
	var my_blob := Client.get_my_blob()
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
