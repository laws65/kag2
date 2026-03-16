@tool
extends EditorPlugin


func _enable_plugin() -> void:
	print("plugin loading")
	add_autoload_singleton("Client", "singletons/client.gd")
	add_autoload_singleton("Multiplayer", "singletons/multiplayer.gd")
	add_autoload_singleton("Server", "singletons/server.gd")
	add_autoload_singleton("Players", "singletons/player_manager.gd")


func _disable_plugin() -> void:
	remove_autoload_singleton("Client")
	remove_autoload_singleton("Multiplayer")
	remove_autoload_singleton("Server")
	remove_autoload_singleton("Players")


func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	pass


func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	pass
