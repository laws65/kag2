extends Resource
class_name ServerConfig


@export var sv_name: String = "Unnamed Server"
@export var sv_description: String = ""

@export var sv_port: int = 50302

@export_file("*.tres") var gamemode_path: String
