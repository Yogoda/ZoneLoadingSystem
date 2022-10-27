@tool
extends Node

signal zone_entered(zone_id, zone_path)
signal zone_exited(zone_id)

@export_file var zone_path

@export var preview:bool = false: 
	get:
		return preview
	set(new_value):
		set_preview(new_value)

var zone_id
var zone_trigger
var _preview_node: Node = null


func _get_configuration_warnings():
	
	var trigger

	for child in get_children():
		if child is Area3D or child is Area2D:
			trigger = child
			break

	if trigger == null:
		return "Area3D or Area2D child expected for zone trigger"

	return ""


func _ready():
	
	if Engine.is_editor_hint():
		return
		
	zone_id = self.name
	
	var trigger

	for child in get_children():
		if child is Area3D or child is Area2D:
			trigger = child
			break

	assert(trigger!=null)
	
	zone_trigger = trigger

	# warning-ignore:return_value_discarded
	trigger.connect("area_entered",Callable(self,"zone_entered"))
	# warning-ignore:return_value_discarded
	trigger.connect("area_exited",Callable(self,"zone_exited"))
	
	trigger.add_to_group("zone_trigger")


# warning-ignore:unused_argument
func enter_zone(area):
	
	if Engine.is_editor_hint():
		return
		
	#discard initial contact with other areas
	if area != null and area.is_in_group("zone_trigger"):
		return
		
	emit_signal("zone_entered", zone_id, zone_path)


# warning-ignore:unused_argument
func exit_zone(area):
	
	if Engine.is_editor_hint():
		return
		
	#discard initial contact with other areas
	if area != null and area.is_in_group("zone_trigger"):
		return
		
	emit_signal("zone_exited", zone_id)


func set_preview(value: bool):
	
	if not Engine.is_editor_hint() or preview == value:
		return
		
	preview = value

	# remove_at existing node, if any
	if _preview_node:
		_preview_node.queue_free()
		_preview_node = null

	# try to load the path
	if preview && zone_path:
		
		var scene: PackedScene = load(zone_path)
		
		# if we loaded something, add it
		if not scene:
			return
			
		_preview_node = scene.instantiate()
		
		add_child(_preview_node)
		
		# this node will not be saved in the editor
		_preview_node.owner = null
