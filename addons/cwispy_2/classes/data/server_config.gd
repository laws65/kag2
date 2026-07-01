extends Resource
class_name ServerConfig


@export var sv_name: String = "Unnamed Server"
@export var sv_description: String = ""
@export var sv_password: String = ""

@export var sv_port: int = 50302

@export var max_players: int = 32

@export var display_in_server_browser: bool = true

@export_file("*.tres") var gamemode_path: String


const DEFAULT_CONFIG_PATH = "res://server_config.tres"


static func load_config(path: String = DEFAULT_CONFIG_PATH) -> ServerConfig:
	var config: ServerConfig = load(path)
	return config
