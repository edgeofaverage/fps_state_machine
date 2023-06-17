extends Node

func _init():
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
    if event is InputEventMouseButton:
        Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    elif Input.is_action_pressed("ui_cancel"):
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _notification(event):
    match(event):
        NOTIFICATION_APPLICATION_FOCUS_IN, \
        NOTIFICATION_APPLICATION_RESUMED:
            Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
        NOTIFICATION_APPLICATION_FOCUS_OUT, \
        NOTIFICATION_APPLICATION_PAUSED:
            Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
