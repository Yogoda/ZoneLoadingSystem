extends Node

# warning-ignore:unused_signal
signal sig_zone_loading_started(zone_id)
# warning-ignore:unused_signal
signal sig_zone_loading_finished(zone_id)
# warning-ignore:unused_signal
signal sig_zone_instanced(zone_id, zone_instance)

#zone resources that have been loaded (referencing prevent them from being freed)
var loaded_zones = {}
var loaded_zones_lock:Mutex = Mutex.new()
var loading_process:Thread = Thread.new()

#var semaphore:Semaphore = Semaphore.new()

enum {ACTION_LOAD, ACTION_UNLOAD, ACTION_INSTANCE, ACTION_FREE_INSTANCE}

#list of actions to be executed by the background thread, in priority order
var action_queue = []
var action_queue_lock:Mutex = Mutex.new()

var request_exit = false
var exit_lock:Mutex = Mutex.new()

export var zone_path:String
export var show_debug = false

var current_zones = {} #zones the player is in (1-2)
var current_zone #zone the player is in (arbitrary)

func _ready():
	
	# warning-ignore:return_value_discarded
	connect("sig_zone_instanced", self, "_on_zone_instance_available")

	#connect all zone triggers
	for zone_trigger in get_children():

		zone_trigger.connect("sig_zone_entered", self, "_on_zone_entered")
		zone_trigger.connect("sig_zone_exited", self, "_on_zone_exited")

	#start background loading process
	# warning-ignore:return_value_discarded
	loading_process.start(self, "_loading_process")
	
func _print(text):
	
	if show_debug:
		print(text)
	
func get_zone_path(zone_id):
	return str(zone_path, zone_id, ".tscn")
		
func is_in_zone(zone_id):
	return current_zones.has(zone_id)
	
func get_connected_zones(zone_id):
	
	var connected_zones = []
	var zone = get_node(zone_id)
	
	if zone:
		for connected_zone in zone.get_overlapping_areas():
			connected_zones.append(connected_zone.name)
			
	return connected_zones

func _on_zone_entered(zone_id):
	
	_print(str("zone ", zone_id, " entered"))
	
	current_zone = zone_id
	current_zones[zone_id] = zone_id
	
	#load and instance current zone, in priority
	request_instance(zone_id, true)
	
	var zone = get_node(zone_id)
	
	#load connected zones
	for connected_zone in zone.get_overlapping_areas():
		_print(str("load connected zone ", connected_zone.name))
		request_instance(connected_zone.name)
	
func _on_zone_exited(zone_id):
	_print(str("zone ", zone_id, " exited"))
	
	current_zones.erase(zone_id)
	
	#when leaving a zone, we are still at least in one zone, this becomes the current zone
	if current_zones.size() >= 1:
		current_zone = current_zones.values()[0]
		
	#schedule unloading
	# warning-ignore:return_value_discarded
	get_tree().create_timer(3.0).connect("timeout", self, "_on_zone_unload", [zone_id])

func _on_zone_unload(zone_id):
	
	if not is_in_zone(zone_id):
		detach_zone(zone_id)

	#unload all loaded zones that are not current or connected
	var keep_zones = current_zones.keys()
	
	for zone_id in current_zones.keys():
		keep_zones = keep_zones + get_connected_zones(zone_id)
		
	request_pruning(keep_zones)
	
func _on_zone_instance_available(zone_id, instance):

	#if player is still in the zone, attach it
	if is_in_zone(zone_id):
		attach_zone(zone_id, instance)

func get_zone(zone_id):

	for child in get_node(zone_id).get_children():
		if not child is CollisionShape and not child is CollisionPolygon:
			return child
			
	return null
		
#attach zone to the scene tree
func attach_zone(zone_id, instance):
	
	if not get_zone(zone_id):
	
		get_node(zone_id).call_deferred("add_child", instance)
		_print(str("zone", zone_id, " attached"))
		
#remove zone from the scene tree
func detach_zone(zone_id):
	
	var zone = get_node(zone_id)
	
	for child in get_node(zone_id).get_children():
		if not child is CollisionShape and not child is CollisionPolygon:
			zone.remove_child(child)
			_print(str("zone ", zone_id, " detached"))
			break
		
func post_queue_action(action_id, zone_id, priority = false):
	
	action_queue_lock.lock()
	
	for action in action_queue:
		if action.zone_id == zone_id:
			
			#an action load should not replace an action instance, since it also do load
			if action_id == ACTION_LOAD and action.action_id == ACTION_INSTANCE:
				action_queue_lock.unlock()
				return
				
			action_queue.erase(action)
			_print(str("action removed ", action.action_id, " ", action.zone_id))

	if priority:
		action_queue.push_front({action_id = action_id, zone_id = zone_id})
	else:
		action_queue.push_back({action_id = action_id, zone_id = zone_id})

	action_queue_lock.unlock()
	
#	semaphore.post() #ask loading thread to process if waiting
	
func _process_load_action(zone_id):
	
	_print(str("process load zone ", zone_id))

	#using deferred so that the signal is processed by the main thread
	call_deferred("emit_signal", "sig_zone_loading_started", zone_id)
	
	var ts = OS.get_ticks_msec()
	
	var loader = ResourceLoader.load_interactive(get_zone_path(zone_id))
	var resource
	
	while true:
		
		exit_lock.lock()
		if request_exit:
			_print("exiting, loading arborted")
			break
		exit_lock.unlock()

		var err = loader.poll()

		#finished loading
		if err == ERR_FILE_EOF:

			resource = loader.get_resource()
			loaded_zones_lock.lock()
			loaded_zones[zone_id] = {resource = resource, instance = null}
			_print(str("zone ", zone_id, " loaded in ", (OS.get_ticks_msec() - ts) / 1000.0, "s"))
			loaded_zones_lock.unlock()
			break
			
		elif err != OK:
			_print(str("error loading resource: ", zone_path , " ",  str(err)))
			break
			
	#using deferred so that the signal is processed by the main thread
	call_deferred("emit_signal", "sig_zone_loading_finished", zone_id, resource)
	
func _process_unload_action(zone_id):
	
	_print(str("process unload zone ", zone_id))
	
	loaded_zones_lock.lock()

	if loaded_zones.has(zone_id):

		var zone = loaded_zones[zone_id]

		if zone.instance != null:
			zone.instance.free()
			
		loaded_zones.erase(zone_id)

		_print(str("zone ", zone_id, " unloaded"))

	else:
		_print(str("zone ", zone_id, " already unloaded"))
		
	loaded_zones_lock.unlock()

func _process_instance_action(zone_id):

	var zone_instance

	_print(str("process instance zone ", zone_id))

	loaded_zones_lock.lock()
	var zone_loaded = loaded_zones.has(zone_id)
	loaded_zones_lock.unlock()

	if zone_loaded:

		loaded_zones_lock.lock()

		if loaded_zones[zone_id] == null:
			_print("ERROR: ZONE LOADED IS NULL")
			loaded_zones_lock.unlock()
			return
		else:
			zone_instance = loaded_zones[zone_id].instance
		loaded_zones_lock.unlock()

		if zone_instance != null:

			_print(str("zone ", zone_id, " already instanced"))
			call_deferred("emit_signal", "sig_zone_instanced", zone_id, zone_instance)
			return

	#zone not loaded, proceed to loading
	else:

		_print(str("instance: load zone ", zone_id))
		_process_load_action(zone_id)

	exit_lock.lock()
	if request_exit:
		_print("exiting, loading arborted")
		return
	exit_lock.unlock()

	var resource

	#instance zone
	loaded_zones_lock.lock()
	resource = loaded_zones[zone_id].resource
	loaded_zones_lock.unlock()

	var ts = OS.get_ticks_msec()
	zone_instance = resource.instance()
	_print(str("zone ", zone_id, " instanced in ", (OS.get_ticks_msec() - ts) / 1000.0, "s"))

	loaded_zones_lock.lock()
	loaded_zones[zone_id].instance = zone_instance
	loaded_zones_lock.unlock()

	call_deferred("emit_signal", "sig_zone_instanced", zone_id, zone_instance)

func _process_free_instance_action(zone_id):
	
	_print("free zone")
	
	var zone_instance

	loaded_zones_lock.lock()

	if loaded_zones.has(zone_id):
		
		zone_instance = loaded_zones[zone_id].instance
		
		if zone_instance != null:
			zone_instance.free()
			loaded_zones[zone_id].instance = null

	loaded_zones_lock.unlock()
	
	#workaround for 3.2.2, fixed in 3.2.3 (pull request #41469)
#	_process_instance_action(zone_id)
	
# warning-ignore:unused_argument
func _loading_process(dummy):

	_print("loading process started")
	
	while true:
	
		OS.delay_msec(400)

#		semaphore.wait() #wait for a new message to be posted in the queue
		
		#exit ?
		exit_lock.lock()
		if request_exit:
			exit_lock.unlock()
			break
		exit_lock.unlock()
		
		action_queue_lock.lock()
		var action = action_queue.pop_front()
		action_queue_lock.unlock()
		
		if action:
			
			match action.action_id:
				
				ACTION_LOAD:
					_process_load_action(action.zone_id)
				ACTION_UNLOAD:
					_process_unload_action(action.zone_id)
				ACTION_INSTANCE:
					_process_instance_action(action.zone_id)
				ACTION_FREE_INSTANCE:
					_process_free_instance_action(action.zone_id)
		
	_print("loading process stopped")
		
func request_load(zone_id, priority = false):
	
	_print(str("request load zone ", zone_id))
	
	loaded_zones_lock.lock()
	
	if loaded_zones.has(zone_id):
		var resource = loaded_zones[zone_id].resource
		_print(str("zone ", zone_id, " already loaded"))
		loaded_zones_lock.unlock()
		emit_signal("sig_zone_loading_finished", zone_id, resource)
		return
	
	loaded_zones_lock.unlock()
	
	post_queue_action(ACTION_LOAD, zone_id, priority)
	
func request_unload(zone_id):
	
	_print(str("request unload zone ", zone_id))
	
	post_queue_action(ACTION_UNLOAD, zone_id, null)
	
func request_instance(zone_id, priority = false):
	
	_print(str("request instance zone ", zone_id))
	
	post_queue_action(ACTION_INSTANCE, zone_id, priority)
	
func request_free_instance(zone_id):
	
	_print(str("request free zone ", zone_id))
	
	post_queue_action(ACTION_FREE_INSTANCE, zone_id)
	
func request_pruning(keep_zones):
	
	loaded_zones_lock.lock()
	
	for zone in loaded_zones:

		if not zone in keep_zones:
			_print(str("prunning: request unload ", zone))
			request_unload(zone)
	
	loaded_zones_lock.unlock()
	
func exit():
	
	exit_lock.lock()
	request_exit = true
	exit_lock.unlock()
	
#	semaphore.post()
	
	loading_process.wait_to_finish()
