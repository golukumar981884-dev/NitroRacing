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
	distance += speed * delta / 1000.0
	camera.global_position = camera.global_position.lerp(car.global_position + Vector3(0, 5.2, 10.5), delta * 4.0)
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

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = Sky.new()
	e.sky.sky_material = ProceduralSkyMaterial.new()
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.62, 0.78)
	e.ambient_light_energy = 0.75
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	add_child(sun)
	var road := _mat(Color(0.075, 0.085, 0.105), 0.05, 0.92)
	var edge := _mat(Color(0.88, 0.9, 0.94), 0.0, 0.8)
	var grass := _mat(Color(0.11, 0.24, 0.18), 0.0, 1.0)
	_box(self, Vector3(200, 0.2, 300), Vector3(0, -0.35, -100), grass)
	_box(self, Vector3(30, 0.25, 280), Vector3(0, -0.18, -100), road)
	for z in range(-230, 40, 18):
		_box(self, Vector3(0.22, 0.025, 7), Vector3(0, -0.035, z), edge)
		_box(self, Vector3(0.6, 0.25, 8), Vector3(-15.4, -0.05, z), edge)
		_box(self, Vector3(0.6, 0.25, 8), Vector3(15.4, -0.05, z), edge)
	var rock := _mat(Color(0.28, 0.31, 0.36), 0.0, 1.0)
	var tree := _mat(Color(0.08, 0.25, 0.16), 0.0, 0.9)
	for i in range(34):
		var z := -220.0 + float(i) * 7.0
		for side in [-1.0, 1.0]:
			var x: float = float(side) * (22.0 + float((i * 7) % 13))
			var h := 7.0 + float((i * 3) % 11)
			_box(self, Vector3(5.0, h, 5.0), Vector3(x, h * 0.5 - 0.2, z), rock if i % 3 == 0 else tree)
	var glow := _mat(Color(0.0, 0.75, 1.0), 0.25, 0.25)
	for z in [-30.0, -95.0, -160.0]:
		_box(self, Vector3(0.35, 7, 0.35), Vector3(-14.0, 3.5, z), glow)
		_box(self, Vector3(0.35, 7, 0.35), Vector3(14.0, 3.5, z), glow)

func _build_car() -> void:
	car = Node3D.new()
	car.position = Vector3(0, 0.35, 4)
	add_child(car)
	var paint := _mat(Color(0.02, 0.42, 0.95), 0.82, 0.2)
	var glass := _mat(Color(0.025, 0.055, 0.09), 0.5, 0.12)
	var rubber := _mat(Color(0.012, 0.014, 0.02), 0.0, 0.95)
	_box(car, Vector3(2.05, 0.58, 4.25), Vector3(0, 0.48, 0), paint)
	_box(car, Vector3(1.55, 0.55, 1.9), Vector3(0, 0.98, -0.25), glass)
	_box(car, Vector3(1.9, 0.16, 0.55), Vector3(0, 0.3, -2.0), paint)
	for x in [-1.08, 1.08]:
		for z in [-1.35, 1.35]:
			var wheel := _box(car, Vector3(0.34, 0.72, 0.82), Vector3(x, 0.18, z), rubber)
			wheel.rotation.z = PI / 2.0
	var lamp := _mat(Color(0.65, 0.9, 1.0), 0.0, 0.12)
	_box(car, Vector3(0.55, 0.13, 0.08), Vector3(-0.58, 0.57, -2.14), lamp)
	_box(car, Vector3(0.55, 0.13, 0.08), Vector3(0.58, 0.57, -2.14), lamp)

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
