extends Node


signal pretick()
signal tick()
signal physics_tick()
signal posttick()

const MAX_LATENCY_ARRAY_SIZE = 9
const INITIAL_TICKS_PER_SECOND = 60

var time_ticks: int = 0
var time_since_last_tick_msecs := 0.0
var ticks_per_second: int = INITIAL_TICKS_PER_SECOND

var broadcast_time: bool = true

var latency_msecs: float = 0.0 # client only
var _latency_array: Array[float] # client only

var time_dilation_factor := 1.0 # client only

var latest_server_time_ticks: int = 0 # client only
var _server_time_since_last_tick_msecs: float = 0.0 # client only

var _client_should_signal_ticks := false # client only


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	time_since_last_tick_msecs += delta * 1000.0 * time_dilation_factor

	if not multiplayer.is_server():
		_server_time_since_last_tick_msecs += delta * 1000.0 * time_dilation_factor
		_adjust_time_dilation_factor()

	if time_since_last_tick_msecs >= tick_duration_msecs:
		time_since_last_tick_msecs -= tick_duration_msecs
		if not multiplayer.is_server():
			_server_time_since_last_tick_msecs -= tick_duration_msecs

		run_tick()


func run_tick() -> void:
	time_ticks += 1

	if _client_should_signal_ticks or multiplayer.is_server():
		pretick.emit()
		tick.emit()
		physics_tick.emit()
		posttick.emit()

	if broadcast_time:
		if multiplayer.is_server():
			_broadcast_server_time()
		else:
			_broadcast_client_time()


func _broadcast_server_time() -> void:
	_receive_server_time.rpc_id(0, time_ticks, time_since_last_tick_msecs)


@rpc("unreliable_ordered", "authority")
func _receive_server_time(server_time_ticks: int, _server_time_since_last_tick_msecs: float) -> void:
	latest_server_time_ticks = server_time_ticks
	self._server_time_since_last_tick_msecs = _server_time_since_last_tick_msecs


func _broadcast_client_time() -> void:
	_receive_client_time.rpc_id(1, time_ticks, engine_time_msecs)


@rpc("unreliable_ordered", "any_peer")
func _receive_client_time(client_time_ticks: int, client_engine_time_msecs: float) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	_return_client_time.rpc_id(sender_id, client_time_ticks, client_engine_time_msecs)


@rpc("unreliable_ordered", "authority")
func _return_client_time(old_client_time_ticks: int, old_client_engine_time_msecs: float) -> void:
	_latency_array.push_back(
		0.5 * (engine_time_msecs - old_client_engine_time_msecs)
	)
	if _latency_array.size() == MAX_LATENCY_ARRAY_SIZE:
		_adjust_latency()


func _adjust_latency() -> void:
	_latency_array.sort()
	var latency_median := _latency_array[floori(MAX_LATENCY_ARRAY_SIZE/2)]
	var pruned_latency_array: Array[float]

	for latency_value in _latency_array:
		if latency_value < latency_median * 2.0 or latency_value < 20.0:
			pruned_latency_array.push_back(latency_value)

	var total_latency := 0.0
	for latency_value in pruned_latency_array:
		total_latency += latency_value

	latency_msecs = total_latency / float(pruned_latency_array.size())
	_latency_array.clear()


func _adjust_time_dilation_factor() -> void:
	const max_tick_disparity_before_correcting := 1

	const high_time_dilation_factor := 1.2
	const low_time_dilation_factor := 0.8

	var desired_time_ticks := (
		latest_server_time_ticks
		+ msecs_to_ticks(
			latency_msecs + _server_time_since_last_tick_msecs
		)
	)

	var tick_diff := abs(time_ticks - desired_time_ticks)

	if tick_diff <= max_tick_disparity_before_correcting:
		time_dilation_factor = 1.0
	elif desired_time_ticks > time_ticks:
		time_dilation_factor = high_time_dilation_factor
	else:
		time_dilation_factor = low_time_dilation_factor


func _calculate_initial_time_and_latency() -> void:
	_return_initial_time_and_latency.rpc_id(1, engine_time_msecs)


@rpc("reliable", "any_peer")
func _return_initial_time_and_latency(client_engine_time_msecs: float) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	_receive_initial_time_and_latency.rpc_id(
		sender_id,
		client_engine_time_msecs,
		time_ticks,
		time_since_last_tick_msecs
	)


@rpc("reliable", "authority")
func _receive_initial_time_and_latency(
	old_engine_time_msecs: float,
	server_time_ticks: int,
	server_time_since_last_tick_msecs: float,
) -> void:
	latency_msecs = (engine_time_msecs - old_engine_time_msecs) * 0.5

	time_ticks = server_time_ticks + msecs_to_ticks(latency_msecs)

	latest_server_time_ticks = server_time_ticks

	time_since_last_tick_msecs = (
		(server_time_since_last_tick_msecs + latency_msecs) / tick_duration_msecs
	- int((server_time_since_last_tick_msecs + latency_msecs) / tick_duration_msecs)
	)


func initialise_on_client() -> void:
	set_process(true)
	_calculate_initial_time_and_latency()


func enable_on_client() -> void:
	_client_should_signal_ticks = true


func enable_on_server() -> void:
	set_process(true)


func shutdown_on_client() -> void:
	set_process(false)

	latency_msecs = 0.0
	_latency_array.clear()

	time_ticks = 0
	time_since_last_tick_msecs = 0.0
	time_dilation_factor = 1.0

	latest_server_time_ticks = 0
	_server_time_since_last_tick_msecs = 0.0

	_client_should_signal_ticks = false


func get_complete_state_serialised() -> int:
	return time_ticks


func deserialise_complete_state(time: int) -> void:
	time_ticks = time
	Network.cull_buffer_before_time_ticks = time


func merge_complete_state(state: int) -> void:
	pass # TODO IMPLEMENT


#region HELPER FUNCS
var engine_time_msecs: float:
	get():
		return Time.get_ticks_usec()/1000.0


var tick_duration_msecs: float:
	get():
		return 1000.0/float(ticks_per_second)


var interpolation_fraction: float:
	get():
		return time_since_last_tick_msecs / tick_duration_msecs


func msecs_to_ticks(time_msecs: float) -> int:
	return roundi(time_msecs / tick_duration_msecs)


func ticks_to_msecs(time_ticks: int) -> float:
	return time_ticks * tick_duration_msecs
#endregion
