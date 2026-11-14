extends "res://tools/test/vd_runner.gd"

func _ready() -> void:
	VDWorldTheme.select(VDWorldTheme.Kind.BIO, false)
	super._ready()

