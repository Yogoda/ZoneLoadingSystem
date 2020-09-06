extends Spatial

onready var zone_loader = $ZoneLoader

export var player_scene:PackedScene

const GROUP_PLAYER_SPAWN = "PLAYER_SPAWN"
var player

var starting_zone = "Zone02"

func _input(event):
	
	if event is InputEventKey and event.pressed and not event.is_echo():
		
		if event.scancode == KEY_ESCAPE:

			print("exited")
			get_tree().quit()

func _ready():
	
		#this will fire the first time a zone is attached to the world (initial loading)
		zone_loader.connect("zone_attached", self, "_on_first_zone_attached", [], CONNECT_ONESHOT)
		
		#simulate player entering first zone area (as player is not in the world yet)
		var zone_path = zone_loader.get_node(starting_zone).zone_path
		zone_loader._on_zone_entered(starting_zone, zone_path)
		
		get_tree().paused = true
		
		$UI/LoadingScreen.show()

#called when loading of the first area is finished
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
