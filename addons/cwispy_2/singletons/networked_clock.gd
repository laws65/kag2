extends Node

signal pretick()
signal tick()
signal posttick()

var latency: float = 0.0
var client_clock: float = 0.0
var delta_latency: float = 0.0
var decimal_collector: float = 0.0

var latency_array: Array[float]

var time_ticks := 0
var time_since_last_tick_seconds := 0.0
var time_dilation_factor := 1.0
var ticks_per_second := Engine.get_physics_ticks_per_second()

var tick_duration_seconds: float:
	get():
		return 1.0/float(ticks_per_second)

var interpolation_fraction: float:
	get():
		return time_since_last_tick_seconds / tick_duration_seconds


func _ready() -> void:
	set_process(false)

	var enable_process := func(): set_process(true)

	Client.joined_server.connect(enable_process)
	Server.server_started.connect(enable_process)


func _process(delta: float) -> void:
	client_clock += delta*1000.0 + delta_latency
	delta_latency = 0.0

	time_since_last_tick_seconds += delta * time_dilation_factor

	if time_since_last_tick_seconds > tick_duration_seconds:
		time_ticks += 1
		time_since_last_tick_seconds -= tick_duration_seconds
		pretick.emit()
		tick.emit()
		posttick.emit()


func _on_connected_to_server() -> void:
	_fetch_server_time.rpc_id(1, Time.get_ticks_usec()/1000.0)
	var timer := Timer.new()
	timer.wait_time = 0.5
	timer.autostart = true
	timer.timeout.connect(_determine_latency)
	add_child(timer)


func _determine_latency() -> void:
	_determine_client_latency.rpc_id(1, Time.get_ticks_usec()/1000.0)


@rpc("reliable", "any_peer")
func _determine_client_latency(client_time: float) -> void:
	var player_id := multiplayer.get_remote_sender_id()
	_receive_client_latency.rpc_id(player_id, client_time)


@rpc("reliable", "authority")
func _receive_client_latency(old_client_time: float) -> void:
	latency_array.append(
		(Time.get_ticks_usec()/1000.0 - old_client_time) * 0.5
	)
	if latency_array.size() == 9:
		var total_latency = 0.0
		latency_array.sort()
		var mid_point := latency_array[4]
		for i in range(latency_array.size()-1, -1, -1):
			if latency_array[i] > 2 * mid_point and latency_array[i] > 20.0:
				latency_array.remove_at(i)
			else:
				total_latency += latency_array[i]
		delta_latency = (total_latency / float(latency_array.size())) - latency
		latency = total_latency / float(latency_array.size())
		latency_array.clear()


@rpc("reliable", "any_peer")
func _fetch_server_time(client_time_msecs: float) -> void:
	var player_id := multiplayer.get_remote_sender_id()
	_return_server_time.rpc_id(player_id, Time.get_ticks_usec()/1000.0, client_time_msecs)


@rpc("reliable", "authority")
func _return_server_time(server_time_msecs: float, old_client_time_msecs: float) -> void:
	latency = (Time.get_ticks_usec()/1000.0 - old_client_time_msecs) / 2.0
	client_clock = server_time_msecs + latency
