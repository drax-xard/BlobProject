extends Control

@onready var viewport_texture: TextureRect = $ViewportTexture
@onready var sub_viewport: SubViewport = $SubViewport

func _ready() -> void:
	viewport_texture.texture = sub_viewport.get_texture()
