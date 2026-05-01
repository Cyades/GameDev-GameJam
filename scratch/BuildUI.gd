extends SceneTree

func _init() -> void:
	print("Building UI Scenes...")
	
	var dir = DirAccess.open("res://Scenes")
	if not dir.dir_exists("UI"):
		dir.make_dir("UI")
	
	var font = load("res://Assets GameJam/Ninja Adventure - Asset Pack/Ui/Font/NormalFont.ttf")
	var btn_normal = load("res://Assets GameJam/Ninja Adventure - Asset Pack/Ui/Theme/Theme Wood/button_normal.png")
	var btn_hover = load("res://Assets GameJam/Ninja Adventure - Asset Pack/Ui/Theme/Theme Wood/button_hover.png")
	var btn_pressed = load("res://Assets GameJam/Ninja Adventure - Asset Pack/Ui/Theme/Theme Wood/button_pressed.png")
	var panel_bg = load("res://Assets GameJam/Ninja Adventure - Asset Pack/Ui/Theme/Theme Wood/nine_path_panel.png")
	var slider_grabber = load("res://Assets GameJam/Ninja Adventure - Asset Pack/Ui/Theme/Theme Wood/h_slidder_grabber.png")
	var slider_progress = load("res://Assets GameJam/Ninja Adventure - Asset Pack/Ui/Theme/Theme Wood/slider_progress.png")
	
	# =====================
	# SETTINGS MENU
	# =====================
	var settings = Control.new()
	settings.name = "SettingsMenu"
	settings.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings.set_script(load("res://Scripts/SettingsMenu.gd"))
	
	var s_panel = NinePatchRect.new()
	s_panel.name = "Panel"
	s_panel.texture = panel_bg
	s_panel.patch_margin_left = 16
	s_panel.patch_margin_top = 16
	s_panel.patch_margin_right = 16
	s_panel.patch_margin_bottom = 16
	s_panel.set_anchors_preset(Control.PRESET_CENTER)
	s_panel.custom_minimum_size = Vector2(400, 300)
	s_panel.position = Vector2(640/2 - 200, 360/2 - 150)
	settings.add_child(s_panel)
	s_panel.owner = settings
	
	var s_title = Label.new()
	s_title.name = "Title"
	s_title.text = "SETTINGS"
	s_title.add_theme_font_override("font", font)
	s_title.add_theme_font_size_override("font_size", 24)
	s_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	s_title.offset_top = 20
	s_title.offset_bottom = 50
	s_panel.add_child(s_title)
	s_title.owner = settings
	
	var s_vbox = VBoxContainer.new()
	s_vbox.name = "VBoxContainer"
	s_vbox.set_anchors_preset(Control.PRESET_CENTER)
	s_vbox.custom_minimum_size = Vector2(300, 150)
	s_vbox.position = Vector2(50, 70)
	s_panel.add_child(s_vbox)
	s_vbox.owner = settings
	
	var buses = ["Master", "BGM", "SFX"]
	for bus in buses:
		var hbox = HBoxContainer.new()
		hbox.name = bus + "HBox"
		s_vbox.add_child(hbox)
		hbox.owner = settings
		
		var lbl = Label.new()
		lbl.name = "Label"
		lbl.text = bus
		lbl.add_theme_font_override("font", font)
		lbl.custom_minimum_size = Vector2(100, 0)
		hbox.add_child(lbl)
		lbl.owner = settings
		
		var slider = HSlider.new()
		slider.name = bus + "Slider"
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = 1.0
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Slider styling using Theme
		slider.add_theme_icon_override("grabber", slider_grabber)
		slider.add_theme_icon_override("grabber_highlight", slider_grabber)
		hbox.add_child(slider)
		slider.owner = settings
		
	var s_close = TextureButton.new()
	s_close.name = "CloseButton"
	s_close.texture_normal = btn_normal
	s_close.texture_hover = btn_hover
	s_close.texture_pressed = btn_pressed
	s_close.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	s_close.custom_minimum_size = Vector2(100, 30)
	s_close.offset_left = 150
	s_close.offset_top = -60
	s_close.offset_right = -150
	s_close.offset_bottom = -30
	s_close.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	s_panel.add_child(s_close)
	s_close.owner = settings
	
	var s_close_lbl = Label.new()
	s_close_lbl.name = "Label"
	s_close_lbl.text = "BACK"
	s_close_lbl.add_theme_font_override("font", font)
	s_close_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	s_close_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s_close_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	s_close.add_child(s_close_lbl)
	s_close_lbl.owner = settings
	
	var settings_packed = PackedScene.new()
	settings_packed.pack(settings)
	ResourceSaver.save(settings_packed, "res://Scenes/UI/SettingsMenu.tscn")
	
	# =====================
	# MAIN MENU
	# =====================
	var main_menu = CanvasLayer.new()
	main_menu.name = "MainMenu"
	main_menu.set_script(load("res://Scripts/MainMenu.gd"))
	
	var mm_ctrl = Control.new()
	mm_ctrl.name = "Control"
	mm_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_menu.add_child(mm_ctrl)
	mm_ctrl.owner = main_menu
	
	var mm_bg = ColorRect.new()
	mm_bg.name = "Background"
	mm_bg.color = Color(0.1, 0.1, 0.1, 1.0)
	mm_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	mm_ctrl.add_child(mm_bg)
	mm_bg.owner = main_menu
	
	var mm_title = Label.new()
	mm_title.name = "Title"
	mm_title.text = "GAME JAM SURVIVAL"
	mm_title.add_theme_font_override("font", font)
	mm_title.add_theme_font_size_override("font_size", 48)
	mm_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mm_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	mm_title.offset_top = 80
	mm_ctrl.add_child(mm_title)
	mm_title.owner = main_menu
	
	var mm_vbox = VBoxContainer.new()
	mm_vbox.name = "VBoxContainer"
	mm_vbox.set_anchors_preset(Control.PRESET_CENTER)
	mm_vbox.custom_minimum_size = Vector2(200, 200)
	mm_vbox.position = Vector2(640/2 - 100, 360/2 - 50)
	mm_vbox.theme_override_constants_separation = 15
	mm_ctrl.add_child(mm_vbox)
	mm_vbox.owner = main_menu
	
	var mm_btns = ["Play", "Settings", "Quit"]
	for btn_name in mm_btns:
		var btn = TextureButton.new()
		btn.name = btn_name + "Button"
		btn.texture_normal = btn_normal
		btn.texture_hover = btn_hover
		btn.texture_pressed = btn_pressed
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.custom_minimum_size = Vector2(200, 40)
		mm_vbox.add_child(btn)
		btn.owner = main_menu
		
		var lbl = Label.new()
		lbl.name = "Label"
		lbl.text = btn_name.to_upper()
		lbl.add_theme_font_override("font", font)
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		btn.add_child(lbl)
		lbl.owner = main_menu
		
	# Instance settings menu
	var settings_inst = settings_packed.instantiate()
	main_menu.add_child(settings_inst)
	settings_inst.owner = main_menu
	
	var mm_packed = PackedScene.new()
	mm_packed.pack(main_menu)
	ResourceSaver.save(mm_packed, "res://Scenes/UI/MainMenu.tscn")
	
	# =====================
	# PAUSE MENU
	# =====================
	var pause_menu = CanvasLayer.new()
	pause_menu.name = "PauseMenu"
	pause_menu.layer = 100
	pause_menu.set_script(load("res://Scripts/PauseMenu.gd"))
	
	var pm_ctrl = Control.new()
	pm_ctrl.name = "Control"
	pm_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_menu.add_child(pm_ctrl)
	pm_ctrl.owner = pause_menu
	
	var pm_bg = ColorRect.new()
	pm_bg.name = "Overlay"
	pm_bg.color = Color(0, 0, 0, 0.6)
	pm_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	pm_ctrl.add_child(pm_bg)
	pm_bg.owner = pause_menu
	
	var pm_title = Label.new()
	pm_title.name = "Title"
	pm_title.text = "PAUSED"
	pm_title.add_theme_font_override("font", font)
	pm_title.add_theme_font_size_override("font_size", 32)
	pm_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pm_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	pm_title.offset_top = 100
	pm_ctrl.add_child(pm_title)
	pm_title.owner = pause_menu
	
	var pm_vbox = VBoxContainer.new()
	pm_vbox.name = "VBoxContainer"
	pm_vbox.set_anchors_preset(Control.PRESET_CENTER)
	pm_vbox.custom_minimum_size = Vector2(200, 200)
	pm_vbox.position = Vector2(640/2 - 100, 360/2 - 20)
	pm_vbox.theme_override_constants_separation = 15
	pm_ctrl.add_child(pm_vbox)
	pm_vbox.owner = pause_menu
	
	var pm_btns = ["Resume", "Settings", "Main Menu"]
	for btn_name in pm_btns:
		var btn = TextureButton.new()
		var n_name = btn_name.replace(" ", "")
		btn.name = n_name + "Button"
		btn.texture_normal = btn_normal
		btn.texture_hover = btn_hover
		btn.texture_pressed = btn_pressed
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.custom_minimum_size = Vector2(200, 40)
		pm_vbox.add_child(btn)
		btn.owner = pause_menu
		
		var lbl = Label.new()
		lbl.name = "Label"
		lbl.text = btn_name.to_upper()
		lbl.add_theme_font_override("font", font)
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		btn.add_child(lbl)
		lbl.owner = pause_menu
		
	# Instance settings menu for pause
	var p_settings_inst = settings_packed.instantiate()
	pause_menu.add_child(p_settings_inst)
	p_settings_inst.owner = pause_menu
	
	var pm_packed = PackedScene.new()
	pm_packed.pack(pause_menu)
	ResourceSaver.save(pm_packed, "res://Scenes/UI/PauseMenu.tscn")
	
	print("UI Scenes built successfully!")
	quit()
