extends Node


const STEAM_AUTH_TICKET = &"steam_auth_ticket"
const STEAM_ID = &"steam_id"

var _pending_auth: Dictionary[int, int]


enum {
	MODE_DISABLED,
	MODE_ENABLED_SERVER,
	MODE_ENABLED_CLIENT,
}

var _mode = MODE_DISABLED

# TODO cancel auth ticket on disconnect
var _client_auth_ticket_id: int # client only


func _ready() -> void:
	Player.secret_members.push_back(STEAM_AUTH_TICKET)
	SteamServer.validate_auth_ticket_response.connect(_on_validate_auth_ticket_response)
	SteamServer.server_connected.connect(func(): print("connected server"))


func _process(_delta: float) -> void:
	if _mode == MODE_ENABLED_SERVER:
		SteamServer.run_callbacks()
	elif _mode == MODE_ENABLED_CLIENT:
		Steam.run_callbacks()


func initialise_on_client() -> void:
	var initialise_response := Steam.steamInitEx()

	if initialise_response["status"] > Steam.STEAM_API_INIT_RESULT_OK:
		print("Failed to initialize Steam, shutting down: %s" % initialise_response)
		get_tree().quit()

	Client.custom_join_data[STEAM_ID] = Steam.getSteamID()

	var auth_ticket: Dictionary = Steam.getAuthSessionTicket()
	Client.custom_join_data[STEAM_AUTH_TICKET] = auth_ticket
	_client_auth_ticket_id = auth_ticket.id
	_mode = MODE_ENABLED_CLIENT


func initialise_on_server() -> void:
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

	SteamServer.logOnAnonymous()
	_mode = MODE_ENABLED_SERVER


func begin_new_player_authentication(player_id: int, join_data: Dictionary) -> void:
	if not join_data.has(STEAM_AUTH_TICKET):
		Server.reject_connection_request(player_id, "No steam auth ticket found")
		return

	if not join_data.has(STEAM_ID):
		Server.reject_connection_request(player_id, "No steam ID found")
		return


	var ticket: Dictionary = join_data[STEAM_AUTH_TICKET]
	var steam_id: int = join_data[STEAM_ID]

	var auth_response: int = SteamServer.beginAuthSession(ticket.buffer, ticket.size, steam_id)
	_pending_auth[steam_id] = player_id
	# Get a verbose response; unnecessary but useful in this example
	var verbose_response: String
	match auth_response:
		0: verbose_response = "Ticket is valid for this game and this Steam ID."
		1: verbose_response = "The ticket is invalid."
		2: verbose_response = "A ticket has already been submitted for this Steam ID."
		3: verbose_response = "Ticket is from an incompatible interface version."
		4: verbose_response = "Ticket is not for this game."
		5: verbose_response = "Ticket has expired."
	print("Auth verifcation response: %s" % verbose_response)

	if auth_response == 0:
		print("Validation successful, adding user to client_auth_tickets")
		#client_auth_tickets.append({"id": steam_id, "ticket": ticket.id})
	Server.accept_connection_request(player_id)


func _on_validate_auth_ticket_response(steam_id: int, response: int, ticket_owner_steam_id: int) -> void:
	print("Received auth ticket response for player %s and response %s" % [ticket_owner_steam_id, response])
	var player_id := _pending_auth[steam_id]
