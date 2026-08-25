extends Control

@onready var viewport_texture: TextureRect = $ViewportFrame/ViewportTexture
@onready var sub_viewport: SubViewport = $ViewportFrame/SubViewport

func _ready() -> void:
	viewport_texture.texture = sub_viewport.get_texture()
