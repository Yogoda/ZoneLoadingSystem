extends Area

signal sig_zone_entered(zone_id)
signal sig_zone_exited(zone_id)

var zone_id

func _ready():
	
	zone_id = self.name
	
	connect("body_entered", self, "zone_entered")
	connect("body_exited", self, "zone_exited")

func zone_entered(player):

	emit_signal("sig_zone_entered", zone_id)
	
func zone_exited(player):

	emit_signal("sig_zone_exited", zone_id)
