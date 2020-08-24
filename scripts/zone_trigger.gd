extends Area

signal sig_zone_entered(zone_id)
signal sig_zone_exited(zone_id)

var zone_id

func _ready():
	
	zone_id = self.name
	
	# warning-ignore:return_value_discarded
	connect("body_entered", self, "zone_entered")
	# warning-ignore:return_value_discarded
	connect("body_exited", self, "zone_exited")

# warning-ignore:unused_argument
func zone_entered(player):

	emit_signal("sig_zone_entered", zone_id)
	
# warning-ignore:unused_argument
func zone_exited(player):

	emit_signal("sig_zone_exited", zone_id)
