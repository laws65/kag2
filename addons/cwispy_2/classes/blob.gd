extends CharacterBody2D
class_name Blob


signal player_id_changed(old_player_id: int, new_player_id: int)
signal death()

@export var props_to_track_per_snapshot: Array[String] = ["position", "velocity"]
@export var props_to_spawn_with: Array[String] = ["position", "_player_id"]

@export var client_controlled: bool = false

@export var display_to_interpolate: Array[Node2D]
var _player_id := -1

@export var health = 3.0

func _init() -> void:
	NetworkedClock.tick.connect(_on_tick_internal)


func set_id(new_id: int) -> void:
	name = str(new_id)


func get_id() -> int:
	return int(name)


func get_spawn_data() -> Dictionary:
	var spawn_data: Dictionary
	for spawn_data_name in props_to_spawn_with:
		spawn_data[spawn_data_name] = get(spawn_data_name)
	spawn_data["id"] = get_id()
	return spawn_data


func set_spawn_data(spawn_data: Dictionary) -> void:
	for key in spawn_data.keys():
		if key == "id":
			set_id(spawn_data[key])
		else:
			set(key, spawn_data[key])


func get_snapshot() -> Dictionary:
	var snapshot: Dictionary
	for prop in props_to_track_per_snapshot:
		snapshot[prop] = get(prop)
	return snapshot


func set_snapshop(snapshot: Dictionary) -> void:
	for prop in snapshot.keys():
		set(prop, snapshot[prop])


func interpolate_snapshot(
	old_snapshot: Dictionary,
	new_snapshot: Dictionary,
	interpolation_delta: float
) -> void:
	for prop in new_snapshot.keys():
		set(prop, lerp(old_snapshot[prop], new_snapshot[prop], interpolation_delta))


func server_set_player(new_player: Player) -> void:
	assert(multiplayer.is_server())
	if new_player:
		server_set_player_id(new_player.get_id())
	else:
		server_set_player_id(-1)


func server_set_player_id(new_player_id: int) -> void:
	assert(multiplayer.is_server())
	Network.rpc_id_safe(0, _set_player_id, new_player_id)


@rpc("call_local", "reliable", "authority")
func _set_player_id(new_player_id: int, notify_own_player: bool = true) -> void:
	var old_player_id := _player_id
	_player_id = new_player_id

	if notify_own_player:
		var old_player := Players.get_player_by_id(old_player_id)
		if old_player:
			old_player._set_blob_id(-1, false)
		var new_player := Players.get_player_by_id(new_player_id)
		if new_player:
			new_player._set_blob_id(get_id(), false)

	player_id_changed.emit(old_player_id, new_player_id)


func get_player_id() -> int:
	return _player_id


func get_player() -> Player:
	return Players.get_player_by_id(_player_id)


func has_player() -> bool:
	return is_instance_valid(get_player())


func is_my_blob() -> bool:
	# TODO potentially investigate why multiplayer could be null on the server
	return not multiplayer.is_server() and get_player_id() == Client.get_my_id()


func _resolve_collision(collision: KinematicCollision2D) -> void:
	var colliding_body_instance_id: int = collision.get_collider_id()
	var colliding_body: Node2D = instance_from_id(colliding_body_instance_id)

	if not colliding_body is Blob:
		return

	colliding_body = colliding_body as Blob
	print("player %s colliding with blob %s" % [get_player_id(), colliding_body.get_player_id()])

	if colliding_body.get_player_id() == Client.get_my_id():
		var colliding_body_velocity: Vector2 = velocity
		colliding_body.velocity += colliding_body_velocity
		#colliding_body.move_and_collide(velocity * get_physics_process_delta_time())


func _on_tick_internal() -> void:
	if not is_queued_for_deletion():
		_on_tick()


func _on_tick() -> void:
	pass


func server_die() -> void:
	assert(multiplayer.is_server(), "Can't kill blob on client")
	Network.rpc_id_safe(0, _die)


@rpc("authority", "call_local", "reliable")
func _die() -> void:
	queue_free()
	get_parent().remove_child(self)

	death.emit()
	Blobs.on_blob_die.emit(self)
