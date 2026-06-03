@tool
extends EditorPlugin


const autoloads := {
	"Client": "client.gd",
	"Multiplayer": "multiplayer.gd",
	"Server": "server.gd",
	"Players": "player_manager.gd",
	"SyncManager": "sync_manager.gd",
	"Blobs": "blob_manager.gd",
	"NetworkedClock": "networked_clock.gd",
}


func _enable_plugin() -> void:
	for autoload in autoloads.keys():
		add_autoload_singleton(autoload, "singletons/%s" % autoloads[autoload])


func _disable_plugin() -> void:
	for autoload in autoloads.keys():
		remove_autoload_singleton(autoload)


func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	pass


func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	pass
