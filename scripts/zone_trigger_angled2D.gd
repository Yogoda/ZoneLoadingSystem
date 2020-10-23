tool
extends Node

var zone_id

func _get_configuration_warning():
	var this = self
	if not (this is Area || this is Area2D):
		return "ZoneTrigger must be an Area(2D) node"
	return ""

func _ready():
	
	if Engine.editor_hint:
		return
		
	var zone = get_parent()

	# warning-ignore:return_value_discarded
	connect("body_entered", zone, "zone_entered")
	# warning-ignore:return_value_discarded
	connect("body_exited", zone, "zone_exited")
	
	# warning-ignore:return_value_discarded
	connect("area_entered", zone, "zone_entered")
	# warning-ignore:return_value_discarded
	connect("area_exited", zone, "zone_exited")
	
	zone_id = zone.zone_id
