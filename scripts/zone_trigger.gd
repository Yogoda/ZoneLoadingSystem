extends Area

signal zone_entered(zone_id, zone_path)
signal zone_exited(zone_id)

export(String, FILE) var zone_path

var zone_id

func _ready():
	
	zone_id = self.name
	
	# warning-ignore:return_value_discarded
	connect("body_entered", self, "zone_entered")
	# warning-ignore:return_value_discarded
	connect("body_exited", self, "zone_exited")

# warning-ignore:unused_argument
func zone_entered(player):

	print("player entered zone ", zone_id)
	emit_signal("zone_entered", zone_id, zone_path)
	
# warning-ignore:unused_argument
func zone_exited(player):

	emit_signal("zone_exited", zone_id)
