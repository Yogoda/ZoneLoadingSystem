extends Node

onready var zone_loader = $ZoneLoader

export var player_scene:PackedScene

#player spawn locations are in this group
const GROUP_PLAYER_SPAWN = "PLAYER_SPAWN"

var player

#you can change the starting zone here
var starting_zone = "Zone01"

func _input(event):
	
	if event is InputEventKey and event.pressed and not event.is_echo():
		
		if event.scancode == KEY_ESCAPE:

			#ask the loading process to stop and wait for it to finish (proper way to quit)
			BackgroundLoader.request_stop()
			yield(BackgroundLoader, "loading_process_stopped")

			print("exited")
			get_tree().quit()

func _ready():
	
		#this will fire the first time a zone is attached to the world (initial loading)
		zone_loader.connect("zone_attached", self, "_on_first_zone_attached", [], CONNECT_ONESHOT)
		
		#simulate player entering first zone area (as player is not in the world yet)
		zone_loader.enter_zone(starting_zone)

		get_tree().paused = true
		
		#show initial loading screen
		$UI/LoadingScreen.show()

#called when the initial first area has finished loading and is attached to the tree
# warning-ignore:unused_argument
func _on_first_zone_attached(zone_id):
	
		#get player spawn on the map
		var player_spawn = get_tree().get_nodes_in_group(GROUP_PLAYER_SPAWN)[0]
		
		#spawn player
		player = player_scene.instance()
		player.global_transform = player_spawn.global_transform
		add_child(player)
		
		get_tree().paused = false
		
		$UI/LoadingScreen.hide()
