extends Node

signal zone_entered
signal zone_exited

func _ready():
	
	if Engine.editor_hint:
		return

	# warning-ignore:return_value_discarded
	connect("body_entered", self, "zone_entered")
	# warning-ignore:return_value_discarded
	connect("body_exited", self, "zone_exited")
	
	# warning-ignore:return_value_discarded
	connect("area_entered", self, "zone_entered")
	# warning-ignore:return_value_discarded
	connect("area_exited", self, "zone_exited")

# warning-ignore:unused_argument
func zone_entered(node):
	
	if Engine.editor_hint:
		return
		
	#discard initial contact with other areas
	if node != null and node.get("zone_id"):
		return
		
	emit_signal("zone_entered")


# warning-ignore:unused_argument
func zone_exited(node):
	
	if Engine.editor_hint:
		return
		
	#discard initial contact with other areas
	if node != null and node.get("zone_id"):
		return
		
	emit_signal("zone_exited")
