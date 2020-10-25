tool
extends Node

signal zone_entered(zone_id, zone_path)
signal zone_exited(zone_id)

export (String, FILE) var zone_path
export (bool) var preview := false setget set_preview

var zone_id
var _preview_node: Node = null


func _get_configuration_warning():

	var trigger = get_node_or_null("ZoneTrigger")

	if trigger == null:
		return "ZoneTrigger child expected"

	if not (trigger is Area || trigger is Area2D):
		return "ZoneTrigger must be an Area(2D) node"
		
	return ""


func _ready():
	
	if Engine.editor_hint:
		return
		
	zone_id = self.name

	var trigger = get_node("ZoneTrigger")

	# warning-ignore:return_value_discarded
	trigger.connect("area_entered", self, "zone_entered")
	# warning-ignore:return_value_discarded
	trigger.connect("area_exited", self, "zone_exited")
	
	trigger.add_to_group("zone_trigger")


# warning-ignore:unused_argument
func zone_entered(area):
	
	if Engine.editor_hint:
		return
		
	#discard initial contact with other areas
	if area != null and area.is_in_group("zone_trigger"):
		return
		
	emit_signal("zone_entered", zone_id, zone_path)


# warning-ignore:unused_argument
func zone_exited(area):
	
	if Engine.editor_hint:
		return
		
	#discard initial contact with other areas
	if area != null and area.is_in_group("zone_trigger"):
		return
		
	emit_signal("zone_exited", zone_id)


func set_preview(value: bool):
	
	if not Engine.editor_hint or preview == value:
		return
		
	preview = value

	# remove existing node, if any
	if _preview_node:
		_preview_node.queue_free()
		_preview_node = null

	# try to load the path
	if preview && zone_path:
		
		var scene: PackedScene = load(zone_path)
		
		# if we loaded something, add it
		if not scene:
			return
			
		_preview_node = scene.instance()
		
		add_child(_preview_node)
		
		# this node will not be saved in the editor
		_preview_node.owner = null
