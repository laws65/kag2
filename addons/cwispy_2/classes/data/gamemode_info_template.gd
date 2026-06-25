extends Resource
class_name GamemodeInfo


@export var gamemode_name: String = "Default Gamemode"

@export_file("*.tscn") var map_paths: Array[String]

@export_file("*.gd") var script_paths: Array[String]
