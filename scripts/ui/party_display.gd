extends VBoxContainer

const MAX_PARTY: int = 4

var member_containers: Array[PanelContainer] = []

func _ready() -> void:
	_build_ui()
	GameManager.party_changed.connect(_on_party_changed)
	_refresh_all()

func _build_ui() -> void:
	for i in range(MAX_PARTY):
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(0, 60)
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		var portrait := TextureRect.new()
		portrait.custom_minimum_size = Vector2(40, 40)
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_set_portrait_texture(portrait, i)
		hbox.add_child(portrait)
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 2)
		var name_label := Label.new()
		name_label.text = "---"
		name_label.add_theme_font_size_override("font_size", 14)
		var hp_bar := ProgressBar.new()
		hp_bar.custom_minimum_size = Vector2(120, 12)
		hp_bar.max_value = 100
		hp_bar.value = 100
		hp_bar.show_percentage = false
		var hp_label := Label.new()
		hp_label.add_theme_font_size_override("font_size", 10)
		hp_label.text = "HP: 0/0"
		info.add_child(name_label)
		info.add_child(hp_bar)
		info.add_child(hp_label)
		hbox.add_child(info)
		panel.add_child(hbox)
		add_child(panel)
		member_containers.append(panel)

func _set_portrait_texture(portrait: TextureRect, index: int) -> void:
	var colors := [
		Color(0.8, 0.2, 0.2),
		Color(0.2, 0.4, 0.9),
		Color(0.9, 0.9, 0.2),
		Color(0.3, 0.8, 0.3),
	]
	var fallback_color: Color = colors[index] if index < colors.size() else Color.GRAY
	if index < GameManager.party.size():
		var member: Dictionary = GameManager.party[index]
		var class_id: String = member.get("class_id", "")
		if not class_id.is_empty():
			var tex := ResLoader.load_texture("base", "portrait_%s.png" % class_id)
			if tex:
				portrait.texture = tex
				return
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(fallback_color)
	portrait.texture = ImageTexture.create_from_image(img)

func _on_party_changed() -> void:
	_refresh_all()

func _refresh_all() -> void:
	for i in range(MAX_PARTY):
		_refresh_member(i)

func _refresh_member(index: int) -> void:
	if index >= member_containers.size():
		return
	var panel := member_containers[index]
	if index >= GameManager.party.size():
		panel.visible = false
		return
	panel.visible = true
	var member: Dictionary = GameManager.party[index]
	var hbox := panel.get_child(0) as HBoxContainer
	var portrait := hbox.get_child(0) as TextureRect
	var info := hbox.get_child(1) as VBoxContainer
	var name_label := info.get_child(0) as Label
	var hp_bar := info.get_child(1) as ProgressBar
	var hp_label := info.get_child(2) as Label
	_set_portrait_texture(portrait, index)
	name_label.text = member["name"]
	hp_bar.max_value = member["max_hp"]
	hp_bar.value = member["hp"]
	hp_label.text = "HP: %d/%d" % [member["hp"], member["max_hp"]]
