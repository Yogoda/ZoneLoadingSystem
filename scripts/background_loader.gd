class_name BackgroundLoader

# warning-ignore:unused_signal
signal resource_loading_finished(resource_id)
# warning-ignore:unused_signal
signal resource_instanced(resource_id, resource_instance)

#resources that have been loaded (referencing prevent them from being freed)
var loaded_resources = {}
var loaded_resources_lock:Mutex = Mutex.new()

var background_loading:Thread = Thread.new()

var semaphore:Semaphore = Semaphore.new()

enum {ACTION_LOAD, ACTION_UNLOAD, ACTION_INSTANCE, ACTION_FREE}

#list of actions to be executed by the background thread, in priority order
var action_queue = []
var action_queue_lock:Mutex = Mutex.new()

var request_exit = false
var exit_lock:Mutex = Mutex.new()

export var show_debug = false

func _print(text):
	
	if show_debug:
		print(text)

func start():

	#start background loading process
	# warning-ignore:return_value_discarded
	background_loading.start(self, "_background_loading")
	
func request_load(resource_id, resource_path, priority = false):
	
	_print(str("request load ", resource_id))
	
	loaded_resources_lock.lock()
	
	if loaded_resources.has(resource_id):
		var resource = loaded_resources[resource_id].resource
		_print(str("resource ", resource_id, " already loaded"))
		loaded_resources_lock.unlock()
		emit_signal("resource_loading_finished", resource_id, resource)
		return
	
	loaded_resources_lock.unlock()
	
	_post_queue_action(ACTION_LOAD, resource_id, resource_path, priority)
	
func request_unload(resource_id):
	
	_print(str("request unload ", resource_id))
	
	_post_queue_action(ACTION_UNLOAD, resource_id, null)
	
func request_instance(resource_id, resource_path, priority = false):
	
	_print(str("request instance ", resource_id))
	
	_post_queue_action(ACTION_INSTANCE, resource_id, resource_path, priority)
	
func request_free_instance(resource_id):
	
	_print(str("request free ", resource_id))
	
	_post_queue_action(ACTION_FREE, resource_id)
	
func stop():
	
	exit_lock.lock()
	request_exit = true
	exit_lock.unlock()
	
	# warning-ignore:return_value_discarded
	semaphore.post()
	
	background_loading.wait_to_finish()

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
		
		exit_lock.lock()
		if request_exit:
			_print("exiting, loading arborted")
			break
		exit_lock.unlock()

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
			
	#using deferred so that the signal is processed by the main thread
	call_deferred("emit_signal", "resource_loading_finished", resource_id, resource)
	
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

	if resource_loaded:

		loaded_resources_lock.lock()

		if loaded_resources[resource_id] == null:
			_print("ERROR: RESOURCE LOADED IS NULL")
			loaded_resources_lock.unlock()
			return
		else:
			resource_instance = loaded_resources[resource_id].instance
			
		loaded_resources_lock.unlock()

		if resource_instance != null:

			_print(str("resource ", resource_id, " already instanced"))
			call_deferred("emit_signal", "resource_instanced", resource_id, resource_instance)
			return

	#resource not loaded, proceed to loading
	else:
		_process_load_action(resource_id, resource_path)

	exit_lock.lock()
	if request_exit:
		_print("exiting, loading arborted")
		return
	exit_lock.unlock()

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

	call_deferred("emit_signal", "resource_instanced", resource_id, resource_instance)

func _process_free_instance_action(resource_id):
	
	_print("free resource")
	
	var resource_instance

	loaded_resources_lock.lock()

	if loaded_resources.has(resource_id):
		
		resource_instance = loaded_resources[resource_id].instance
		
		if resource_instance != null:
			resource_instance.free()
			loaded_resources[resource_id].instance = null

	loaded_resources_lock.unlock()

# warning-ignore:unused_argument
func _background_loading(dummy):

	_print("background process started")
	
	while true:

		# warning-ignore:return_value_discarded
		semaphore.wait() #wait for a new message to be posted in the queue
		
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
					_process_load_action(action.resource_id, action.resource_path)
				ACTION_UNLOAD:
					_process_unload_action(action.resource_id)
				ACTION_INSTANCE:
					_process_instance_action(action.resource_id, action.resource_path)
				ACTION_FREE:
					_process_free_instance_action(action.resource_id)
		
	_print("loading process stopped")
