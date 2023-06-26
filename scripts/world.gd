extends Node

#signalling parent the world has finished loading (hide loading screen)
signal world_loaded

@onready var zone_loader:ZoneLoader = $ZoneLoader

@export var player_scene:PackedScene

#you can change the starting zone here
@export var starting_zone: String

#player spawn locations are in this group
const GROUP_PLAYER_SPAWN = "PLAYER_SPAWN"

var player


func _input(event):
	
	if event is InputEventKey and event.pressed and not event.is_echo():
		
		if event.keycode == KEY_ESCAPE:

			#ask the loading process to stop and wait for it to finish (proper way to quit)
			BackgroundLoader.request_stop()
			await BackgroundLoader.loading_process_stopped

			# warning-ignore:return_value_discarded
			get_tree().change_scene_to_file("res://demo/menu.tscn")


func _ready():
	
	#this will fire the first time a zone is attached to the world (initial loading)
	#zone_loader.connect("zone_attached", _on_first_zone_attached, CONNECT_ONE_SHOT)
	zone_loader.zone_attached.connect(_on_first_zone_attached, CONNECT_ONE_SHOT)
	
	zone_loader.connect("zone_loaded", Callable(self, "_on_zone_loaded"))
	zone_loader.connect("zone_about_to_unload", Callable(self, "_on_zone_about_to_unload"))
	
	#simulate player entering first zone area (as player is not in the world yet)
	zone_loader.enter_zone(starting_zone)

	get_tree().paused = true


#called when the initial first area has finished loading and is attached to the tree
func _on_first_zone_attached(_zone_id):
	
	#get player spawn checked the map
	var player_spawn = get_tree().get_nodes_in_group(GROUP_PLAYER_SPAWN)[0]
	
	#spawn player
	player = player_scene.instantiate()
	player.global_transform = player_spawn.global_transform
	add_child(player)
	
	get_tree().paused = false
	
	#wait one frame
	#await get_tree().idle_frame
	
	emit_signal("world_loaded")

#load zone data here
func _on_zone_loaded(_zone_id, _zone_node):

	pass
#	print("zone loaded ", zone_id)

#save zone data here
func _on_zone_about_to_unload(_zone_id, _zone_node):

	pass
#	print("zone unloaded ", zone_id)
