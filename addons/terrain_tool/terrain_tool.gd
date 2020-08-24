tool
extends EditorPlugin

var undo_redo = get_undo_redo()

var dock

func get_cursor_pos(mouse_pos, camera, depth=800):
	
	var node = get_editor_interface().get_edited_scene_root()
	
#	var mouse_pos = get_editor_interface().get_edited_scene_root().get_viewport().get_mouse_position()
	
#	print(str("mouse pos: ", mouse_pos))

	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * depth
	
	var space_state = node.get_world().direct_space_state
	var result = space_state.intersect_ray(from, to)
	
	if result.size() != 0:
		
#		print(result.normal)
#		print(to - from)
#		print(result.normal.dot((to - from).normalized()))
#		print(result.normal.dot((from - to).normalized()))
#
#		if result.normal.dot((to - from).normalized()) <= 0.0:
#			print("raycast interupted by hidden wall")

#		NORMAL DOES NOT WORK
		
		return result.position
	else:
		return null
		
func place_node(node, position, duplicate):
	
#	print(str("place node ", node.name))
#				print(str("world pos: ", position))
	
	var new_node:Spatial
	
	if duplicate:
		
		new_node = node.duplicate()
	
		var scene_root = get_editor_interface().get_edited_scene_root()
				
#		var parent_node = scene_root.get_node("TerrainTool/Placed")
		node.get_parent().add_child(new_node)
		new_node.set_owner(scene_root)
		
	else:
		new_node = node
	
	new_node.global_transform.origin = position
	
	if duplicate:

#		print(dock)
	#	scale
		var scale_factor = dock.rand_scale / 100.0
		var scale = Vector3(0,0,0)
		if dock.prop_lock:
			var rand_scale = (randf() - 0.5)*2*scale_factor
			scale = Vector3(rand_scale,rand_scale,rand_scale)
		else:
			scale = Vector3(randf(), randf(), randf()) * scale_factor * 2.0 - Vector3(scale_factor, scale_factor, scale_factor)
		
		new_node.scale += scale
		
	#	rotate
		var rotation_axis = Vector3(randf()*int(dock.rand_rot_x), randf()*int(dock.rand_rot_y), randf()*int(dock.rand_rot_z)).normalized()
#		print(dock.rand_rot_x)
#		print(int(dock.rand_rot_x))
		var rotation_amnt = randf() * PI
		new_node.rotate(rotation_axis, rotation_amnt)
		
func handles(object):
	return true
	
func forward_spatial_gui_input(camera, event):
	
	if event is InputEventMouseButton:
		
		if event.button_index == BUTTON_LEFT \
			and event.pressed \
			and (Input.is_key_pressed(KEY_CONTROL) or Input.is_key_pressed(KEY_ALT)):
			
			var node_to_paint
			
#			get first selected node
			for node in get_editor_interface().get_selection().get_selected_nodes():
				node_to_paint = node
				break
				
			if node_to_paint == null:
				return
				
#			if node_to_paint.get_node("../..").name == "TerrainTool":
				
			var position = get_cursor_pos(event.position, camera)
			
#			print("event " + str(event.position))

			if Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_ALT):
				place_node(node_to_paint, position, false)
			else:
				place_node(node_to_paint, position, true)
			
			return true
	
func _enter_tree():
	
	# Initialization of the plugin goes here
	# Load the dock scene and instance it
	dock = preload("res://addons/terrain_tool/terrain_tool.tscn").instance()
	
	# Add the loaded scene to the docks
	add_control_to_dock(DOCK_SLOT_RIGHT_UR, dock)
	# Note that LEFT_UL means the left of the editor, upper-left dock

	set_input_event_forwarding_always_enabled()

func _exit_tree():
	
	# Clean-up of the plugin goes here
	# Remove the dock
	remove_control_from_docks(dock)
	 # Erase the control from the memory
	dock.queue_free()
