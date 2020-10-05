tool
extends Node

signal zone_entered(zone_id, zone_path)
signal zone_exited(zone_id)

export (String, FILE) var zone_path
export (bool) var preview := false setget set_preview

var zone_id
var _preview_node: Node = null


func _get_configuration_warning():
	var this = self
	if not (this is Area || this is Area2D):
		return "ZoneTrigger must be an Area(2D) node"
	return ""


func _ready():
	
	if Engine.editor_hint:
		return
		
	zone_id = self.name

	# warning-ignore:return_value_discarded
	connect("body_entered", self, "zone_entered")
	# warning-ignore:return_value_discarded
	connect("body_exited", self, "zone_exited")
	
	# warning-ignore:return_value_discarded
	connect("area_entered", self, "zone_entered")
	# warning-ignore:return_value_discarded
	connect("area_exited", self, "zone_exited")

# warning-ignore:unused_argument
func zone_entered(player):
	
	if Engine.editor_hint:
		return
		
	#discard initial contact with other areas
	if player != null and player.get("zone_id"):
		return
		
	emit_signal("zone_entered", zone_id, zone_path)


# warning-ignore:unused_argument
func zone_exited(player):
	
	if Engine.editor_hint:
		return
		
	#discard initial contact with other areas
	if player != null and player.get("zone_id"):
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
