extends Node

#the resource was just instanced
# warning-ignore:unused_signal
signal resource_instanced(resource_id, resource_instance)

#the resource instance is available (maybe it was already instanced)
# warning-ignore:unused_signal
signal resource_instance_available(resource_id, resource_instance)

# warning-ignore:unused_signal
signal _loading_process_stopped #internal use
signal loading_process_stopped #external use

#resources that have been loaded (referencing prevent them from being freed)
var loaded_resources = {}
var loaded_resources_lock:Mutex = Mutex.new()

var loading_process:Thread = Thread.new()

var semaphore:Semaphore = Semaphore.new()

enum {ACTION_LOAD, ACTION_UNLOAD, ACTION_INSTANCE, ACTION_FREE}

#list of actions to be executed by the background thread, in priority order
var action_queue = []
var action_queue_lock:Mutex = Mutex.new()

var _request_exit = false

var exit_lock:Mutex = Mutex.new()

export var show_debug = false

func _print(text):
	
	if show_debug:
		print(text)

func start():
	
	if loading_process.is_active():
		_print("loading process already running...")
		return

	_request_exit = false

	#start background loading process
	# warning-ignore:return_value_discarded
	loading_process.start(self, "_loading_process")
	
#will stop the loading process when a quit request is received 
#(closing the window with the x button)
func _notification(what):

	if what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST:

		if loading_process.is_active():

			request_stop()
			yield(self, "_loading_process_stopped")

func is_exiting():
	
	var exiting
	
	exit_lock.lock()
	exiting = _request_exit
	exit_lock.unlock()
	
	return exiting

func request_load(resource_id, resource_path, priority = false):
	
	if is_exiting():
		return
	
	_print(str("request load ", resource_id))
	
	loaded_resources_lock.lock()
	
	if loaded_resources.has(resource_id):
		_print(str("resource ", resource_id, " already loaded"))
		loaded_resources_lock.unlock()
		return
	
	loaded_resources_lock.unlock()
	
	_post_queue_action(ACTION_LOAD, resource_id, resource_path, priority)
	
func request_unload(resource_id):
	
	if is_exiting():
		return
	
	_print(str("request unload ", resource_id))
	
	_post_queue_action(ACTION_UNLOAD, resource_id, null)
	
func request_instance(resource_id, resource_path, priority = false):
	
	if is_exiting():
		return
	
	_print(str("request instance ", resource_id))
	
	_post_queue_action(ACTION_INSTANCE, resource_id, resource_path, priority)
	
func request_free(resource_id):
	
	if is_exiting():
		return
	
	_print(str("request free ", resource_id))
	
	_post_queue_action(ACTION_FREE, resource_id)
	
func request_stop():
	
	exit_lock.lock()
	_request_exit = true
	exit_lock.unlock()
	
	# warning-ignore:return_value_discarded
	semaphore.post()
	
	#wait for the loading process to signal it has finished
	#(prevents game from freezing when thread is instancing nodes)
	yield(self, "_loading_process_stopped")
	
	loading_process.wait_to_finish()
	
	emit_signal("loading_process_stopped")

func _post_queue_action(action_id, resource_id, resource_path = null, priority = false):
	
	action_queue_lock.lock()
	
	for action in action_queue:
		
		if action.resource_id == resource_id:
			
			#an action load should not replace an action instance, since it also do load
			if action_id == ACTION_LOAD and action.action_id == ACTION_INSTANCE:
				action_queue_lock.unlock()
				return
				
			action_queue.erase(action)
			_print(str("action removed ", action.action_id, " ", action.resource_id))

	if priority:
		action_queue.push_front({action_id = action_id, resource_id = resource_id, resource_path = resource_path})
	else:
		action_queue.push_back({action_id = action_id, resource_id = resource_id, resource_path = resource_path})

	action_queue_lock.unlock()
	
	# warning-ignore:return_value_discarded
	semaphore.post() #ask loading thread to process if waiting
	
func _process_load_action(resource_id, resource_path):
	
	_print(str("process load resource ", resource_id))

	var ts = OS.get_ticks_msec()
	
	var loader = ResourceLoader.load_interactive(resource_path)
	var resource
	
	while true:
		
		if is_exiting():
			_print(str("exiting, loading ", resource_id, " arborted"))
			break

		var err = loader.poll()

		#finished loading
		if err == ERR_FILE_EOF:

			resource = loader.get_resource()
			loaded_resources_lock.lock()
			loaded_resources[resource_id] = {resource = resource, instance = null}
			_print(str("resource ", resource_id, " loaded in ", (OS.get_ticks_msec() - ts) / 1000.0, "s"))
			loaded_resources_lock.unlock()
			break
			
		elif err != OK:
			_print(str("error loading resource: ", resource_id , " ",  str(err)))
			break
			
	if is_exiting():
		return

func _process_unload_action(resource_id):
	
	_print(str("process unload resource ", resource_id))
	
	loaded_resources_lock.lock()

	if loaded_resources.has(resource_id):

		var resource = loaded_resources[resource_id]

		if resource.instance != null:
			resource.instance.free()
			
		loaded_resources.erase(resource_id)

		_print(str("resource ", resource_id, " unloaded"))

	else:
		_print(str("resource ", resource_id, " already unloaded"))
		
	loaded_resources_lock.unlock()

func _process_instance_action(resource_id, resource_path):

	var resource_instance

	_print(str("process instance resource ", resource_id))

	loaded_resources_lock.lock()
	var resource_loaded = loaded_resources.has(resource_id)
	loaded_resources_lock.unlock()

	#resource already loaded
	if resource_loaded:

		loaded_resources_lock.lock()

		resource_instance = loaded_resources[resource_id].instance
			
		loaded_resources_lock.unlock()

		#resource already instanced
		if resource_instance != null:

			_print(str("resource ", resource_id, " already instanced"))
			
			if not is_exiting():
				call_deferred("emit_signal", "resource_instance_available", resource_id, resource_instance)
			return

	#resource not loaded, proceed to loading
	else:
		_process_load_action(resource_id, resource_path)

	if is_exiting():
		_print("exiting, loading arborted")
		return

	var resource

	#instance resource
	loaded_resources_lock.lock()
	resource = loaded_resources[resource_id].resource
	loaded_resources_lock.unlock()

	var ts = OS.get_ticks_msec()
	resource_instance = resource.instance()
	_print(str("resource ", resource_id, " instanced in ", (OS.get_ticks_msec() - ts) / 1000.0, "s"))

	loaded_resources_lock.lock()
	loaded_resources[resource_id].instance = resource_instance
	loaded_resources_lock.unlock()

	if not is_exiting():
		call_deferred("emit_signal", "resource_instanced", resource_id, resource_instance)
		call_deferred("emit_signal", "resource_instance_available", resource_id, resource_instance)

func _process_free_action(resource_id):
	
	_print("free resource")
	
	var resource_instance

	loaded_resources_lock.lock()

	if loaded_resources.has(resource_id):
		
		resource_instance = loaded_resources[resource_id].instance
		
		if resource_instance != null:
			resource_instance.free()
			loaded_resources[resource_id].instance = null

	loaded_resources_lock.unlock()
	
func _reset_state():
	
	#remove all pending messages
	action_queue_lock.lock()
	action_queue.clear()
	action_queue_lock.unlock()
	
	#clear all loaded resources
	loaded_resources_lock.lock()
	
	#free instanced nodes that are not attached to the tree
	for resource_id in loaded_resources:

		var node = loaded_resources[resource_id].instance
		if node != null and not node.is_inside_tree():
			loaded_resources[resource_id].instance.queue_free()

	loaded_resources.clear()
	
	loaded_resources_lock.unlock()

#the background loading process executed by a thread
# warning-ignore:unused_argument
func _loading_process():

	_print("background process started")
	
	while true:

		# warning-ignore:return_value_discarded
		semaphore.wait() #wait for a new message to be posted in the queue
		
		#exit ?
		exit_lock.lock()
		if _request_exit:
			
			_reset_state()

			exit_lock.unlock()
			break

		exit_lock.unlock()
		
		action_queue_lock.lock()
		var action = action_queue.pop_front()
		action_queue_lock.unlock()
		
		if action:
			
			match action.action_id:
				
				ACTION_LOAD:
					_process_load_action(action.resource_id, action.resource_path)
				ACTION_UNLOAD:
					_process_unload_action(action.resource_id)
				ACTION_INSTANCE:
					_process_instance_action(action.resource_id, action.resource_path)
				ACTION_FREE:
					_process_free_action(action.resource_id)
	
	call_deferred("emit_signal", "_loading_process_stopped")
	
	_print("loading process stopped")
