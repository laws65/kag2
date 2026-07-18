extends Node


@onready var _world_state_buffer := RingBuffer.new(50)



func _ready() -> void:
	NetworkedClock.posttick.connect(_on_post_tick)


func _on_post_tick() -> void:
	if multiplayer.is_server():
		NetworkedClock.posttick.disconnect(_on_post_tick)
		return

	var world_state := SyncManager.get_complete_world_state()
	world_state[&"timestamp"] = NetworkedClock.time_ticks
	
	_world_state_buffer.put(world_state, NetworkedClock.time_ticks)


func rewind_to(time_ticks: int) -> void:
	assert(NetworkedClock.time_ticks > time_ticks, "Cannot rewind to the future!")
	
	var target_world_state: Dictionary = _world_state_buffer.retrieve(time_ticks)
	assert(target_world_state[&"timestamp"] == time_ticks, "Cannot rollback to timestamp %s" % time_ticks)

	# TODO modify sync manager so that it doesn't delete and re-add everything every reset
	SyncManager.merge_complete_world_state(target_world_state)


func fast_forward_to(time_ticks: int) -> void:
	NetworkedClock.broadcast_time = false
	var current_time := NetworkedClock.time_ticks
	var tick_delta := time_ticks - current_time
	assert(tick_delta > 0, "Cannot fast forward from %s to %s" % [current_time, time_ticks])
	
	while tick_delta > 0:
		NetworkedClock._run_tick()
		tick_delta -= 1
		print(tick_delta)
	NetworkedClock.broadcast_time = true
