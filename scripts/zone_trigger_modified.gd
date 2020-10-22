tool
extends Node

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
