extends Node


const STEAM_ENABLED = false

const STEAM_AUTH_TICKET = &"steam_auth_ticket"
const STEAM_ID = &"steam_id"
const MOD_DIR = "kag2"

enum {
	MODE_DISABLED,
	MODE_CONNECTING_SERVER,
	MODE_ENABLED_SERVER,
	MODE_ENABLED_CLIENT,
}

var mode = MODE_DISABLED

var auth: SteamAuth
var server_browser: SteamServerBrowser


func _ready() -> void:
	if not STEAM_ENABLED:
		set_process(false)
		return

	Server.pre_start_server.connect(_initialise_on_server) # assumes that pre start server is only ever emitted once
	SteamServer.server_connected.connect(_on_server_connected_to_steam)
	Client.pre_join_server.connect(_initialise_on_client)

	auth = SteamAuth.new()
	server_browser = SteamServerBrowser.new()


func _process(_delta: float) -> void:
	if mode == MODE_ENABLED_SERVER or mode == MODE_CONNECTING_SERVER:
		SteamServer.run_callbacks()
	elif mode == MODE_ENABLED_CLIENT:
		Steam.run_callbacks()


func _initialise_on_server() -> void:
	var initialise_response := SteamServer.serverInitEx(
		"0.0.0.0",
		Server.config.sv_port,
		Server.config.sv_port + 1,
		SteamServer.SERVER_MODE_AUTHENTICATION,
		"0.1.0"
	)

	var error_code: int = initialise_response["status"]
	var error_message: String = initialise_response["verbal"]

	if error_code != SteamServer.SteamAPIInitResult.STEAM_API_INIT_RESULT_OK:
		print(error_message)
		return

	var product_name := str(SteamServer.getAppID())
	SteamServer.setProduct(product_name)
	SteamServer.setModDir(MOD_DIR)
	SteamServer.setGameDescription("King Arthur's Gold 2")
	SteamServer.logOnAnonymous()

	mode = MODE_CONNECTING_SERVER


func _initialise_on_client() -> void:
	if mode == MODE_ENABLED_CLIENT:
		return

	var initialise_response := Steam.steamInitEx()
	if initialise_response["status"] > Steam.STEAM_API_INIT_RESULT_OK:
		print("Failed to initialize Steam, shutting down: %s" % initialise_response)
		get_tree().quit()

	Client.custom_join_data[STEAM_ID] = Steam.getSteamID()
	print("Steam has been initialised on client")
	mode = MODE_ENABLED_CLIENT


func _on_server_connected_to_steam() -> void:
	mode = MODE_ENABLED_SERVER
	print("Server has connected to steam")
