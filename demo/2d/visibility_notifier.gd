extends VisibilityNotifier2D

var zone := ""

func _ready():
	
	zone = get_parent().name
	
	connect("screen_entered", self, "_screen_entered")
	connect("screen_exited", self, "_screen_exited")
	
func _screen_entered():
	
	prints(zone, "entered")
	
	get_parent().zone_entered(null)
	
func _screen_exited():
	
	prints(zone, "exited")
	get_parent().zone_exited(null)
