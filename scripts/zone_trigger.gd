tool
extends Node

signal zone_entered(zone_id, zone_path)
signal zone_exited(zone_id)

export (String, FILE) var zone_path

var zone_id


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

# warning-ignore:unused_argument
func zone_entered(player):
	if Engine.editor_hint:
		return
	print("player entered zone ", zone_id)
	emit_signal("zone_entered", zone_id, zone_path)
	
# warning-ignore:unused_argument
func zone_exited(player):
	if Engine.editor_hint:
		return
	emit_signal("zone_exited", zone_id)
