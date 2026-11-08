extends Node2D
## Continuous weighted meshes and 60 FPS baked IK, with runtime pose blending.
## A native preview adapter for the exported Spine subset, not its official runtime.
signal animation_finished(animation_name: String)
const ART := "res://Art/Qingqiu/HunterRigV2"
var art_root := ART
var data: Dictionary
var info: Dictionary
var bones: Dictionary = {}
var setup: Dictionary = {}
var sprites: Dictionary = {}
var meshes: Dictionary = {}
var bone_list: Array[Bone2D] = []
var current := "idle"
var elapsed := 0.0
var speed_scale := 1.0
var paused := false
var finished := false
var show_bones := false
var skeleton: Skeleton2D
var overlay: Node2D
var blend_from: Dictionary = {}
var blend_age := 0.0
var blend_seconds := .10

class BoneOverlay extends Node2D:
	var puppet: Node2D
	func _draw() -> void:
		if not puppet.show_bones:
			return
		for entry in puppet.data.bones:
			var bone: Bone2D = puppet.bones[entry.name]
			var point := to_local(bone.global_position)
			if entry.has("parent"):
				draw_line(to_local(puppet.bones[entry.parent].global_position), point, Color(.3,.95,.84,.8), 2)
			draw_circle(point, 3.5, Color(1,.76,.38))

func _ready() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(art_root + "/spine/hunter.json"))
	info = JSON.parse_string(FileAccess.get_file_as_string(art_root + "/animation_info.json"))
	skeleton = Skeleton2D.new()
	skeleton.name = "HunterSkeletonV2"
	add_child(skeleton)
	for entry in data.bones:
		var bone := Bone2D.new()
		bone.name = entry.name
		bone.set_autocalculate_length_and_angle(false)
		bone.length = float(entry.get("length", 20))
		var parent_node: Node = bones[entry.parent] if entry.has("parent") else skeleton
		parent_node.add_child(bone)
		bone.position = Vector2(float(entry.get("x",0)), -float(entry.get("y",0)))
		bone.rotation = -deg_to_rad(float(entry.get("rotation",0)))
		bone.rest = bone.transform
		bones[entry.name] = bone
		bone_list.append(bone)
		setup[entry.name] = bone.transform
	var attachments: Dictionary = data.skins[0].attachments
	for i in data.slots.size():
		var slot: Dictionary = data.slots[i]
		var attachment: Dictionary = attachments[slot.name][slot.attachment]
		var texture: Texture2D = load(art_root + "/images/" + str(attachment.path) + ".png")
		if attachment.type == "mesh":
			var polygon := Polygon2D.new()
			polygon.name = slot.name
			polygon.texture = texture
			polygon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			var uv := PackedVector2Array()
			for n in range(0, attachment.uvs.size(), 2):
				uv.append(Vector2(float(attachment.uvs[n])*texture.get_width(), float(attachment.uvs[n+1])*texture.get_height()))
			polygon.uv = uv
			var triangles: Array[PackedInt32Array] = []
			for n in range(0, attachment.triangles.size(), 3):
				triangles.append(PackedInt32Array([int(attachment.triangles[n]), int(attachment.triangles[n+1]), int(attachment.triangles[n+2])]))
			polygon.polygons = triangles
			polygon.z_as_relative = false
			polygon.z_index = i+1
			add_child(polygon)
			var influences: Array = []
			var at := 0
			while at < attachment.vertices.size():
				var count := int(attachment.vertices[at])
				at += 1
				var vertex: Array = []
				for n in count:
					vertex.append([int(attachment.vertices[at]), Vector2(float(attachment.vertices[at+1]), -float(attachment.vertices[at+2])), float(attachment.vertices[at+3])])
					at += 4
				influences.append(vertex)
			meshes[slot.name] = {"node":polygon, "influences":influences}
			sprites[slot.name] = polygon
		else:
			var sprite := Sprite2D.new()
			sprite.name = slot.name
			sprite.texture = texture
			sprite.centered = false
			sprite.offset = -Vector2(texture.get_size())/2.0
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			sprite.position = Vector2(float(attachment.x),-float(attachment.y))
			sprite.rotation = -deg_to_rad(float(attachment.get("rotation",0)))
			sprite.scale = Vector2(float(attachment.width)/texture.get_width(),float(attachment.height)/texture.get_height())
			sprite.z_as_relative = false
			sprite.z_index = i+1
			bones[slot.bone].add_child(sprite)
			sprite.position -= (sprite.get_rect().get_center()*sprite.scale).rotated(sprite.rotation)
			sprites[slot.name] = sprite
	overlay = BoneOverlay.new()
	overlay.puppet = self
	overlay.z_index = 100
	add_child(overlay)
	seek(0)

func sample(keys: Array, time: float, channel: String, fallback: float) -> float:
	var first: Dictionary = keys[0]
	var last: Dictionary = keys[-1]
	# Uniform dense samples keep this bounded even with many animated bones.
	var approximate := clampi(int(time/maxf(float(keys[-1].time),.00001)*(keys.size()-1)),0,keys.size()-2)
	first = keys[approximate]
	last = keys[approximate+1]
	var weight := clampf((time-float(first.time))/maxf(float(last.time)-float(first.time),.000001),0,1)
	return lerpf(float(first.get(channel,fallback)),float(last.get(channel,fallback)),weight)

func apply_pose(time: float) -> void:
	elapsed = clampf(time,0,float(info[current].duration))
	for name in bones:
		bones[name].transform = setup[name]
	var timelines: Dictionary = data.animations[current].bones
	for name in timelines:
		var bone: Bone2D = bones[name]
		var rest: Transform2D = setup[name]
		var channels: Dictionary = timelines[name]
		if channels.has("rotate"):
			bone.rotation = rest.get_rotation()-deg_to_rad(sample(channels.rotate,elapsed,"value",0))
		if channels.has("translate"):
			bone.position = rest.origin+Vector2(sample(channels.translate,elapsed,"x",0),-sample(channels.translate,elapsed,"y",0))
		if channels.has("scale"):
			bone.scale = Vector2(sample(channels.scale,elapsed,"x",1),sample(channels.scale,elapsed,"y",1))
	apply_draw_order(elapsed)

func apply_draw_order(time: float) -> void:
	var selected: Dictionary = {}
	for key: Dictionary in data.animations[current].get("drawOrder", []):
		if float(key.get("time", 0)) > time:
			break
		selected = key
	var order: Array = range(data.slots.size())
	if selected.has("offsets"):
		order.fill(-1)
		var unchanged: Array[int] = []
		var original := 0
		for offset: Dictionary in selected.offsets:
			var slot_index := 0
			while data.slots[slot_index].name != offset.slot:
				slot_index += 1
			while original < slot_index:
				unchanged.append(original)
				original += 1
			order[original + int(offset.offset)] = original
			original += 1
		while original < data.slots.size():
			unchanged.append(original)
			original += 1
		for index in range(order.size()-1, -1, -1):
			if order[index] == -1:
				order[index] = unchanged.pop_back()
	for index in order.size():
		sprites[data.slots[order[index]].name].z_index = index + 1

func update_meshes() -> void:
	var transforms: Array[Transform2D] = []
	var inverse := global_transform.affine_inverse()
	for bone in bone_list:
		transforms.append(inverse*bone.global_transform)
	for entry in meshes.values():
		var vertices := PackedVector2Array()
		for influences: Array in entry.influences:
			var point := Vector2.ZERO
			for influence: Array in influences:
				point += (transforms[influence[0]]*influence[1])*float(influence[2])
			vertices.append(point)
		entry.node.polygon = vertices
	if overlay:
		overlay.queue_redraw()

func seek(time: float) -> void:
	# Exact sampling for import/render verification; runtime play blends separately.
	apply_pose(time)
	update_meshes()

func snapshot_pose() -> Dictionary:
	var result: Dictionary = {}
	for name in bones:
		result[name] = bones[name].transform
	return result

func mix_pose(weight: float) -> void:
	for name in blend_from:
		var source: Transform2D = blend_from[name]
		var bone: Bone2D = bones[name]
		bone.position = source.origin.lerp(bone.position,weight)
		bone.rotation = lerp_angle(source.get_rotation(),bone.rotation,weight)
		bone.scale = source.get_scale().lerp(bone.scale,weight)

func play(animation_name: String, restart := true) -> void:
	if not info.has(animation_name) or (animation_name == current and not restart):
		return
	var phase := elapsed/maxf(float(info[current].duration),.001)
	var preserve_phase := current in ["walk","run"] and animation_name in ["walk","run"]
	blend_from = snapshot_pose()
	current = animation_name
	finished = false
	blend_age = 0
	blend_seconds = .035 if current == "hit" else .045 if current == "light_slash" else .055 if current == "dodge" else .085 if current == "heavy_strike" else .12
	apply_pose(phase*float(info[current].duration) if preserve_phase else 0.0)
	mix_pose(0)
	update_meshes()

func snap_to(animation_name: String) -> void:
	current = animation_name
	finished = false
	blend_from.clear()
	blend_age = 1.0
	seek(0)

func _process(delta: float) -> void:
	if paused or finished:
		return
	var next := elapsed+delta*speed_scale
	var duration := float(info[current].duration)
	if next >= duration:
		if bool(info[current].loop):
			next = fmod(next,duration)
		else:
			next = duration
			finished = true
	apply_pose(next)
	if not blend_from.is_empty():
		blend_age += delta
		var amount := clampf(blend_age/blend_seconds,0,1)
		mix_pose(amount*amount*(3-2*amount))
		if amount >= 1:
			blend_from.clear()
	update_meshes()
	if finished:
		animation_finished.emit(current)

func get_local_bounds() -> Rect2:
	var result := Rect2()
	var first := true
	for name in sprites:
		var points := PackedVector2Array()
		if meshes.has(name):
			points = meshes[name].node.polygon
		else:
			var sprite: Sprite2D = sprites[name]
			var rect := sprite.get_rect()
			var relative := global_transform.affine_inverse()*sprite.global_transform
			for point in [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]:
				points.append(relative*point)
		for point in points:
			if first:
				result = Rect2(point,Vector2.ZERO)
				first = false
			else:
				result = result.expand(point)
	return result
