extends Node


const STEAM_AUTH_TICKET = &"steam_auth_ticket"
const STEAM_ID = &"steam_id"

enum {
	MODE_DISABLED,
	MODE_CONNECTING_SERVER,
	MODE_ENABLED_SERVER,
	MODE_ENABLED_CLIENT,
}

var _mode = MODE_DISABLED

# server only
var _pending_auth: Dictionary[int, int]

# client only
var _client_auth_ticket_id: int


func _ready() -> void:
	Player.secret_members.push_back(STEAM_AUTH_TICKET)

	Server.pre_start_server.connect(initialise_on_server) # assumes that pre start server is only ever emitted once
	Server.custom_client_authenticator = begin_new_player_authentication
	SteamServer.validate_auth_ticket_response.connect(_on_validate_auth_ticket_response)
	SteamServer.server_connected.connect(_on_server_connected_to_steam)
	Players.player_left.connect(_on_Player_left)

	Client.pre_join_server.connect(_on_pre_join_server)
	Client.left_server.connect(_client_cancel_auth_ticket)


func _process(_delta: float) -> void:
	if _mode == MODE_ENABLED_SERVER or _mode == MODE_CONNECTING_SERVER:
		SteamServer.run_callbacks()
	elif _mode == MODE_ENABLED_CLIENT:
		Steam.run_callbacks()


#region SERVER FUNCS
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
	_mode = MODE_CONNECTING_SERVER


func _on_server_connected_to_steam() -> void:
	_mode = MODE_ENABLED_SERVER
	print("Server has connected to steam")


func begin_new_player_authentication(player_id: int, join_data: Dictionary) -> void:
	if _mode == MODE_CONNECTING_SERVER:
		await SteamServer.server_connected

	if not join_data.has(STEAM_AUTH_TICKET):
		Server.reject_connection_request(player_id, "No steam auth ticket found")
		return

	if not join_data.has(STEAM_ID):
		Server.reject_connection_request(player_id, "No steam ID found")
		return

	var ticket: Dictionary = join_data[STEAM_AUTH_TICKET]
	var steam_id: int = join_data[STEAM_ID]

	var auth_response_id: int = SteamServer.beginAuthSession(ticket.buffer, ticket.size, steam_id)
	var verbose_response: String = get_begin_auth_session_response_verbal(auth_response_id)

	print("Auth verification response: %s" % verbose_response)

	if auth_response_id == SteamServer.BeginAuthSessionResult.BEGIN_AUTH_SESSION_RESULT_OK:
		_pending_auth[steam_id] = player_id
		print("Validation successful, adding user to client_auth_tickets")
	else:
		Server.reject_connection_request(player_id, verbose_response)


func _on_validate_auth_ticket_response(steam_id: int, response_id: int, _ticket_owner_steam_id: int) -> void:
	print("Received auth ticket response for player %s and response %s" % [steam_id, response_id])
	print("Verbalised it is %s" % get_auth_session_response_verbal(response_id))
	var player_id := _pending_auth[steam_id]
	_pending_auth.erase(steam_id)

	if response_id == SteamServer.AuthSessionResponse.AUTH_SESSION_RESPONSE_OK:
		Server.accept_connection_request(player_id)


func _on_Player_left(player: Player) -> void:
	if _mode == MODE_ENABLED_SERVER or _mode == MODE_CONNECTING_SERVER:
		end_client_auth_session(player)


func end_client_auth_session(player: Player) -> void:
	var steam_id: int = player.get_prop(STEAM_ID)
	SteamServer.endAuthSession(steam_id)
#endregion


#region CLIENT FUNCS
func _on_pre_join_server() -> void:
	if _mode != MODE_ENABLED_CLIENT:
		initialise_on_client()

	generate_auth_ticket()


func initialise_on_client() -> void:
	var initialise_response := Steam.steamInitEx()

	if initialise_response["status"] > Steam.STEAM_API_INIT_RESULT_OK:
		print("Failed to initialize Steam, shutting down: %s" % initialise_response)
		get_tree().quit()

	Client.custom_join_data[STEAM_ID] = Steam.getSteamID()

	_mode = MODE_ENABLED_CLIENT


func generate_auth_ticket() -> void:
	var auth_ticket: Dictionary = Steam.getAuthSessionTicket()
	Client.custom_join_data[STEAM_AUTH_TICKET] = auth_ticket
	_client_auth_ticket_id = auth_ticket.id


func _client_cancel_auth_ticket() -> void:
	Steam.cancelAuthTicket(_client_auth_ticket_id)
#endregion


#region HELPER FUNCS
func get_auth_session_response_verbal(response_id: int) -> String:
	match response_id:
		SteamServer.AuthSessionResponse.AUTH_SESSION_RESPONSE_OK:
			return "Ticket is valid"
		SteamServer.AuthSessionResponse.AUTH_SESSION_RESPONSE_USER_NOT_CONNECTED_TO_STEAM:
			return "User is not connected to steam"
		SteamServer.AuthSessionResponse.AUTH_SESSION_RESPONSE_NO_LICENSE_OR_EXPIRED:
			return "User does not own this game"
		SteamServer.AuthSessionResponse.AUTH_SESSION_RESPONSE_VAC_BANNED:
			return "User is VAC banned"
		SteamServer.AuthSessionResponse.AUTH_SESSION_RESPONSE_LOGGED_IN_ELSEWHERE:
			return "User is logged in elsewhere"
		SteamServer.AuthSessionResponse.AUTH_SESSION_RESPONSE_VAC_CHECK_TIMED_OUT:
			return "Steam VAC check timed out"
		SteamServer.AuthSessionResponse.AUTH_SESSION_RESPONSE_AUTH_TICKET_CANCELED:
			return "User auth session has been cancelled by user"
		SteamServer.AuthSessionResponse.AUTH_SESSION_RESPONSE_AUTH_TICKET_INVALID_ALREADY_USED:
			return "User auth session ticket already used"
		SteamServer.AuthSessionResponse.AUTH_SESSION_RESPONSE_AUTH_TICKET_INVALID:
			return "User auth ticket is invalid"
		SteamServer.AuthSessionResponse.AUTH_SESSION_RESPONSE_PUBLISHER_ISSUED_BAN:
			return "User is banned by the publisher"
		SteamServer.AuthSessionResponse.AUTH_SESSION_RESPONSE_AUTH_TICKET_NETWORK_IDENTITY_FAILURE:
			return "Weird network error wtf"
		_:
			return "Unknown ticket error"


func get_begin_auth_session_response_verbal(response_id: int) -> String:
	match response_id:
		SteamServer.BeginAuthSessionResult.BEGIN_AUTH_SESSION_RESULT_OK:
			return "Ticket looks valid"
		SteamServer.BeginAuthSessionResult.BEGIN_AUTH_SESSION_RESULT_INVALID_TICKET:
			return "Ticket is invalid"
		SteamServer.BeginAuthSessionResult.BEGIN_AUTH_SESSION_RESULT_DUPLICATE_REQUEST:
			return "Ticket has already been used"
		SteamServer.BeginAuthSessionResult.BEGIN_AUTH_SESSION_RESULT_INVALID_VERSION:
			return "Ticket has invalid game version"
		SteamServer.BeginAuthSessionResult.BEGIN_AUTH_SESSION_RESULT_GAME_MISMATCH:
			return "Ticket is from the wrong game"
		SteamServer.BeginAuthSessionResult.BEGIN_AUTH_SESSION_RESULT_EXPIRED_TICKET:
			return "Ticket is expired"
		_:
			return "Unknown ticket error"
#endregion
