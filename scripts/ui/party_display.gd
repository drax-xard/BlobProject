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
		var portrait := ColorRect.new()
		portrait.custom_minimum_size = Vector2(40, 40)
		portrait.color = _get_portrait_color(i)
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

func _get_portrait_color(index: int) -> Color:
	var colors := [
		Color(0.8, 0.2, 0.2),
		Color(0.2, 0.4, 0.9),
		Color(0.9, 0.9, 0.2),
		Color(0.3, 0.8, 0.3),
	]
	if index < colors.size():
		return colors[index]
	return Color.GRAY

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
	var member := GameManager.party[index]
	var hbox := panel.get_child(0) as HBoxContainer
	var info := hbox.get_child(1) as VBoxContainer
	var name_label := info.get_child(0) as Label
	var hp_bar := info.get_child(1) as ProgressBar
	var hp_label := info.get_child(2) as Label
	name_label.text = member["name"]
	hp_bar.max_value = member["max_hp"]
	hp_bar.value = member["hp"]
	hp_label.text = "HP: %d/%d" % [member["hp"], member["max_hp"]]
