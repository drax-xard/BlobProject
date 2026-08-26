extends Control

@onready var split: HSplitContainer = $HSplitContainer
@onready var left_panel: VBoxContainer = $HSplitContainer/LeftPanel
@onready var viewport_frame: SubViewportContainer = $HSplitContainer/LeftPanel/ViewportFrame
@onready var bottom_bar: HBoxContainer = $HSplitContainer/LeftPanel/BottomBar
@onready var right_panel: PanelContainer = $HSplitContainer/RightPanel

func _ready() -> void:
	call_deferred("_apply_layout")
	get_viewport().size_changed.connect(_apply_layout)
	if SettingsManager:
		SettingsManager.settings_changed.connect(_on_settings_changed)

func _on_settings_changed(section: String) -> void:
	if section == "layout":
		_apply_layout()

func _apply_layout() -> void:
	if not SettingsManager:
		return

	var vp_ratio: float = SettingsManager.get_layout("viewport_ratio")
	var bar_ratio: float = SettingsManager.get_layout("action_bar_ratio")
	var party_ratio: float = SettingsManager.get_layout("party_panel_ratio")
	var vp_min_h: int = SettingsManager.get_layout("viewport_min_height")
	var bar_min_h: int = SettingsManager.get_layout("action_bar_min_height")
	var party_min_w: int = SettingsManager.get_layout("party_panel_min_width")

	viewport_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_frame.size_flags_stretch_ratio = vp_ratio
	bottom_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_bar.size_flags_stretch_ratio = bar_ratio

	viewport_frame.custom_minimum_size.y = vp_min_h
	bottom_bar.custom_minimum_size.y = bar_min_h
	right_panel.custom_minimum_size.x = party_min_w

	var container_w: float = split.size.x
	if container_w <= 0.0:
		return
	var total_ratio: float = vp_ratio + party_ratio
	if total_ratio <= 0.0:
		total_ratio = 1.0
	var viewport_pct: float = vp_ratio / total_ratio
	var split_position: float = container_w * viewport_pct
	split.split_offset = int(split_position - container_w)
