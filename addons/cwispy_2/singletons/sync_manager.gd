extends Node


var snapshot_buffer := []

var latest_snapshot_received: int = 0
var time_since_latest_snapshot : int = 0

func _process(delta: float) -> void:
	time_since_latest_snapshot += roundi(delta * 1000)
	if multiplayer.multiplayer_peer == null:
		return

	if multiplayer.is_server():
		return

	if snapshot_buffer.size() < 2:
		return
	while snapshot_buffer.size() > 10:
		snapshot_buffer.pop_front()

	var latest_snapshot: Dictionary = snapshot_buffer[-1]
	var second_latest_snapshot: Dictionary = snapshot_buffer[-2]
	var latest_time: int = latest_snapshot["time"]
	var second_latest_time: int = second_latest_snapshot["time"]
	var render_time := second_latest_time + time_since_latest_snapshot
	var interpolation_delta := (render_time - second_latest_time) / float(latest_time - second_latest_time)
	interpolation_delta = min(interpolation_delta, 1)
	print("%s - %s - %s - %s" % [second_latest_time, render_time, latest_time, interpolation_delta])
	for blob_id in latest_snapshot["snapshots"].keys():
		if blob_id == Client.get_my_blob_id(): continue

		var blob := Blobs.get_blob_by_id(blob_id)
		if not blob: continue
		if not second_latest_snapshot["snapshots"].has(blob_id): continue

		var older_state: Dictionary = second_latest_snapshot["snapshots"][blob_id]
		var newer_state: Dictionary = latest_snapshot["snapshots"][blob_id]

		blob.interpolate_snapshot(
			older_state,
			newer_state,
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
	_receive_server_blob_snapshots.rpc_id(0, to_transmit)


@rpc("authority", "unreliable_ordered")
func _receive_server_blob_snapshots(blob_snapshots: Dictionary) -> void:
	if not Client.connected_to_server: return
	latest_snapshot_received = roundi(Time.get_unix_time_from_system()*1000.0)
	time_since_latest_snapshot = 0
	snapshot_buffer.push_back({
		"time": latest_snapshot_received,
		"snapshots": blob_snapshots
	})
	return
	for blob_id: int in blob_snapshots.keys():
		if blob_id == Client.get_my_blob_id(): continue

		var blob := Blobs.get_blob_by_id(blob_id)
		if blob:
			blob.set_snapshop(blob_snapshots[blob_id])


func _transmit_client_snapshot() -> void:
	var my_blob := Client.get_my_blob()
	if is_instance_valid(my_blob):
		var blob_snapshot := my_blob.get_snapshot()
		_receive_client_blob_snapshot.rpc_id(1, blob_snapshot)


@rpc("any_peer", "unreliable_ordered")
func _receive_client_blob_snapshot(snapshot: Dictionary) -> void:
	print("client snapshot received")
	var player_id := multiplayer.get_remote_sender_id()
	var player := Players.get_player_by_id(player_id)
	if is_instance_valid(player) and player.has_blob():
		var blob := player.get_blob()
		blob.set_snapshop(snapshot)
