extends Spatial

onready var zone_loader = $ZoneLoader
onready var zones = $Zones

func _ready():

	#connect all zone triggers
	for zone_trigger in zones.get_children():

		zone_trigger.connect("sig_zone_entered", self, "_on_zone_entered")
		zone_trigger.connect("sig_zone_exited", self, "_on_zone_exited")
		
#		var zone_id = zone_trigger.name
#
#		#register zone connections
#		#need to wait a bit so zone overlapping data is available
#		get_tree().create_timer(1.0).connect("timeout", self, "register_connected_zones", [zone_id])
#
#func register_zone_connections(zone_id):
#
#	for area in get_overlapping_areas():
#		emit_signal("sig_connect_zone", zone_id, area.name)
		
func _on_zone_entered(zone_id):
	print("zone ", zone_id, " entered")
	
func _on_zone_exited(zone_id):
	print("zone ", zone_id, " exited")
