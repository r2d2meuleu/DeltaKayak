@tool # Needed so it runs in editor.
extends EditorScenePostImport

# This sample changes all node names.
# Called right after the scene is imported and gets the root node.
func _post_import(scene):
	# Change all node names to "modified_[oldnodename]"
	iterate(scene)
	return scene # Remember to return the imported scene

# Recursive function that is called on every node
# (for demonstration purposes; EditorScenePostImport only requires a `_post_import(scene)` function).
func iterate(node):
	if node != null:
		#print_rich("Post-import: [b]%s[/b] -> [b]%s[/b]" % [node.name, "modified_" + node.name])
		#node.name = "modified_" + node.name
		if node is MeshInstance3D:
			var p: Node3D = node.get_parent()
			if p != null and p.name == "kayak_detailed":
				#if node.name == "Kayak_001":
				node.set_layer_mask_value(15, true)
			if p != null and p.name == "Embudo":
				#if node.name == "Kayak_001":
				node.set_layer_mask_value(20, true)
			if p != null and p.name == "Almohadon2":
				#if node.name == "Kayak_001":
				node.set_layer_mask_value(15, true)
			for s in node.mesh.get_surface_count():
				var mat:StandardMaterial3D = node.mesh.surface_get_material(s)
				mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
				if not ["DogEyes"].has(mat.resource_name):
					mat.metallic_specular = 0.0
				if mat.resource_name == "Plastic Kayak":
					mat.clearcoat_enabled = true
					mat.clearcoat = 0.37
					mat.clearcoat_roughness = 0.64
				if mat.resource_name == "DesagueAgua":
					var smat := ShaderMaterial.new()
					smat.shader = preload("res://shaders/moving_texture.gdshader")
					smat.set_shader_parameter("texture_1", mat.albedo_texture)
					node.mesh.surface_set_material(s, smat)
		for child in node.get_children():
			iterate(child)
