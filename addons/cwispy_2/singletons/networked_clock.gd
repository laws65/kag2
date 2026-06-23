extends Node


signal pretick()
signal tick()
signal posttick()

const MAX_LATENCY_ARRAY_SIZE = 9
const INITIAL_TICKS_PER_SECOND = 60

var latency_msecs: float = 0.0
var client_clock: float = 0.0
var decimal_collector: float = 0.0

var latency_array: Array[float]

var time_ticks: int = 0
var time_since_last_tick_msecs := 0.0
var time_dilation_factor := 1.0

var latest_server_time_ticks: int = 0 # client only
var latest_server_engine_time_msecs: float = 0.0 # client only
var _should_signal_ticks := false # client only

var ticks_per_second: int:
	set(value):
		Engine.set_physics_ticks_per_second(value)
	get():
		return Engine.get_physics_ticks_per_second()


var engine_time_msecs: float:
	get():
		return Time.get_ticks_usec()/1000.0


var tick_duration_msecs: float:
	get():
		return 1000.0/float(ticks_per_second)


var interpolation_fraction: float:
	get():
		return time_since_last_tick_msecs / tick_duration_msecs


func initialise_on_client() -> void:
	ticks_per_second = INITIAL_TICKS_PER_SECOND
	set_process(true)
	_calculate_initial_time_and_latency()


func enable_on_client() -> void:
	_should_signal_ticks = true


func enable_on_server() -> void:
	set_process(true)


func _ready() -> void:
	set_process(false)

	ticks_per_second = INITIAL_TICKS_PER_SECOND

	posttick.connect(_on_post_tick)

	var space := get_viewport().world_2d.space
	PhysicsServer2D.space_set_active(space, false)


func _process(delta: float) -> void:
	time_since_last_tick_msecs += delta * 1000.0 * time_dilation_factor

	if not multiplayer.is_server():
		_adjust_time_dilation_factor()

	if time_since_last_tick_msecs > tick_duration_msecs:
		time_ticks += 1
		time_since_last_tick_msecs -= tick_duration_msecs

		if not _should_signal_ticks and not multiplayer.is_server():
			return

		pretick.emit()
		tick.emit()

		var space := get_viewport().world_2d.space
		RapierPhysicsServer2D.space_step(space, time_since_last_tick_msecs / 1000.0)
		RapierPhysicsServer2D.space_flush_queries(space)

		posttick.emit()


func _on_post_tick() -> void:
	if multiplayer.is_server():
		_broadcast_server_time()
	else:
		_broadcast_client_time()


func _broadcast_server_time() -> void:
	_receive_server_time.rpc_id(0, time_ticks, engine_time_msecs)


@rpc("unreliable_ordered", "authority")
func _receive_server_time(server_time_ticks: int, server_engine_time_msecs: float) -> void:
	latest_server_time_ticks = server_time_ticks
	latest_server_engine_time_msecs = server_engine_time_msecs


func _broadcast_client_time() -> void:
	_receive_client_time.rpc_id(1, time_ticks, engine_time_msecs)


@rpc("unreliable_ordered", "any_peer")
func _receive_client_time(client_time_ticks: int, client_engine_time_msecs: float) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	_return_client_time.rpc_id(sender_id, client_time_ticks, client_engine_time_msecs)


@rpc("unreliable_ordered", "authority")
func _return_client_time(old_client_time_ticks: int, old_client_engine_time_msecs: float) -> void:
	latency_array.push_back(
		0.5 * (engine_time_msecs - old_client_engine_time_msecs)
	)
	if latency_array.size() == MAX_LATENCY_ARRAY_SIZE:
		_adjust_latency()


func _adjust_latency() -> void:
	latency_array.sort()
	var latency_median := latency_array[floori(MAX_LATENCY_ARRAY_SIZE/2)]
	var pruned_latency_array: Array[float]

	for latency_value in latency_array:
		if latency_value < latency_median * 2.0 or latency_value < 20.0:
			pruned_latency_array.push_back(latency_value)

	var total_latency := 0.0
	for latency_value in pruned_latency_array:
		total_latency += latency_value

	latency_msecs = total_latency / float(pruned_latency_array.size())
	latency_array.clear()


func _adjust_time_dilation_factor() -> void:
	const max_tick_disparity_before_correcting := 1

	const high_time_dilation_factor := 1.2
	const low_time_dilation_factor := 0.8

	var desired_time_ticks := (
		latest_server_time_ticks
		- msecs_to_ticks(latency_msecs)
		- msecs_to_ticks(time_since_last_tick_msecs)
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
		sender_id, client_engine_time_msecs, time_ticks, engine_time_msecs
	)


@rpc("reliable", "authority")
func _receive_initial_time_and_latency(
	old_engine_time_msecs: float, server_time_ticks: int, server_engine_time_msecs: float
) -> void:
	latency_msecs = (engine_time_msecs - old_engine_time_msecs) * 0.5

	time_ticks = server_time_ticks

	latest_server_time_ticks = server_time_ticks
	latest_server_engine_time_msecs = server_engine_time_msecs


func msecs_to_ticks(time_msecs: float) -> int:
	return ceili(time_msecs / tick_duration_msecs)


func ticks_to_msecs(time_ticks: int) -> float:
	return time_ticks * tick_duration_msecs
