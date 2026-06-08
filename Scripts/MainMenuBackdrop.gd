@tool
extends Control

const DESIGN_SIZE := Vector2(640.0, 360.0)

var time_passed: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(true)

func _process(delta: float) -> void:
	time_passed += delta
	queue_redraw()

func _draw() -> void:
	var viewport_size := size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = get_viewport_rect().size

	var cover_scale := maxf(viewport_size.x / DESIGN_SIZE.x, viewport_size.y / DESIGN_SIZE.y)
	var draw_origin := (viewport_size - DESIGN_SIZE * cover_scale) * 0.5
	draw_set_transform(draw_origin, 0.0, Vector2.ONE * cover_scale)

	_draw_sky(DESIGN_SIZE)
	_draw_stars(DESIGN_SIZE)
	_draw_moon(DESIGN_SIZE)
	_draw_clouds(DESIGN_SIZE)
	_draw_mountains(DESIGN_SIZE)
	_draw_castle(DESIGN_SIZE)
	_draw_ground(DESIGN_SIZE)
	_draw_fires(DESIGN_SIZE)
	_draw_foreground(DESIGN_SIZE)
	_draw_title_glow(DESIGN_SIZE)
	_draw_fire_embers(DESIGN_SIZE)
	_draw_fog_layers(DESIGN_SIZE)
	_draw_menu_readability_scrim(DESIGN_SIZE)
	_draw_vignette(DESIGN_SIZE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_sky(viewport_size: Vector2) -> void:
	var strips := 90
	for i in range(strips):
		var t := float(i) / float(strips - 1)
		var color := Color(0.012, 0.020, 0.060).lerp(Color(0.170, 0.058, 0.075), t)
		if t > 0.52:
			color = color.lerp(Color(0.255, 0.105, 0.060), (t - 0.52) * 0.34)
		draw_rect(Rect2(0.0, viewport_size.y * t, viewport_size.x, viewport_size.y / float(strips) + 2.0), color, true)

func _draw_stars(viewport_size: Vector2) -> void:
	for i in range(118):
		var x := fposmod(float(i * 97 + 23), viewport_size.x)
		var y := fposmod(float(i * 43 + 31), viewport_size.y * 0.44) + 10.0
		var twinkle := 0.55 + 0.45 * sin(time_passed * (0.8 + float(i % 6) * 0.15) + float(i))
		var alpha := 0.22 + twinkle * 0.42
		var size_px := 1.0 + float(i % 3) * 0.45
		var star_color := Color(1.0, 0.82, 0.42, alpha) if i % 4 != 0 else Color(0.55, 0.75, 1.0, alpha * 0.74)
		draw_rect(Rect2(Vector2(x, y), Vector2(size_px, size_px)), star_color, true)

func _draw_moon(viewport_size: Vector2) -> void:
	var center := Vector2(viewport_size.x * 0.76, viewport_size.y * 0.19)
	for i in range(7):
		draw_circle(center, 74.0 - float(i) * 7.0, Color(1.0, 0.42, 0.13, 0.012 + float(i) * 0.006))
	draw_circle(center, 38.0, Color(1.0, 0.78, 0.42, 0.82))
	draw_circle(center + Vector2(13.0, -5.0), 37.0, Color(0.045, 0.050, 0.105, 0.98))
	draw_circle(center + Vector2(-16.0, -8.0), 3.0, Color(0.78, 0.44, 0.22, 0.26))
	draw_circle(center + Vector2(-19.0, 9.0), 5.0, Color(0.78, 0.44, 0.22, 0.18))

func _draw_clouds(viewport_size: Vector2) -> void:
	for layer in range(3):
		var speed := 2.5 + float(layer) * 1.8
		var x_offset := fposmod(time_passed * speed, 220.0)
		var y := 58.0 + float(layer) * 36.0
		var cloud_color := Color(0.12, 0.10, 0.18, 0.13 - float(layer) * 0.025)
		for j in range(5):
			var x := float(j) * 220.0 - x_offset - 100.0 + float(layer) * 52.0
			draw_circle(Vector2(x, y), 34.0 + float(layer) * 6.0, cloud_color)
			draw_circle(Vector2(x + 38.0, y + 7.0), 26.0 + float(layer) * 5.0, cloud_color)
			draw_rect(Rect2(x - 10.0, y, 82.0, 24.0), cloud_color, true)

func _draw_mountains(viewport_size: Vector2) -> void:
	var far_y := viewport_size.y * 0.58
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, far_y),
		Vector2(viewport_size.x * 0.10, far_y - 90.0),
		Vector2(viewport_size.x * 0.20, far_y - 34.0),
		Vector2(viewport_size.x * 0.32, far_y - 132.0),
		Vector2(viewport_size.x * 0.44, far_y - 38.0),
		Vector2(viewport_size.x * 0.60, far_y - 72.0),
		Vector2(viewport_size.x * 0.72, far_y - 16.0),
		Vector2(viewport_size.x * 0.82, far_y - 112.0),
		Vector2(viewport_size.x, far_y - 28.0),
		Vector2(viewport_size.x, viewport_size.y),
		Vector2(0.0, viewport_size.y)
	]), Color(0.038, 0.050, 0.115, 1.0))

	var near_y := viewport_size.y * 0.70
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, near_y),
		Vector2(viewport_size.x * 0.12, near_y - 86.0),
		Vector2(viewport_size.x * 0.26, near_y - 30.0),
		Vector2(viewport_size.x * 0.39, near_y - 126.0),
		Vector2(viewport_size.x * 0.52, near_y - 34.0),
		Vector2(viewport_size.x * 0.68, near_y - 74.0),
		Vector2(viewport_size.x * 0.84, near_y - 28.0),
		Vector2(viewport_size.x, near_y - 92.0),
		Vector2(viewport_size.x, viewport_size.y),
		Vector2(0.0, viewport_size.y)
	]), Color(0.016, 0.020, 0.044, 1.0))

func _draw_castle(viewport_size: Vector2) -> void:
	var base := Vector2(viewport_size.x * 0.50, viewport_size.y * 0.64)
	var body := Color(0.042, 0.034, 0.058, 0.99)
	var tower := Color(0.025, 0.024, 0.044, 1.0)
	draw_circle(base + Vector2(0.0, -90.0), 128.0, Color(1.0, 0.30, 0.08, 0.035))
	draw_rect(Rect2(base + Vector2(-84.0, -136.0), Vector2(168.0, 150.0)), body, true)
	draw_rect(Rect2(base + Vector2(-142.0, -88.0), Vector2(48.0, 104.0)), tower, true)
	draw_rect(Rect2(base + Vector2(94.0, -88.0), Vector2(48.0, 104.0)), tower, true)
	for i in range(8):
		draw_rect(Rect2(base + Vector2(-84.0 + float(i) * 24.0, -149.0), Vector2(13.0, 20.0)), tower, true)
	for x in [-142.0, 94.0]:
		for i in range(2):
			draw_rect(Rect2(base + Vector2(x + float(i) * 28.0, -100.0), Vector2(18.0, 18.0)), tower, true)
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(-100.0, -136.0),
		base + Vector2(0.0, -218.0),
		base + Vector2(100.0, -136.0)
	]), Color(0.030, 0.026, 0.045, 1.0))
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(-152.0, -88.0),
		base + Vector2(-118.0, -140.0),
		base + Vector2(-84.0, -88.0)
	]), Color(0.030, 0.026, 0.045, 1.0))
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(84.0, -88.0),
		base + Vector2(118.0, -140.0),
		base + Vector2(152.0, -88.0)
	]), Color(0.030, 0.026, 0.045, 1.0))

	for i in range(7):
		var x := base.x - 76.0 + float(i) * 25.0
		var pulse := 0.76 + sin(time_passed * 1.7 + float(i)) * 0.12
		draw_rect(Rect2(x, base.y - 112.0, 9.0, 24.0), Color(1.0, 0.38, 0.10, 0.26 * pulse), true)
		draw_rect(Rect2(x + 2.0, base.y - 109.0, 5.0, 17.0), Color(1.0, 0.86, 0.42, 0.40 * pulse), true)

	draw_rect(Rect2(base + Vector2(-36.0, -54.0), Vector2(72.0, 72.0)), Color(0.018, 0.016, 0.026, 1.0), true)
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(-36.0, 18.0),
		base + Vector2(0.0, -38.0),
		base + Vector2(36.0, 18.0)
	]), Color(0.010, 0.009, 0.016, 1.0))
	draw_line(base + Vector2(-172.0, 18.0), base + Vector2(172.0, 18.0), Color(0.85, 0.50, 0.18, 0.42), 3.0)
	draw_line(base + Vector2(-150.0, 12.0), base + Vector2(150.0, 12.0), Color(1.0, 0.72, 0.28, 0.18), 1.0)
	draw_line(base + Vector2(0.0, -218.0), base + Vector2(0.0, -246.0), Color(0.12, 0.08, 0.12, 1.0), 2.0)
	draw_colored_polygon(PackedVector2Array([
		base + Vector2(1.0, -245.0),
		base + Vector2(30.0, -237.0),
		base + Vector2(1.0, -226.0)
	]), Color(0.72, 0.12, 0.10, 0.86))

func _draw_ground(viewport_size: Vector2) -> void:
	var ground_y := viewport_size.y * 0.70
	draw_rect(Rect2(0.0, ground_y, viewport_size.x, viewport_size.y - ground_y), Color(0.048, 0.038, 0.052, 1.0), true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(viewport_size.x * 0.44, ground_y),
		Vector2(viewport_size.x * 0.55, ground_y),
		Vector2(viewport_size.x * 0.70, viewport_size.y),
		Vector2(viewport_size.x * 0.30, viewport_size.y)
	]), Color(0.150, 0.095, 0.070, 0.84))
	draw_colored_polygon(PackedVector2Array([
		Vector2(viewport_size.x * 0.46, ground_y + 12.0),
		Vector2(viewport_size.x * 0.54, ground_y + 12.0),
		Vector2(viewport_size.x * 0.64, viewport_size.y),
		Vector2(viewport_size.x * 0.36, viewport_size.y)
	]), Color(0.235, 0.145, 0.090, 0.72))
	for i in range(28):
		var y := ground_y + float(i) * 8.0
		draw_line(Vector2(0.0, y), Vector2(viewport_size.x, y + sin(float(i)) * 8.0), Color(1.0, 0.42, 0.12, 0.035), 1.0)

func _draw_foreground(viewport_size: Vector2) -> void:
	var dark := Color(0.009, 0.011, 0.021, 0.98)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0.0, 238.0), Vector2(42.0, 252.0), Vector2(70.0, 292.0),
		Vector2(126.0, 320.0), Vector2(166.0, viewport_size.y),
		Vector2(0.0, viewport_size.y)
	]), dark)
	draw_colored_polygon(PackedVector2Array([
		Vector2(viewport_size.x, 230.0), Vector2(594.0, 252.0), Vector2(568.0, 300.0),
		Vector2(510.0, 326.0), Vector2(484.0, viewport_size.y),
		Vector2(viewport_size.x, viewport_size.y)
	]), dark)
	for side in [-1.0, 1.0]:
		var root_x := 42.0 if side < 0.0 else viewport_size.x - 42.0
		draw_line(Vector2(root_x, viewport_size.y), Vector2(root_x + side * 12.0, 244.0), dark, 12.0)
		draw_line(Vector2(root_x + side * 8.0, 280.0), Vector2(root_x + side * 46.0, 250.0), dark, 7.0)
		draw_line(Vector2(root_x + side * 5.0, 266.0), Vector2(root_x - side * 28.0, 236.0), dark, 6.0)

func _draw_fires(viewport_size: Vector2) -> void:
	var points := [
		Vector2(viewport_size.x * 0.18, viewport_size.y * 0.79),
		Vector2(viewport_size.x * 0.81, viewport_size.y * 0.78),
		Vector2(viewport_size.x * 0.09, viewport_size.y * 0.86),
		Vector2(viewport_size.x * 0.89, viewport_size.y * 0.88)
	]
	for p in points:
		var pulse := 0.5 + 0.5 * sin(time_passed * 4.0 + p.x)
		draw_circle(p + Vector2(0.0, 4.0), 44.0, Color(1.0, 0.36, 0.08, 0.08 + pulse * 0.03))
		draw_rect(Rect2(p + Vector2(-44.0, 22.0), Vector2(88.0, 8.0)), Color(0.012, 0.009, 0.010, 0.76), true)
		draw_colored_polygon(PackedVector2Array([
			p + Vector2(-14.0, 16.0),
			p + Vector2(0.0, -34.0 - pulse * 5.0),
			p + Vector2(14.0, 16.0)
		]), Color(0.92, 0.22, 0.08, 0.82))
		draw_colored_polygon(PackedVector2Array([
			p + Vector2(-7.0, 12.0),
			p + Vector2(2.0, -24.0 - pulse * 4.0),
			p + Vector2(8.0, 12.0)
		]), Color(1.0, 0.78, 0.30, 0.72))

func _draw_title_glow(viewport_size: Vector2) -> void:
	var center := Vector2(viewport_size.x * 0.50, viewport_size.y * 0.18)
	for i in range(8):
		var radius := 92.0 + float(i) * 24.0
		var alpha := 0.030 - float(i) * 0.0024
		draw_circle(center, radius, Color(1.0, 0.58, 0.18, maxf(alpha, 0.005)))

func _draw_fire_embers(viewport_size: Vector2) -> void:
	for i in range(48):
		var speed := 9.0 + float(i % 7) * 3.0
		var x := fposmod(float(i * 83 + 41) + time_passed * speed, viewport_size.x)
		var base_y := viewport_size.y * (0.54 + float(i % 11) * 0.034)
		var drift := sin(time_passed * (0.9 + float(i % 5) * 0.13) + float(i)) * 7.0
		var y := base_y + drift
		var pulse := 0.45 + 0.55 * sin(time_passed * 2.0 + float(i) * 0.71)
		draw_circle(Vector2(x, y), 1.0 + float(i % 3) * 0.55, Color(1.0, 0.48, 0.12, 0.08 + pulse * 0.12))

func _draw_fog_layers(viewport_size: Vector2) -> void:
	for i in range(5):
		var y := viewport_size.y * (0.55 + float(i) * 0.045)
		var x_offset := fposmod(time_passed * (7.0 + float(i) * 2.0), 180.0)
		var color := Color(0.70, 0.42, 0.24, 0.035 - float(i) * 0.003)
		for j in range(8):
			var x := float(j) * 180.0 - x_offset - 80.0
			draw_circle(Vector2(x + 110.0, y + 14.0), 30.0 + float(i) * 7.0, color)

func _draw_menu_readability_scrim(viewport_size: Vector2) -> void:
	var y := viewport_size.y * 0.50
	for i in range(14):
		var alpha := 0.025 - float(i) * 0.0013
		draw_rect(Rect2(0.0, y + float(i) * 12.0, viewport_size.x, 13.0), Color(0.0, 0.0, 0.0, maxf(alpha, 0.004)), true)

func _draw_vignette(viewport_size: Vector2) -> void:
	for i in range(32):
		var alpha := 0.105 - float(i) * 0.003
		var c := Color(0.0, 0.0, 0.0, maxf(alpha, 0.0))
		draw_rect(Rect2(float(i) * 4.0, 0.0, 4.0, viewport_size.y), c, true)
		draw_rect(Rect2(viewport_size.x - float(i + 1) * 4.0, 0.0, 4.0, viewport_size.y), c, true)
	for i in range(24):
		var alpha := 0.12 - float(i) * 0.004
		draw_rect(Rect2(0.0, float(i) * 3.0, viewport_size.x, 3.0), Color(0.0, 0.0, 0.0, maxf(alpha, 0.0)), true)
		draw_rect(Rect2(0.0, viewport_size.y - float(i + 1) * 4.0, viewport_size.x, 4.0), Color(0.0, 0.0, 0.0, maxf(alpha + 0.02, 0.0)), true)
