extends Node
class_name ZoneLoader

signal zone_entered(zone_id)
signal zone_attached(zone_id)

#useful if you need to load the zone data
signal zone_loaded(zone_id, zone_node)
#useful if you need to save the zone data
signal zone_about_to_unload(zone_id, zone_node)

@export var show_debug = false

@export var unload_delay = 1.0

var current_zones = {} #zones the player is in (1-2)
var current_zone #zone the player is in (arbitrary)

#keep track of loaded zones to ask for unloading
var loaded_zones = {}

func _ready():
	
	# warning-ignore:return_value_discarded
	BackgroundLoader.connect("resource_instance_available",Callable(self,"_on_zone_instance_available"))
	
	# warning-ignore:return_value_discarded
	BackgroundLoader.connect("resource_instanced",Callable(self,"_on_zone_loaded"))
	
	#connect all zone triggers
	for zone in get_children():
		
		if zone.get("zone_id") != null:
			
			zone.connect("zone_entered",Callable(self,"_on_zone_entered"))
			zone.connect("zone_exited",Callable(self,"_on_zone_exited"))

	if show_debug:
		BackgroundLoader.show_debug = true
	
	#start background resource loading process
	BackgroundLoader.start()

func _print(text):
	
	if show_debug:
		print(text)
	
func get_zone_path(zone_id):
	return loaded_zones[zone_id]
		
func is_in_zone(zone_id):
	return current_zones.has(zone_id)

func enter_zone(zone_id):
	get_node(zone_id).enter_zone(null)

func _on_zone_entered(zone_id, zone_path):
	
	_print(str("zone ", zone_id, " entered"))
	
	current_zone = zone_id
	current_zones[zone_id] = zone_id
	
	#load and instance current zone, in priority
	BackgroundLoader.request_instance(zone_id, zone_path, true)

	#deferred, otherwise connected zones might not be detected
	call_deferred("_load_connected_zones", zone_id)

	emit_signal("zone_entered", zone_id)
	
func _load_connected_zones(zone_id:String):
	
	var zone = get_node(zone_id)
	
	#load connected zones
	for connected_area in zone.zone_trigger.get_overlapping_areas():
	
		var connected_zone = connected_area.get_parent()
	
		#don't consider player trigger area
		if connected_zone.get("zone_id") != null:
		
			if not loaded_zones.has(connected_zone.zone_id):
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
		
	#schedule unloading, not having immediate unloading prevents having 
	#noticable transitions when going back and forth a small amount
	# warning-ignore:return_value_discarded
	get_tree().create_timer(unload_delay).connect("timeout",Callable(self,"_remove_zone").bind(zone_id))

func _remove_zone(zone_id):
	
	if not is_in_zone(zone_id):
		detach_zone(zone_id)

	#unload all loaded zones that are not current or connected
	var keep_zones = current_zones.keys()

	for current_zone_id in current_zones.keys():
		
		var zone = get_node(current_zone_id)
		
		#add all zones connected to a zone the player is in
		for connected_area in zone.zone_trigger.get_overlapping_areas():
			
			var connected_zone = connected_area.get_parent()
			
			#don't consider player trigger area
			if connected_zone.get("zone_id") != null:
				
				keep_zones.append(connected_zone.zone_id)
	
	for loaded_zone_id in loaded_zones:

		if not loaded_zone_id in keep_zones:
			
			_print(str("prunning: request unload ", loaded_zone_id))
			
			emit_signal("zone_about_to_unload", loaded_zone_id, loaded_zones[loaded_zone_id])
			
			BackgroundLoader.request_unload(loaded_zone_id)

			loaded_zones.erase(loaded_zone_id)
	
func _on_zone_loaded(zone_id, instance):
	
	emit_signal("zone_loaded", zone_id, instance)
	
#func _on_zone_unloaded(zone_id, instance):
#
#	print("erase zone ", zone_id)
#	current_zones.erase(zone_id)
	
func _on_zone_instance_available(zone_id, instance):
	
	instance.name = zone_id
	
	loaded_zones[zone_id] = instance

	#if player is still in the zone, attach it
	if is_in_zone(zone_id):

		#use a timer as a workaround for this issue:
		#https://github.com/godotengine/godot/issues/19465
		# warning-ignore:return_value_discarded
		get_tree().create_timer(0.0).connect("timeout",Callable(self,"attach_zone").bind(zone_id, instance))

#return instanced zone node from the tree
func get_zone(zone_id:String):

	return get_node(zone_id).get_node_or_null(zone_id)

#attach zone to the scene tree
func attach_zone(zone_id:String, zone_instance):

	if not get_zone(zone_id):

		get_node(zone_id).add_child(zone_instance)
		_print(str("zone ", zone_id, " attached"))
		
		emit_signal("zone_attached", zone_id)
		
#remove_at zone from the scene tree
func detach_zone(zone_id:String):
	
	var area = get_node(zone_id)
	var zone = area.get_node_or_null(zone_id)
	
	if zone:

		# warning-ignore:return_value_discarded
		get_tree().create_timer(0.0).connect("timeout",Callable(self,"remove_from_tree").bind(area, zone))
		
		_print(str("zone ", zone_id, " detached"))

func remove_from_tree(area, zone):

	if is_instance_valid(zone):
		area.remove_child(zone)
