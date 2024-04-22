# import_plugin.gd
@tool
extends EditorImportPlugin
#extends EditorSceneFormatImporter

const gltf_document_extension_class = preload("./gltf_extension.gd")

const WATER_PATCH = preload("res://scenes/water_patch.tscn")

enum Presets { DEFAULT }

var packed_scenes: Dictionary

func _get_importer_name():
	return "eibriel.dkworld"

func _get_visible_name():
	return "Delta Kayak World"

func _get_recognized_extensions() -> PackedStringArray:
	return ["dkworld"]

#func _get_extensions() -> PackedStringArray:
	#var exts: PackedStringArray
	#exts.push_back("dkworld")
	#return exts


#func _get_import_flags() -> int:
#	return IMPORT_SCENE
	
func _get_save_extension():
	return "scn"

func _get_resource_type():
	return "PackedScene"

func _get_preset_count():
	return Presets.size()

func _get_preset_name(preset_index):
	match preset_index:
		Presets.DEFAULT:
			return "Default"
		_:
			return "Unknown"

func _get_import_options(path, preset_index):
	match preset_index:
		Presets.DEFAULT:
			return [{
					   "name": "use_red_anyway",
					   "default_value": false
					}]
		_:
			return []

#func _get_import_options(path: String) -> void:
#	pass

func _get_option_visibility(path, option_name, options):
	return true

func _import(source_file, save_path, options, r_platform_variants, r_gen_files):
#func _import_scene(source_file: String, flags: int, options: Dictionary) -> Object:
	var file = FileAccess.open(source_file, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
		#return null

	var json_string = file.get_as_text()
	
	var json = JSON.new()
	var error = json.parse(json_string)
	var world_definition:Dictionary = {}
	if error == OK:
		world_definition = json.data
	else:
		print("JSON Parse Error: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())
		
	var scene = PackedScene.new()
	var main_node = DKWorld.new()
	main_node.name = "DKWorld"
	
	for sector_id in world_definition:
		var sector:Dictionary = world_definition[sector_id] as Dictionary
		for item_id in sector.items:
			var item:Dictionary = sector.items[item_id] as Dictionary
			add_item(item, item_id, main_node)
		for camera_id in sector.cameras:
			var camera:Dictionary = sector.cameras[camera_id] as Dictionary
			add_camera(camera, camera_id, main_node)
		add_trees(sector.trees, sector_id, main_node)
		add_triggers(sector.triggers, sector_id, main_node)
	
	add_water(main_node)
	
	packed_scenes = {}
	var result = scene.pack(main_node)
	if result == OK:
		#return scene
		#prints(save_path, _get_save_extension())
		return ResourceSaver.save(scene, "%s.%s" % [save_path, _get_save_extension()])
	else:
		return result
		#return null

func add_triggers(triggers: Array, sector_id:String, main_node:Node3D):
	for trigger in triggers:
		# Trigger
		var trigger_area := Trigger.new()
		var trigger_collision := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		main_node.add_child(trigger_area)
		trigger_area.set_owner(main_node)
		trigger_area.add_child(trigger_collision)
		trigger_collision.set_owner(main_node)
		trigger_collision.shape = box_shape
		box_shape.size = Vector3(
			trigger.scale[0]*2,
			trigger.scale[1]*2,
			trigger.scale[2]*2
		)
		trigger_area.position.x = trigger.position[0]
		trigger_area.position.y = trigger.position[1]
		trigger_area.position.z = trigger.position[2]
		trigger_area.trigger_id = trigger.id
		trigger_area.world_node = main_node

func add_water(main_node:Node3D):
	var water = WATER_PATCH.instantiate()
	main_node.add_child(water)
	water.set_owner(main_node)

func add_trees(trees: Dictionary, sector_id:String, main_node:Node3D):
	var amount_trees: int = trees.keys().size()
	#print(amount_trees)
	if amount_trees < 1: return
	var multimesh_instance := MultiMeshInstance3D.new()
	var multimesh := MultiMesh.new()
	multimesh_instance.set_name("Trees_%s" % sector_id)
	main_node.add_child(multimesh_instance)
	multimesh_instance.set_owner(main_node)
	multimesh_instance.multimesh = multimesh
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = load_tree_meshes()
	
	var points := get_trees_positions(trees)
	
	multimesh.instance_count = points.size()
	
	#print(corners)
	var tree_n := 0
	for p in points:
		#var v = p
		#var t := Transform3D(Basis(), v)
		#t = t.rotated_local(Vector3.UP, randf_range(deg_to_rad(-180), deg_to_rad(180)))
		#t = t.scaled_local(Vector3.ONE*((randf()+0.5)*0.5))
		multimesh.set_instance_transform(tree_n, p)
		tree_n += 1

func get_trees_positions(trees) -> Array:
	var tree_n := 0
	var points := []
	for tree_id in trees:
		#print(tree_id)
		var tree:Dictionary = trees[tree_id] as Dictionary
		var set_position:= Vector3(
			tree.position[0],
			tree.position[1],
			tree.position[2]
		)
		var set_rotation:= Vector3(
			tree.rotation[0],
			tree.rotation[1],
			tree.rotation[2]
		)
		var set_scale:= Vector3(
			tree.scale[0],
			tree.scale[1],
			tree.scale[2]
		)
		var t := Transform3D(Basis(), set_position)
		t = t.rotated_local(Vector3.RIGHT, set_rotation.x)
		t = t.rotated_local(Vector3.UP, set_rotation.y)
		t = t.rotated_local(Vector3.FORWARD, set_rotation.z)
		t = t.scaled_local(set_scale)
		
		# TODO allow rotation in any axis
		var corners: Array[Vector3] = [
			t * Vector3(-1, 0, -1),
			t * Vector3(1, 0, -1),
			t * Vector3(-1, 0, 1),
			t * Vector3(1, 0, 1)
		]
		var length_side1 := corners[0].distance_to(corners[1])
		var length_side2 := corners[1].distance_to(corners[2])
		var amount_side1 := length_side1 * 2
		var amount_side2 := length_side2 * 2
		for side1 in int(amount_side1):
			for side2 in int(amount_side2):
				var point_a: Vector3 = lerp(corners[0], corners[1], side1/amount_side1)
				var point_b: Vector3 = lerp(corners[2], corners[3], side1/amount_side1)
				var point:Vector3 = lerp(point_a, point_b, side2/amount_side2)
				var t_point := Transform3D(Basis(), point)
				var rand_rotation := randf_range(deg_to_rad(-180), deg_to_rad(180))
				var rand_scale := Vector3.ONE*randf_range(0.5, 1.0)
				t_point = t_point.rotated_local(Vector3.RIGHT, set_rotation.x)
				t_point = t_point.rotated_local(Vector3.UP, set_rotation.y+rand_rotation)
				t_point = t_point.rotated_local(Vector3.FORWARD, set_rotation.z)
				t_point = t_point.scaled_local(rand_scale)
				points.append(t_point)
	return points

func load_tree_meshes():
	var gltf_loader := GLTFDocument.new()
	var convert_mesh_extension := GLTFDocumentExtensionConvertImporterMesh.new()
	gltf_loader.register_gltf_document_extension(convert_mesh_extension, true)
	var gltf_state := GLTFState.new()
	var gltf_path:String = "res://models/world/Tree001.glb"
	gltf_state.base_path = "res://models/world/"
	var gltf_error = gltf_loader.append_from_file(gltf_path, gltf_state)
	var gltf_instance: Node3D
	if gltf_error == OK:
		gltf_instance = gltf_loader.generate_scene(gltf_state) as Node3D
	gltf_loader.unregister_gltf_document_extension(convert_mesh_extension)
	const TREE_001_DIFFUSE = preload("res://models/world_textures/Tree001_diffuse.png")
	for c in gltf_instance.get_children():
		if c is MeshInstance3D:
			var mat := c.mesh.surface_get_material(0) as StandardMaterial3D
			mat.albedo_texture = TREE_001_DIFFUSE
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			return c.mesh
	return null

func add_camera(camera:Dictionary, camera_id:String, main_node:Node3D):
	#print(camera)
	var camera_node = Node3D.new()
	camera_node.set_name(camera_id)
	main_node.add_child(camera_node)
	camera_node.set_owner(main_node)
	
	# Camera
	var camera3d := Camera3D.new()
	camera3d.set_name("%s_cam" % camera_id)
	camera_node.add_child(camera3d)
	camera3d.set_owner(main_node)
	
	camera3d.position.x = camera.camera.position[0]
	camera3d.position.y = camera.camera.position[1]
	camera3d.position.z = camera.camera.position[2]
	camera3d.rotation_order = EULER_ORDER_ZXY
	camera3d.rotation.x = camera.camera.rotation[0] - deg_to_rad(90)
	camera3d.rotation.y = camera.camera.rotation[1]
	camera3d.rotation.z = camera.camera.rotation[2]
	camera3d.fov = rad_to_deg(camera.camera.fov)
	
	# Sensor
	var sensor_area := CameraSensor.new()
	var sensor_collision := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	camera_node.add_child(sensor_area)
	sensor_area.set_owner(main_node)
	sensor_area.add_child(sensor_collision)
	sensor_collision.set_owner(main_node)
	sensor_collision.shape = box_shape
	
	box_shape.size = Vector3(
		camera.sensor.scale[0]*2,
		camera.sensor.scale[1]*2,
		camera.sensor.scale[2]*2
	)
	
	sensor_area.position.x = camera.sensor.position[0]
	sensor_area.position.y = camera.sensor.position[1]
	sensor_area.position.z = camera.sensor.position[2]
	
	# Curve
	var path3d := Path3D.new()
	var curve3d := Curve3D.new()
	path3d.curve = curve3d
	camera_node.add_child(path3d)
	path3d.set_owner(main_node)
	
	path3d.position.x = camera.curve.position[0]
	path3d.position.y = camera.curve.position[1]
	path3d.position.z = camera.curve.position[2]
	#path3d.rotation_order = EULER_ORDER_ZXY
	path3d.rotation.x = camera.curve.rotation[0]
	path3d.rotation.y = camera.curve.rotation[1]
	path3d.rotation.z = camera.curve.rotation[2]
	
	for p in camera.curve.points:
		var p_position := Vector3(p[0][0], p[0][1], p[0][2])
		var p_in := Vector3(p[1][0], p[1][1], p[1][2]) - p_position
		var p_out := Vector3(p[2][0], p[2][1], p[2][2]) - p_position
		curve3d.add_point(p_position, p_in, p_out)
		
	if camera.default:
		#print("Default")
		main_node.initial_camera = camera3d
		main_node.initial_camera_path = path3d
	
	
	sensor_area.world_node = main_node
	sensor_area.camera = camera3d
	sensor_area.path = path3d
	#print(main_node.camera_change)
	#sensor_area.connect("area_entered", main_node.camera_change.bind(camera3d, curve3d))
	#print(sensor_area.is_connected("area_entered", main_node.camera_change.bind(camera3d)))
	#main_node.initial_camera_sensor = sensor_area

func add_item(item: Dictionary, item_id: String, main_node: Node3D):
	var gltf_scene: PackedScene
	if item.instance in packed_scenes:
		gltf_scene = packed_scenes[item.instance] as PackedScene
	else:
		gltf_scene = scene_from_gltf(item, item_id) as PackedScene
		packed_scenes[item.instance] = gltf_scene
	var gltf_instance = gltf_scene.instantiate()
	gltf_instance.name = item_id
	main_node.add_child(gltf_instance)
	#print(item)
	gltf_instance.position.x = item.position[0]
	gltf_instance.position.y = item.position[1]
	gltf_instance.position.z = item.position[2]
	#gltf_instance.rotation_order = EULER_ORDER_ZXY
	gltf_instance.rotation.x = item.rotation[0]
	gltf_instance.rotation.y = item.rotation[1]
	gltf_instance.rotation.z = item.rotation[2]
	gltf_instance.scale.x = item.scale[0]
	gltf_instance.scale.y = item.scale[1]
	gltf_instance.scale.z = item.scale[2]
	gltf_instance.set_owner(main_node)
	#print("owner")
	#prints(gltf_instance.name, gltf_instance.owner.name)
	_recursively_set_owner(gltf_instance, main_node)
	#gltf_instance.propagate_call("set_owner", [main_node], true)

func scene_from_gltf(item:Dictionary, item_id:String) -> PackedScene:
	var gltf_loader := GLTFDocument.new()
	var convert_mesh_extension := GLTFDocumentExtensionConvertImporterMesh.new()
	var vrm_extension: GLTFDocumentExtension = gltf_document_extension_class.new()
	# Order?
	gltf_loader.register_gltf_document_extension(convert_mesh_extension, true)
	gltf_loader.register_gltf_document_extension(vrm_extension, false)
	var gltf_state := GLTFState.new()
	var gltf_path:String = "res://models/world/%s.glb" % item.instance
	gltf_state.base_path = "res://models/world/"
	var gltf_error = gltf_loader.append_from_file(gltf_path, gltf_state)
	#print(gltf_state.json)
	var gltf_instance: Node3D
	if gltf_error == OK:
		#print("OK")
		gltf_instance = gltf_loader.generate_scene(gltf_state) as Node3D
	gltf_loader.unregister_gltf_document_extension(convert_mesh_extension)
	gltf_loader.unregister_gltf_document_extension(vrm_extension)
	_recursively_set_owner(gltf_instance, gltf_instance)
	_add_colliders(gltf_instance)
	_configure_lod(gltf_instance, gltf_state.json)
	# TODO remove unneded LODs (levels of details) from Mesh
	var scene = PackedScene.new()
	var result = scene.pack(gltf_instance)
	if result == OK:
		return scene
	else:
		return scene


func _configure_lod(gltf_instance:Node, json:Dictionary) -> void:
	for node in gltf_instance.get_children():
		var extras:={}
		for gltf_node in json.nodes:
			if gltf_node.name == node.name:
				extras = gltf_node.extras
		#print(extras)
	
		if not extras.has("dkt_properties"): continue
		var dkt_data: Dictionary = extras.dkt_properties
		var mesh_instance: = node as MeshInstance3D
		if dkt_data.has("range_begin"):
			mesh_instance.visibility_range_begin= dkt_data.range_begin
			mesh_instance.visibility_range_begin_margin = 1.0
			mesh_instance.set_meta("visibility_range_begin", dkt_data.range_begin)
		if dkt_data.has("range_end"):
			mesh_instance.visibility_range_end= dkt_data.range_end
			mesh_instance.visibility_range_end_margin = 1.0
			mesh_instance.set_meta("visibility_range_end", dkt_data.range_end)
		#if not dkt_data.is_last_lod:
			#mesh_instance.visibility_range_begin_margin = 1.0
			#mesh_instance.visibility_range_end = 10.0 * lod_distances[dkt_data.lod+1]
			#mesh_instance.visibility_range_end_margin = 1.0
	

func _add_colliders(gltf_instance:Node3D) -> void:
	for c in gltf_instance.get_children():
		if c.name.ends_with("-colonly"):
			c.visible = false
		if c.name.ends_with("_occluder"):
			c.visible = false
			var occluder := OccluderInstance3D.new()
			var array_occluder := ArrayOccluder3D.new()
			occluder.occluder = array_occluder
			var mesh = c.mesh as ArrayMesh
			var arrays := mesh.surface_get_arrays(0)
			#print(arrays.size())
			array_occluder.set_arrays(arrays[Mesh.ARRAY_VERTEX], arrays[Mesh.ARRAY_INDEX])
			gltf_instance.add_child(occluder)
			occluder.set_owner(gltf_instance)
		if c.name.ends_with("_boxcollider"):
			c.visible = false
			var static_body := StaticBody3D.new()
			gltf_instance.add_child(static_body)
			static_body.set_owner(gltf_instance)
			var collider := CollisionShape3D.new()
			var box_shape := BoxShape3D.new()
			collider.shape = box_shape
			box_shape.size = c.scale * 2
			static_body.add_child(collider)
			collider.set_owner(gltf_instance)

func _recursively_set_owner(root: Node, owner: Node) -> void:
	for child in root.get_children():
		child.set_owner(owner)
		#prints(child.name, child.owner.name)
		_recursively_set_owner(child, owner)

func _get_priority() -> float:
	return 1.0

func _get_import_order() -> int:
	return 1
