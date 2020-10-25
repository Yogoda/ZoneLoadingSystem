### How does it work ?

BackgroundLoader is an autoload singleton that takes requests to load/instance resources.

It contains a background thread that needs to be manually started/stopped with:

	BackgroundLoader.start()
	BackgroundLoader.request_stop(), and then wait for signal "BackgroundLoader.loading_process_stopped"
	
Once the loader is started, you can use the following methods:

	BackgroundLoader.request_load(resource_id, resource_path)
	BackgroundLoader.request_unload(resource_id)

	BackgroundLoader.request_instance(resource_id, resource_path)
	BackgroundLoader.request_free(resource_id)
  
The resource_id is an ID that you provide to identify your resource, it can be anything. In the demo we use the zone id.
	
Note that "request_instance" will also automatically load the resource if not already loaded.
	
When a resource has finished loading/instancing, the corresponding signal will be raised (resource_loaded/resource_instanced).
	
Note that the background loader can be used to load any resource in the background, not just zones.

To be continued...
