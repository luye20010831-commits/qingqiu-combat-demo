extends Node
## Rooted foliage, decorative clouds and translucent mist crossing the whole map.
@export var animate := true
@export_range(0.0,2.0) var wind_scale := 1.0
@export_range(0.1,2.0) var wind_speed := 1.0
@export_range(0.0,2.0) var cloud_drift := 1.0
@export_range(0.1,6.0) var cloud_speed := 3.2
@export_group("祥云：远层 / 中层 / 近层")
@export var cloud_layer_opacities := Vector3(0.055,0.14,0.075)
@export var cloud_layer_speeds := Vector3(0.72,1.0,1.38)
@export_range(24.0,40.0) var cloud_travel_half_extent := 30.0
@export_group("全地图漂雾")
@export_range(0.0,3.0) var mist_drift_speed := 1.65
@export_range(20.0,36.0) var mist_travel_half_extent := 24.0
@export_range(0.0,2.0) var mist_density_scale := 0.92
@export_range(1.0,2.0) var p3_mist_footprint_scale := 1.40
var mist_phase:=1
var mist_sizes: Array[Vector3]=[]
var mist_layers: Array[int]=[]
var mist_hover_offsets: Array[float]=[]
var elapsed := 0.0
var foliage: Array[ShaderMaterial] = []
var cloud_nodes: Array[MeshInstance3D] = []
var cloud_bases: Array[Transform3D] = []
var cloud_layers: Array[int] = []
var cloud_clusters: Array[int] = []
var mist_nodes: Array[FogVolume] = []
var mist_bases: Array[Vector3] = []
var mist_velocities: Array[Vector2] = []
var mist_gains: Array[float] = []
var ground_mist: FogVolume

func _ready() -> void:
	for node in get_parent().find_children("*","Sprite3D",true,false):
		var material = node.material_override
		if material is ShaderMaterial and material.shader.resource_path.ends_with("ink_prop.gdshader") and material.get_shader_parameter("wind_strength") > 0.0:
			foliage.append(material)
	var root:=get_parent().get_node("GroundClouds")
	var originals: Array=root.get_children()
	for index in originals.size():
		var original: MeshInstance3D=originals[index]
		var base:=original.transform
		register_cloud(original,base,index,1)
		for layer in [0,2]:
			var cloud:=MeshInstance3D.new()
			cloud.name="Xiangyun%d_%s"%[index,"Far" if layer==0 else "Near"]
			cloud.mesh=original.mesh
			cloud.material_override=original.material_override.duplicate()
			cloud.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(cloud)
			var layer_base:=base.scaled_local(Vector3(1.10,1.0,1.06) if layer==0 else Vector3(0.86,1.0,0.90))
			layer_base.origin+=base.basis*(Vector3(-0.70,0,0.28) if layer==0 else Vector3(0.55,0,-0.22))
			register_cloud(cloud,layer_base,index,layer)
	configure_ground_mist()
	apply_motion()

func configure_ground_mist() -> void:
	ground_mist=get_parent().get_node("Atmosphere/GroundMist")
	ground_mist.size=Vector3(62,0.46,62)
	ground_mist.position.y=0.20
	ground_mist.material=ground_mist.material.duplicate()
	configure_mist_material(ground_mist.material,0)
	ground_mist.material.set_shader_parameter("fade_out_height",0.06)
	ground_mist.material.set_shader_parameter("fade_out_distance",0.34)
	var root:=get_parent().get_node("Atmosphere/MistBanks")
	var originals: Array=root.get_children()
	var source_material: ShaderMaterial=originals[0].material
	# An 8x8 distribution fills the clearing at startup. Layer checkerboarding
	# avoids putting every elevated bank along the same row or map edge.
	for index in 64:
		var row:=int(index/8);var column:=index%8
		var layer: int=[0,1,0,2][(row*3+column)%4]
		var bank: FogVolume=originals[index] if index<originals.size() else FogVolume.new()
		if index>=originals.size():
			bank.name="GlobalDriftingMist%02d"%(index+1);root.add_child(bank)
		bank.shape=RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
		bank.material=source_material.duplicate()
		var x: float=-17.5+float(column)*5.0+sin(float(index)*2.17)*.85
		var z: float=-17.5+float(row)*5.0+cos(float(index)*1.73)*.85
		var height: float=[.68,.90,.80][layer]+float(index%3)*.07
		bank.size=Vector3(9.0+float(index%4)*1.25,height,6.0+float(index%3)*1.0)
		bank.position=Vector3(x,height*.5-.04+[0.0,.58,1.32][layer],z)
		bank.rotation.y=sin(float(index)*.79)*.68
		bank.set_meta("mist_layer",layer)
		bank.set_meta("density_scale",[.65,.48,.32][layer])
		register_mist(bank,index)

func configure_mist_material(surface: ShaderMaterial,index: int) -> void:
	surface.resource_local_to_scene=true
	surface.set_shader_parameter("custom_clock",true)
	surface.set_shader_parameter("seed",float(index)*1.73)
	surface.set_shader_parameter("fade_out_height",0.10)
	surface.set_shader_parameter("fade_out_distance",0.42)
	surface.set_shader_parameter("noise_velocity1",Vector3(-0.032,0,-0.010))
	surface.set_shader_parameter("noise_velocity2",Vector3(-0.060,0,0.020))
	surface.set_shader_parameter("noise_velocity3",Vector3(-0.090,0,-0.025))

func register_mist(bank: FogVolume,index: int) -> void:
	configure_mist_material(bank.material,index+1)
	var layer:=int(bank.get_meta("mist_layer",0))
	bank.material.set_shader_parameter("local_height_fade",layer>0)
	mist_nodes.append(bank)
	mist_bases.append(bank.position)
	mist_sizes.append(bank.size)
	mist_layers.append(layer)
	mist_hover_offsets.append([0.0,.58,1.32][layer])
	mist_velocities.append(Vector2(.48+float(index%5)*.07,.10+sin(float(index)*.93)*.16))
	# More banks use less optical density individually. High wisps are lighter.
	mist_gains.append([12.0,9.0,7.0][layer])

func register_cloud(cloud: MeshInstance3D,base: Transform3D,cluster: int,layer: int) -> void:
	base.origin.y=0.03+float(layer)*0.05+float(cluster)*0.002
	cloud.set_meta("cloud_layer",layer)
	cloud.set_meta("cloud_cluster",cluster)
	cloud.material_override.resource_local_to_scene=true
	cloud.material_override.render_priority=layer
	cloud.material_override.set_shader_parameter("seed",float(cluster)*1.4+float(layer-1)*0.47)
	cloud.material_override.set_shader_parameter("drift_speed",0.35)
	cloud.material_override.set_shader_parameter("tail_extension",0.10)
	cloud_nodes.append(cloud)
	cloud_bases.append(base)
	cloud_layers.append(layer)
	cloud_clusters.append(cluster)

func apply_phase(value: int) -> void:
	mist_phase=value
	if ground_mist==null:return
	var large:=value==3
	ground_mist.size=Vector3(77.5,.55,77.5) if large else Vector3(62,.46,62)
	ground_mist.position.y=.24 if large else .20
	ground_mist.material.set_shader_parameter("fade_out_height",.08 if large else .06)
	ground_mist.material.set_shader_parameter("fade_out_distance",.38 if large else .34)
	for index in mist_nodes.size():
		var size: Vector3=mist_sizes[index]
		mist_nodes[index].size=Vector3(size.x*p3_mist_footprint_scale,size.y*1.20,size.z*p3_mist_footprint_scale) if large else size
		mist_bases[index].y=mist_nodes[index].size.y*.5-.04+mist_hover_offsets[index]
		mist_nodes[index].material.set_shader_parameter("fade_out_height",.14 if large else .10)
		mist_nodes[index].material.set_shader_parameter("fade_out_distance",.46 if large else .42)
	apply_motion()

func _process(delta: float) -> void:
	if animate: elapsed += delta*wind_speed
	apply_motion()

func apply_motion() -> void:
	for material in foliage:
		material.set_shader_parameter("custom_clock",true)
		material.set_shader_parameter("wind_clock",elapsed)
		material.set_shader_parameter("wind_scale",wind_scale)
	for index in cloud_nodes.size():
		var cloud := cloud_nodes[index]
		var base := cloud_bases[index]
		var layer:=cloud_layers[index]
		var phase := float(cloud_clusters[index])*1.17+float(layer)*0.73
		var clock:=elapsed*cloud_speed*cloud_layer_speeds[layer]
		cloud.transform = base
		# Let the visible cloud bodies travel across the clearing, rather than
		# oscillating only a metre around their original positions.
		cloud.position.x=wrapf(base.origin.x+clock*0.18*cloud_drift,-cloud_travel_half_extent,cloud_travel_half_extent)
		cloud.position.y+=(sin(clock*0.27+phase)-sin(phase))*0.004*cloud_drift
		cloud.position.z+=(cos(clock*0.045+phase)-cos(phase))*1.60*cloud_drift
		cloud.rotate_y((sin(clock*0.10+phase)-sin(phase))*0.025*cloud_drift)
		cloud.material_override.set_shader_parameter("custom_clock",true)
		cloud.material_override.set_shader_parameter("cloud_clock",clock)
		var cloud_edge:=cloud_travel_half_extent-absf(cloud.position.x)
		cloud.material_override.set_shader_parameter("opacity",clampf(cloud_layer_opacities[layer],0.0,1.0)*smoothstep(0.0,7.0,cloud_edge))
	if ground_mist!=null:
		ground_mist.material.set_shader_parameter("mist_clock",elapsed*mist_drift_speed)
		ground_mist.material.set_shader_parameter("density_gain",2.20*mist_density_scale*(1.12 if mist_phase==3 else 1.0))
	for index in mist_nodes.size():
		var bank:=mist_nodes[index]
		var base:=mist_bases[index]
		var velocity:=mist_velocities[index]
		var clock:=elapsed*mist_drift_speed
		var phase:=float(index)*1.71
		var bob: float=(sin(clock*.16+phase)-sin(phase))*[.025,.065,.095][mist_layers[index]]
		bank.position=Vector3(wrapf(base.x+velocity.x*clock,-mist_travel_half_extent,mist_travel_half_extent),base.y+bob,wrapf(base.z+velocity.y*clock,-mist_travel_half_extent,mist_travel_half_extent))
		var edge:=minf(mist_travel_half_extent-absf(bank.position.x),mist_travel_half_extent-absf(bank.position.z))
		var surface: ShaderMaterial=bank.material
		surface.set_shader_parameter("mist_clock",clock)
		surface.set_shader_parameter("density_gain",mist_gains[index]*mist_density_scale*(1.12 if mist_phase==3 else 1.0))
		surface.set_shader_parameter("travel_fade",smoothstep(0.0,4.0,edge))
