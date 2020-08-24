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

#list of actions to be executed by the background thread, in priority order
var action_queue = []
var action_queue_lock:Mutex = Mutex.new()

var request_exit = false
var exit_lock:Mutex = Mutex.new()

export var zone_path:String

var current_zones = {} #zones the player is in (1-2)
var current_zone #zone the player is in (arbitrary)

class Queue_Action extends Reference:

	enum {ACTION_LOAD, ACTION_UNLOAD, ACTION_INSTANCE, ACTION_FREE_INSTANCE}
	
	var action_id
	var zone_id
	var zone_path
	
	func _init(action_id, zone_id, zone_path = null):
		
		self.action_id = action_id
		self.zone_id = zone_id
		self.zone_path = zone_path

func _ready():
	
	connect("sig_zone_loading_finished", self, "_on_zone_loading_finished")
	connect("sig_zone_instanced", self, "_on_zone_instance_available")

	#connect all zone triggers
	for zone_trigger in get_children():

		zone_trigger.connect("sig_zone_entered", self, "_on_zone_entered")
		zone_trigger.connect("sig_zone_exited", self, "_on_zone_exited")

	#start background loading process
	loading_process.start(self, "_loading_process", null)
	
func get_zone_path(zone_id):
	return str(zone_path, zone_id, ".tscn")
		
func _on_zone_entered(zone_id):
	
	print("zone ", zone_id, " entered")
	
	current_zone = zone_id
	current_zones[zone_id] = zone_id
	
	#load and instance current zone
	request_instance(zone_id, true)
	
func _on_zone_exited(zone_id):
	print("zone ", zone_id, " exited")
	
func _on_zone_loading_finished(zone_id, resource):
	pass
	
func _on_zone_instance_available(zone_id, instance):

	#if player is still in the zone, attach it
	if current_zones.has(zone_id):
		attach_zone(zone_id, instance)
		
func is_zone_attached(zone_id):

	for child in get_node(zone_id).get_children():
		if not child is CollisionShape and not child is CollisionPolygon:
			return true
			
	return false
		
func attach_zone(zone_id, instance):
	
	print("A")
	if not is_zone_attached(zone_id):
		print("B")
		get_node(zone_id).call_deferred("add_child", instance)
		print("zone", zone_id, " attached")
	
func post_queue_action(action_id, zone_id, zone_path = null, priority = false):
	
	action_queue_lock.lock()
	
	for action in action_queue:
		if action.zone_id == zone_id:
			
			#an action load should not replace an action instance, since it also do load
			if action_id == Queue_Action.ACTION_LOAD and action.action_id == Queue_Action.ACTION_INSTANCE:
				action_queue_lock.unlock()
				return
				
			action_queue.erase(action)
			print("action removed ", action.action_id, " ", action.zone_id)

	if priority:
		action_queue.push_front(Queue_Action.new(action_id, zone_id, zone_path))
	else:
		action_queue.push_back(Queue_Action.new(action_id, zone_id, zone_path))

	action_queue_lock.unlock()
	
#	semaphore.post() #ask loading thread to process if waiting
	
func _process_load_action(zone_id):
	
	print("process load zone ", zone_id)

	#using deferred so that the signal is processed by the main thread
	call_deferred("emit_signal", "sig_zone_loading_started", zone_id)
	
	var ts = OS.get_ticks_msec()
	
	var loader = ResourceLoader.load_interactive(get_zone_path(zone_id))
	var resource
	
	while true:
		
		exit_lock.lock()
		if request_exit:
			print("exiting, loading arborted")
			break
		exit_lock.unlock()

		var err = loader.poll()

		#finished loading
		if err == ERR_FILE_EOF:

			resource = loader.get_resource()
			loaded_zones_lock.lock()
			loaded_zones[zone_id] = {resource = resource, instance = null}
			print("zone ", zone_id, " loaded in ", (OS.get_ticks_msec() - ts) / 1000.0, "s")
			loaded_zones_lock.unlock()
			break
			
		elif err != OK:
			print("error loading resource: ", zone_path , " ",  str(err))
			break
			
	#using deferred so that the signal is processed by the main thread
	call_deferred("emit_signal", "sig_zone_loading_finished", zone_id, resource)
	
func _process_unload_action(zone_id):
	
	print("process unload zone ", zone_id)
	
	loaded_zones_lock.lock()

	if loaded_zones.has(zone_id):

		var zone = loaded_zones[zone_id]

		if zone.instance != null:
			zone.instance.free()
			
		loaded_zones.erase(zone_id)

		print("zone ", zone_id, " unloaded")

	else:
		print("zone ", zone_id, " already unloaded")
		
	loaded_zones_lock.unlock()

func _process_instance_action(zone_id):

	var zone_instance

	print("process instance zone ", zone_id)

	loaded_zones_lock.lock()
	var zone_loaded = loaded_zones.has(zone_id)
	loaded_zones_lock.unlock()

	if zone_loaded:

		loaded_zones_lock.lock()

		if loaded_zones[zone_id] == null:
			print("ERROR: ZONE LOADED IS NULL")
			loaded_zones_lock.unlock()
			return
		else:
			zone_instance = loaded_zones[zone_id].instance
		loaded_zones_lock.unlock()

		if zone_instance != null:

			print("zone ", zone_id, " already instanced")
			call_deferred("emit_signal", "sig_zone_instanced", zone_id, zone_instance)
			return

	#zone not loaded, proceed to loading
	else:

		print("instance: load zone ", zone_id)
		_process_load_action(zone_id)

#	print("A")

	exit_lock.lock()
	if request_exit:
		print("exiting, loading arborted")
		return
	exit_lock.unlock()

#	print("B")

	var resource

	#instance zone
	loaded_zones_lock.lock()
	resource = loaded_zones[zone_id].resource
	loaded_zones_lock.unlock()

#	print("C")

	var ts = OS.get_ticks_msec()
	zone_instance = resource.instance()
	print("zone ", zone_id, " instanced in ", (OS.get_ticks_msec() - ts) / 1000.0, "s")

#	print("D")

	loaded_zones_lock.lock()
	loaded_zones[zone_id].instance = zone_instance
	loaded_zones_lock.unlock()

#	print("E")

	call_deferred("emit_signal", "sig_zone_instanced", zone_id, zone_instance)

#	print("F")

func _process_free_instance_action(zone_id):
	
	print("free zone")
	
	var zone_instance

	loaded_zones_lock.lock()

	if loaded_zones.has(zone_id):
		
		zone_instance = loaded_zones[zone_id].instance
		
		if zone_instance != null:
			zone_instance.free()
			loaded_zones[zone_id].instance = null

	loaded_zones_lock.unlock()
	
	#create a new fresh instance for when player comes back into the zone
	#we cannot keep the instance because of the error "_body_enter_tree: Condition "!E" is true"
	_process_instance_action(zone_id)
	
func _loading_process(dummy):

	print("loading process started")
	
	while true:
	
#		print("loading thread ", OS.get_ticks_msec(), " ", OS.get_ticks_usec(), " ", OS.get_time())
		OS.delay_msec(400)

#		print("wait")
#		semaphore.wait() #wait for a new message to be posted in the queue
#		print("post")
		
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
				
				Queue_Action.ACTION_LOAD:
					_process_load_action(action.zone_id)
				Queue_Action.ACTION_UNLOAD:
					_process_unload_action(action.zone_id)
				Queue_Action.ACTION_INSTANCE:
					_process_instance_action(action.zone_id)
				Queue_Action.ACTION_FREE_INSTANCE:
					_process_free_instance_action(action.zone_id)
		
	print("loading process stopped")
		
func request_load(zone_id, zone_path, priority = false):
	
	print("request load zone ", zone_id)
	
	loaded_zones_lock.lock()
	
	if loaded_zones.has(zone_id):
		var resource = loaded_zones[zone_id].resource
		print("zone ", zone_id, " already loaded")
		loaded_zones_lock.unlock()
		emit_signal("sig_zone_loading_finished", zone_id, resource)
		return
	
	loaded_zones_lock.unlock()
	
	post_queue_action(Queue_Action.ACTION_LOAD, zone_id, zone_path, priority)
	
func request_unload(zone_id):
	
	print("request unload zone ", zone_id)
	
	post_queue_action(Queue_Action.ACTION_UNLOAD, zone_id, null)
	
func request_instance(zone_id, zone_path, priority = false):
	
	print("request instance zone ", zone_id)
	
	post_queue_action(Queue_Action.ACTION_INSTANCE, zone_id, zone_path, priority)
	
func request_free_instance(zone_id):
	
	print("request free zone ", zone_id)
	
	post_queue_action(Queue_Action.ACTION_FREE_INSTANCE, zone_id)
	
func request_pruning(keep_zones):
	
	print("pruning start")
	
	loaded_zones_lock.lock()
	
	for zone in loaded_zones:

		if not zone in keep_zones:
			print("PRUNNING: request unloading ", zone)
			request_unload(zone)
	
	loaded_zones_lock.unlock()
	
	print("prune finish")
	
func exit():
	
	exit_lock.lock()
	request_exit = true
	exit_lock.unlock()
	
#	semaphore.post()
	
	loading_process.wait_to_finish()
