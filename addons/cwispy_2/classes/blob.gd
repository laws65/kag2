@icon ("res://addons/icons/human.svg")
extends RapierRigidBody2D
class_name Blob


signal player_id_changed(old_player_id: int, new_player_id: int)
signal death()

@export var props_to_track_per_snapshot: Array[String] = ["position", "velocity"]
@export var props_to_spawn_with: Array[String] = ["position"]

@export var client_controlled: bool = false

@export var display_to_interpolate: Array[Node2D]

@export var health = 3.0



func _init() -> void:
	NetworkedClock.tick.connect(_on_tick_internal)


func _on_tick_internal() -> void:
	if not is_queued_for_deletion():
		_on_tick()


func _on_tick() -> void:
	pass


func server_set_player(new_player: Player) -> void:
	assert(multiplayer.is_server())
	if new_player:
		server_set_player_id(new_player.get_id())
	else:
		server_set_player_id(-1)


func server_set_player_id(new_player_id: int) -> void:
	assert(multiplayer.is_server())
	Blobs.server_set_ownership(new_player_id, get_id())


func server_die() -> void:
	assert(multiplayer.is_server(), "Can't kill blob on client")
	Network.rpc_id_safe(0, _die)


@rpc("authority", "call_local", "reliable")
func _die() -> void:
	queue_free()
	get_parent().remove_child(self)

	death.emit()
	Blobs.on_blob_die.emit(self)


#region HELPER FUNCS
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
		elif key == "position":
			PhysicsServer2D.body_set_state(
				get_rid(),
				PhysicsServer2D.BODY_STATE_TRANSFORM,
				Transform2D.IDENTITY.translated(spawn_data["position"])
			)
		else:
			set(key, spawn_data[key])


func get_snapshot() -> Dictionary:
	var snapshot: Dictionary
	for prop in props_to_track_per_snapshot:
		snapshot[prop] = get(prop)
	return snapshot


const MAX_VELOCITY_CORRECTION := 3


func set_snapshop(snapshot: Dictionary) -> void:
	for prop in snapshot.keys():
		if prop == "position":
			PhysicsServer2D.body_set_state(
				get_rid(),
				PhysicsServer2D.BODY_STATE_TRANSFORM,
				Transform2D.IDENTITY.translated(snapshot["position"])
			)
		elif prop == "linear_velocity":
			var new_velocity: Vector2 = snapshot["linear_velocity"]
			if linear_velocity.distance_squared_to(new_velocity) > pow(MAX_VELOCITY_CORRECTION, 2):
				PhysicsServer2D.body_set_state(
					get_rid(),
					PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY,
					snapshot["linear_velocity"]
				)
		else:
			set(prop, snapshot[prop])


func interpolate_snapshot(
	old_snapshot: Dictionary,
	new_snapshot: Dictionary,
	interpolation_delta: float
) -> void:
	for prop in new_snapshot.keys():
		set(prop, lerp(old_snapshot[prop], new_snapshot[prop], interpolation_delta))


func get_player_id() -> int:
	return Blobs.get_blob_id_owner(get_id())


func get_player() -> Player:
	return Players.get_player_by_id(get_player_id())


func has_player() -> bool:
	return is_instance_valid(get_player())


func is_my_blob() -> bool:
	# TODO potentially investigate why multiplayer could be null on the server
	return not multiplayer.is_server() and get_player_id() == multiplayer.get_unique_id()
#endregion
