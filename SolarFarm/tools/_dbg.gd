extends SceneTree
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	root.get_node("GameManager").goto("puzzle")
	for i in 40:
		await process_frame
	var c = current_scene
	print("ctrl size ", c.size, " hud size ", c.hud.size, " hud pos ", c.hud.position)
	print("bottom ", c.hud.bottom_bar.get_global_rect(), " vis ", c.hud.bottom_bar.visible, " children ", c.hud.bottom_bar.get_child_count())
	print("top ", c.hud.top_panel.get_global_rect())
	quit()
