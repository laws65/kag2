@tool
extends EditorPlugin


const autoloads := {
	"Client": "client.gd",
	"Server": "server.gd",
	"Players": "player_manager.gd",
	"SyncManager": "sync_manager.gd",
	"Blobs": "blob_manager.gd",
	"NetworkedClock": "networked_clock.gd",
	"Network": "network.gd",
	"GamemodeManager": "gamemode_manager.gd",
	"MapManager": "map_manager.gd",
}


func _enable_plugin() -> void:
	for autoload in autoloads.keys():
		add_autoload_singleton(autoload, "singletons/%s" % autoloads[autoload])


func _disable_plugin() -> void:
	for autoload in autoloads.keys():
		remove_autoload_singleton(autoload)
