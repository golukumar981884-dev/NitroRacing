extends Node3D

var car: Node3D
var camera: Camera3D
var speed := 0.0
var steering := 0.0
var nitro := 100.0
var race_time := 0.0
var distance := 0.0
var accelerate := false
var braking := false
var steer_left := false
var steer_right := false
var nitro_on := false
var hud_speed: Label
var hud_nitro: Label
var hud_time: Label
var wheels: Array[MeshInstance3D] = []
var nitro_flames: Array[MeshInstance3D] = []

const MAX_SPEED := 92.0

func _ready() -> void:
	_build_world()
	_build_car()
	_build_camera()
	_build_hud()

func _process(delta: float) -> void:
	race_time += delta
	var throttle := 1.0 if accelerate else 0.0
	var brake := 1.0 if braking else 0.0
	var boost := nitro_on and nitro > 0.0 and throttle > 0.0
	var target := MAX_SPEED * throttle
	if boost:
		target *= 1.42
		nitro = maxf(0.0, nitro - 28.0 * delta)
	else:
		nitro = minf(100.0, nitro + 8.0 * delta)
	if brake > 0.0:
		target = 0.0
	speed = move_toward(speed, target, (34.0 if throttle > 0.0 else 46.0) * delta)
	var steer_input := float(steer_right) - float(steer_left)
	steering = move_toward(steering, steer_input, delta * 3.5)
	car.rotate_y(-steering * delta * (0.8 + speed / MAX_SPEED))
	car.translate(Vector3(steering * speed * delta * 0.22, 0, -speed * delta * 0.34))
	car.position.x = clampf(car.position.x, -13.0, 13.0)
	for wheel in wheels:
		wheel.rotate_object_local(Vector3.RIGHT, speed * delta * 0.19)
	for flame in nitro_flames:
		flame.visible = boost
		flame.scale.z = randf_range(0.85, 1.35) if boost else 1.0
	distance += speed * delta / 1000.0
	camera.global_position = camera.global_position.lerp(car.global_position + Vector3(0, 5.2, 10.5), delta * 4.0)
	camera.fov = lerpf(camera.fov, 74.0 + (12.0 if boost else 0.0), delta * 3.0)
	camera.look_at(car.global_position + Vector3(0, 1.0, -5.0), Vector3.UP)
	hud_speed.text = "%03d KM/H" % int(speed * 2.15)
	hud_nitro.text = "NITRO  %d%%" % int(nitro)
	hud_time.text = "TIME  %02d:%02d" % [int(race_time) / 60, int(race_time) % 60]

func _mat(color: Color, metallic := 0.0, roughness := 0.55) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m

func _box(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.position = pos
	n.material_override = material
	parent.add_child(n)
	return n

func _mountain(parent: Node3D, pos: Vector3, size: Vector3, material: Material, seed_value: int) -> void:
	var rock := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radial_segments = 24
	mesh.rings = 14
	rock.mesh = mesh
	rock.position = pos
	rock.scale = size
	rock.rotation_degrees = Vector3(float(seed_value % 17), float(seed_value * 13 % 360), float(seed_value * 7 % 12))
	rock.material_override = material
	parent.add_child(rock)

func _surface_material(is_road: bool) -> Material:
	if is_road:
		var albedo_path := "res://assets/textures/road_albedo.jpg"
		var normal_path := "res://assets/textures/road_normal.jpg"
		var roughness_path := "res://assets/textures/road_roughness.jpg"
		if ResourceLoader.exists(albedo_path) and ResourceLoader.exists(normal_path) and ResourceLoader.exists(roughness_path):
			var pbr := StandardMaterial3D.new()
			pbr.albedo_texture = load(albedo_path) as Texture2D
			pbr.normal_enabled = true
			pbr.normal_texture = load(normal_path) as Texture2D
			pbr.normal_scale = 0.7
			pbr.roughness_texture = load(roughness_path) as Texture2D
			pbr.roughness = 0.92
			pbr.metallic = 0.0
			pbr.uv1_scale = Vector3(7.0, 70.0, 1.0)
			return pbr
	var shader := Shader.new()
	if is_road:
		shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
void fragment() {
	vec2 p = UV * vec2(220.0, 1100.0);
	float grain = hash21(floor(p * 1.7));
	float fine_grain = hash21(floor(p * 7.0));
	float patch = sin(p.x * 0.12 + sin(p.y * 0.035)) * 0.025;
	float value = 0.105 + (grain - 0.5) * 0.055 + (fine_grain - 0.5) * 0.025 + patch;
	ALBEDO = vec3(value * 0.82, value * 0.88, value);
	ROUGHNESS = 0.88 + fine_grain * 0.08;
	METALLIC = 0.0;
}
"""
	else:
		shader.code = """
shader_type spatial;
render_mode diffuse_burley;
float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.5);
	return fract(p.x * p.y);
}
void fragment() {
	vec2 p = UV * 95.0;
	float n = hash21(floor(p)) * 0.12 + hash21(floor(p * 3.0)) * 0.035;
	float bands = sin(UV.y * 190.0 + sin(UV.x * 80.0)) * 0.018;
	ALBEDO = vec3(0.105 + n + bands, 0.17 + n, 0.105 + n * 0.45);
	ROUGHNESS = 1.0;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

func _plane(parent: Node3D, size: Vector2, pos: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = size
	mesh.subdivide_width = 8
	mesh.subdivide_depth = 64
	node.mesh = mesh
	node.position = pos
	node.material_override = material
	parent.add_child(node)
	return node

func _tree(parent: Node3D, x: float, z: float, height: float, variant: int) -> void:
	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.16
	trunk_mesh.bottom_radius = 0.28
	trunk_mesh.height = height * 0.55
	trunk.mesh = trunk_mesh
	trunk.position = Vector3(x, height * 0.275 - 0.15, z)
	trunk.material_override = _mat(Color(0.20, 0.13, 0.085), 0.0, 0.98)
	parent.add_child(trunk)
	var crown := MeshInstance3D.new()
	var crown_mesh := SphereMesh.new()
	crown_mesh.radial_segments = 12
	crown_mesh.rings = 8
	crown.mesh = crown_mesh
	crown.position = Vector3(x, height * 0.72 - 0.15, z)
	crown.scale = Vector3(1.25, 1.65, 1.2) if variant % 2 == 0 else Vector3(1.0, 1.35, 1.0)
	crown.material_override = _mat(Color(0.055 + float(variant % 3) * 0.012, 0.16 + float(variant % 4) * 0.018, 0.085), 0.0, 0.96)
	parent.add_child(crown)

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = Sky.new()
	e.sky.sky_material = ProceduralSkyMaterial.new()
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.62, 0.78)
	e.ambient_light_energy = 0.95
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.38
	e.glow_strength = 0.75
	e.fog_enabled = true
	e.fog_light_color = Color(0.58, 0.65, 0.76)
	e.fog_density = 0.0035
	e.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 1.55
	sun.light_color = Color(1.0, 0.91, 0.78)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 95.0
	add_child(sun)
	var road := _surface_material(true)
	var edge := _mat(Color(0.88, 0.9, 0.94), 0.0, 0.8)
	var grass := _surface_material(false)
	var rail := _mat(Color(0.48, 0.56, 0.64), 0.72, 0.28)
	var lane := _mat(Color(0.95, 0.82, 0.38), 0.05, 0.55)
	_plane(self, Vector2(220, 320), Vector3(0, -0.28, -100), grass)
	_plane(self, Vector2(30, 280), Vector3(0, -0.045, -100), road)
	var shoulder := _mat(Color(0.31, 0.29, 0.25), 0.0, 0.95)
	_box(self, Vector3(2.0, 0.08, 280), Vector3(-16.0, -0.12, -100), shoulder)
	_box(self, Vector3(2.0, 0.08, 280), Vector3(16.0, -0.12, -100), shoulder)
	for z in range(-230, 40, 18):
		_box(self, Vector3(0.22, 0.025, 7), Vector3(0, -0.035, z), edge)
		_box(self, Vector3(0.13, 0.03, 7), Vector3(-5.2, -0.025, z), lane)
		_box(self, Vector3(0.13, 0.03, 7), Vector3(5.2, -0.025, z), lane)
		_box(self, Vector3(0.6, 0.25, 8), Vector3(-15.4, -0.05, z), edge)
		_box(self, Vector3(0.6, 0.25, 8), Vector3(15.4, -0.05, z), edge)
	for side in [-1.0, 1.0]:
		_box(self, Vector3(0.32, 0.65, 280), Vector3(side * 15.0, 0.18, -100), rail)
		_box(self, Vector3(0.18, 0.22, 280), Vector3(side * 15.0, 0.62, -100), edge)
	var rock := _mat(Color(0.28, 0.31, 0.36), 0.0, 0.98)
	for i in range(38):
		var z := -224.0 + float(i) * 6.0
		for side in [-1.0, 1.0]:
			var x: float = float(side) * (23.0 + float((i * 7) % 14))
			var h := 5.5 + float((i * 3) % 9)
			if i % 3 == 0:
				_mountain(self, Vector3(x, h * 0.42, z), Vector3(2.2, h * 0.8, 2.0), rock, i * 5)
			else:
				_tree(self, x, z, h, i)

	# Layered canyon cliffs create a stronger sense of scale around the road.
	var cliff_dark := _mat(Color(0.16, 0.19, 0.25), 0.0, 1.0)
	var cliff_warm := _mat(Color(0.34, 0.25, 0.19), 0.0, 0.96)
	var cliff_light := _mat(Color(0.43, 0.39, 0.32), 0.0, 0.94)
	for i in range(19):
		var z := -235.0 + float(i) * 13.0
		for side in [-1.0, 1.0]:
			var x: float = float(side) * (29.0 + float((i * 11) % 10))
			var h: float = 17.0 + float((i * 7) % 15)
			var w: float = 12.0 + float((i * 5) % 9)
			var depth: float = 17.0 + float((i * 3) % 12)
			var cliff_mat: Material = cliff_warm if i % 3 == 0 else (cliff_light if i % 3 == 1 else cliff_dark)
			_mountain(self, Vector3(x, h * 0.42, z), Vector3(w, h, depth), cliff_mat, i * 9 + int(side))
			_mountain(self, Vector3(x + side * 8.0, h * 0.62, z - 5.0), Vector3(w * 0.68, h * 0.78, depth * 0.72), cliff_dark, i * 13)
	# Tall roadside rock spires and reflective track markers.
	for i in range(13):
		var z := -218.0 + float(i) * 17.0
		for side in [-1.0, 1.0]:
			var spire_h: float = 8.0 + float((i * 5) % 8)
			_mountain(self, Vector3(side * (19.0 + float(i % 3) * 2.0), spire_h * 0.5, z), Vector3(2.4, spire_h, 2.8), cliff_warm if i % 2 == 0 else cliff_dark, i + 31)
	var glow := _mat(Color(0.0, 0.75, 1.0), 0.25, 0.25)
	for z in [-30.0, -95.0, -160.0]:
		_box(self, Vector3(0.35, 7, 0.35), Vector3(-14.0, 3.5, z), glow)
		_box(self, Vector3(0.35, 7, 0.35), Vector3(14.0, 3.5, z), glow)
	# Repeating reflector posts and metal guardrail supports add roadside scale.
	var post_mat := _mat(Color(0.72, 0.76, 0.78), 0.68, 0.32)
	var reflector := _mat(Color(1.0, 0.72, 0.25), 0.05, 0.25)
	for i in range(56):
		var z := -232.0 + float(i) * 5.0
		for side in [-1.0, 1.0]:
			_box(self, Vector3(0.12, 0.95, 0.12), Vector3(side * 14.55, 0.48, z), post_mat)
			_box(self, Vector3(0.14, 0.16, 0.04), Vector3(side * 14.55, 0.82, z - 0.07), reflector)
	# Layered roadside shoulders and small rock clusters break up the flat horizon.
	for i in range(42):
		var z := -228.0 + float(i) * 5.2
		for side in [-1.0, 1.0]:
			var x := side * (18.5 + float((i * 9) % 8))
			var scale_value := 0.65 + float(i % 4) * 0.22
			_mountain(self, Vector3(x, 0.35 * scale_value, z), Vector3(1.1, 0.65, 1.4) * scale_value, cliff_warm if i % 2 == 0 else cliff_dark, i * 17)

func _build_car() -> void:
	car = Node3D.new()
	car.position = Vector3(0, 0.35, 4)
	add_child(car)

	# Prefer the textured, real-world-scale CC0 supercar downloaded by CI.
	# Keep the procedural car as a safe fallback for editor runs without the asset.
	var model_path := "res://assets/cars/player_supercar.glb"
	if ResourceLoader.exists(model_path):
		var packed_model := load(model_path) as PackedScene
		if packed_model != null:
			var model := packed_model.instantiate() as Node3D
			if model != null:
				model.scale = Vector3.ONE
				model.position = Vector3(0, 0.25, 0)
				car.add_child(model)
				return

	var paint := _mat(Color(0.015, 0.32, 0.96), 0.9, 0.16)
	var paint_dark := _mat(Color(0.008, 0.075, 0.22), 0.82, 0.22)
	var glass := _mat(Color(0.012, 0.035, 0.065), 0.72, 0.1)
	var trim := _mat(Color(0.008, 0.012, 0.02), 0.5, 0.28)
	var alloy := _mat(Color(0.62, 0.76, 0.88), 0.92, 0.16)
	var red := _mat(Color(1.0, 0.025, 0.018), 0.25, 0.2)
	var rubber := _mat(Color(0.008, 0.01, 0.015), 0.0, 0.98)
	_box(car, Vector3(2.12, 0.42, 4.35), Vector3(0, 0.43, 0), paint)
	_box(car, Vector3(1.92, 0.22, 2.65), Vector3(0, 0.67, -0.48), paint)
	_box(car, Vector3(1.72, 0.58, 1.82), Vector3(0, 0.96, -0.18), glass)
	_box(car, Vector3(1.82, 0.12, 0.72), Vector3(0, 1.28, -0.1), paint_dark)
	_box(car, Vector3(1.92, 0.13, 0.82), Vector3(0, 0.62, 1.48), paint)
	_box(car, Vector3(2.18, 0.12, 0.42), Vector3(0, 0.25, -2.18), trim)
	_box(car, Vector3(2.25, 0.10, 0.42), Vector3(0, 0.18, 2.13), paint_dark)
	_box(car, Vector3(2.28, 0.10, 0.36), Vector3(0, 0.19, -2.3), alloy)
	_box(car, Vector3(0.13, 0.22, 3.25), Vector3(-1.08, 0.22, 0), trim)
	_box(car, Vector3(0.13, 0.22, 3.25), Vector3(1.08, 0.22, 0), trim)
	_box(car, Vector3(2.05, 0.12, 0.18), Vector3(0, 1.32, 1.72), trim)
	_box(car, Vector3(0.12, 0.42, 0.12), Vector3(-0.72, 1.12, 1.72), trim)
	_box(car, Vector3(0.12, 0.42, 0.12), Vector3(0.72, 1.12, 1.72), trim)
	_box(car, Vector3(0.28, 0.18, 0.42), Vector3(-1.12, 0.82, -0.78), paint)
	_box(car, Vector3(0.28, 0.18, 0.42), Vector3(1.12, 0.82, -0.78), paint)
	for x in [-1.08, 1.08]:
		for z in [-1.38, 1.38]:
			var wheel := MeshInstance3D.new()
			var wheel_mesh := CylinderMesh.new()
			wheel_mesh.top_radius = 0.44
			wheel_mesh.bottom_radius = 0.44
			wheel_mesh.height = 0.32
			wheel.mesh = wheel_mesh
			wheel.position = Vector3(x, 0.32, z)
			wheel.rotation.z = PI / 2.0
			wheel.material_override = rubber
			car.add_child(wheel)
			wheels.append(wheel)
			var hub := MeshInstance3D.new()
			var hub_mesh := CylinderMesh.new()
			hub_mesh.top_radius = 0.23
			hub_mesh.bottom_radius = 0.23
			hub_mesh.height = 0.335
			hub.mesh = hub_mesh
			hub.position = Vector3(x * 1.01, 0.32, z)
			hub.rotation.z = PI / 2.0
			hub.material_override = alloy
			car.add_child(hub)
	var lamp := _mat(Color(0.65, 0.92, 1.0), 0.15, 0.08)
	_box(car, Vector3(0.62, 0.12, 0.09), Vector3(-0.59, 0.55, -2.2), lamp)
	_box(car, Vector3(0.62, 0.12, 0.09), Vector3(0.59, 0.55, -2.2), lamp)
	_box(car, Vector3(0.52, 0.12, 0.08), Vector3(-0.65, 0.49, 2.2), red)
	_box(car, Vector3(0.52, 0.12, 0.08), Vector3(0.65, 0.49, 2.2), red)
	var flame_mat := StandardMaterial3D.new()
	flame_mat.albedo_color = Color(0.05, 0.72, 1.0)
	flame_mat.emission_enabled = true
	flame_mat.emission = Color(0.02, 0.62, 1.0)
	flame_mat.emission_energy_multiplier = 3.5
	for x in [-0.48, 0.48]:
		var flame := _box(car, Vector3(0.22, 0.22, 0.85), Vector3(x, 0.34, 2.68), flame_mat)
		flame.visible = false
		nitro_flames.append(flame)

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.position = Vector3(0, 5.5, 14)
	camera.fov = 74
	camera.current = true
	add_child(camera)
	camera.look_at(car.position + Vector3(0, 1, -5), Vector3.UP)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := ColorRect.new()
	panel.color = Color(0.015, 0.035, 0.07, 0.72)
	panel.position = Vector2(20, 18)
	panel.size = Vector2(330, 112)
	layer.add_child(panel)
	hud_speed = Label.new()
	hud_speed.position = Vector2(38, 25)
	hud_speed.add_theme_font_size_override("font_size", 38)
	hud_speed.add_theme_color_override("font_color", Color(0.2, 0.88, 1))
	panel.add_child(hud_speed)
	hud_nitro = Label.new()
	hud_nitro.position = Vector2(18, 72)
	hud_nitro.add_theme_font_size_override("font_size", 19)
	panel.add_child(hud_nitro)
	hud_time = Label.new()
	hud_time.position = Vector2(1030, 30)
	hud_time.add_theme_font_size_override("font_size", 26)
	layer.add_child(hud_time)
	var credits := Label.new()
	credits.text = "Powered by Poly Haven"
	credits.position = Vector2(1010, 66)
	credits.add_theme_font_size_override("font_size", 12)
	credits.add_theme_color_override("font_color", Color(0.72, 0.82, 0.92, 0.82))
	layer.add_child(credits)
	_make_button(layer, "◀", Vector2(38, 560), Vector2(112, 112), "left")
	_make_button(layer, "▶", Vector2(164, 560), Vector2(112, 112), "right")
	_make_button(layer, "BRAKE", Vector2(850, 580), Vector2(125, 88), "brake")
	_make_button(layer, "GO", Vector2(1000, 535), Vector2(220, 145), "go")
	_make_button(layer, "NITRO", Vector2(1040, 420), Vector2(150, 82), "nitro")

func _make_button(parent: Node, caption: String, pos: Vector2, size: Vector2, action: String) -> void:
	var b := Button.new()
	b.text = caption
	b.position = pos
	b.size = size
	b.add_theme_font_size_override("font_size", 26 if action != "go" else 34)
	b.modulate = Color(0.55, 0.85, 1.0, 0.9) if action == "nitro" else Color(1, 1, 1, 0.88)
	parent.add_child(b)
	b.button_down.connect(func(): _set_action(action, true))
	b.button_up.connect(func(): _set_action(action, false))

func _set_action(action: String, value: bool) -> void:
	match action:
		"left": steer_left = value
		"right": steer_right = value
		"brake": braking = value
		"go": accelerate = value
		"nitro": nitro_on = value
