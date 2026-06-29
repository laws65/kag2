extends Node


const APP_ID: int = 480

func _ready() -> void:
	return
	var initialise_response := Steam.steamInitEx(APP_ID)

	if initialise_response['status'] > Steam.STEAM_API_INIT_RESULT_OK:
		print("Failed to initialize Steam, shutting down: %s" % initialise_response)
		get_tree().quit()


func _process(_delta: float) -> void:
	return
	#Steam.run_callbacks()
