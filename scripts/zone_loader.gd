extends Node

const GROUP_ZONES = "ZONE"

export var show_debug = false
export var unload_delay = 1.0

var current_zones = {} #zones the player is in (1-2)
var current_zone #zone the player is in (arbitrary)

var loaded_zones = {}

func _ready():
	
	# warning-ignore:return_value_discarded
	BackgroundLoader.connect("resource_instanced", self, "_on_zone_instance_available")

	#connect all zone triggers
	for zone_trigger in get_children():

		zone_trigger.connect("zone_entered", self, "_on_zone_entered")
		zone_trigger.connect("zone_exited", self, "_on_zone_exited")

func _enter_tree():

	BackgroundLoader.show_debug = true
	
	#start background resource loading process
	BackgroundLoader.start()
	
func _exit_tree():
	
	#stop background process
	BackgroundLoader.stop()
	
func _print(text):
	
	if show_debug:
		print(text)
	
func get_zone_path(zone_id):
	return loaded_zones[zone_id]
		
func is_in_zone(zone_id):
	return current_zones.has(zone_id)

func _on_zone_entered(zone_id, zone_path):
	
	_print(str("zone ", zone_id, " entered"))
	
	current_zone = zone_id
	current_zones[zone_id] = zone_id

	#load and instance current zone, in priority
	BackgroundLoader.request_instance(zone_id, zone_path, true)

	var zone = get_node(zone_id)

	#load connected zones
	for connected_zone in zone.get_overlapping_areas():
	
		_print(str("load connected zone ", connected_zone.zone_id))
		BackgroundLoader.request_instance(connected_zone.zone_id, connected_zone.zone_path)
	
func _on_zone_exited(zone_id):
	
	_print(str("zone ", zone_id, " exited"))
	
	current_zones.erase(zone_id)
	
	#when leaving a zone, we are still at least in one zone, this becomes the current zone
	if current_zones.size() >= 1:
		current_zone = current_zones.values()[0]
	else:
		current_zone = null
		
	#schedule unloading
	# warning-ignore:return_value_discarded
	get_tree().create_timer(unload_delay).connect("timeout", self, "_remove_zone", [zone_id])

func _remove_zone(zone_id):
	
	if not is_in_zone(zone_id):
		detach_zone(zone_id)

	#unload all loaded zones that are not current or connected
	var keep_zones = current_zones.keys()

	for zone_id in current_zones.keys():
		
		var zone = get_node(zone_id)
		
		#add all zones connected to a zone the player is in
		for connected_zone in zone.get_overlapping_areas():
			keep_zones.append(connected_zone.zone_id)
	
	for zone_id in loaded_zones:

		if not zone_id in keep_zones:
			_print(str("prunning: request unload ", zone_id))
			BackgroundLoader.request_unload(zone_id)
	
func _on_zone_instance_available(zone_id, instance):
	
	loaded_zones[zone_id] = instance

	#if player is still in the zone, attach it
	if is_in_zone(zone_id):
		attach_zone(zone_id, instance)

#return instanced zone node from the tree
func get_zone(zone_id):

	for child in get_node(zone_id).get_children():
		
		if child.is_in_group(GROUP_ZONES):
			return child
			
	return null
		
#attach zone to the scene tree
func attach_zone(zone_id, zone_instance):
	
	if not get_zone(zone_id):
	
		zone_instance.add_to_group(GROUP_ZONES)
		get_node(zone_id).call_deferred("add_child", zone_instance)
		_print(str("zone ", zone_id, " attached"))
		
#remove zone from the scene tree
func detach_zone(zone_id):
	
	var zone = get_node(zone_id)
	
	for child in get_node(zone_id).get_children():
		
		if child.is_in_group(GROUP_ZONES):
			zone.remove_child(child)
			_print(str("zone ", zone_id, " detached"))
			break
