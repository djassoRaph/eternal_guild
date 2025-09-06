extends CanvasLayer


func _input(event):
	if event.is_action_pressed("ui_cancel"):
		toggle_unpause_menu()

func toggle_unpause_menu():
	var pause_menu = get_node("PauseMenu")  # Go up to root
	if(pause_menu.visible){
		pause_menu.hidden
	}
	get_tree().paused = !pause_menu.visible
	
