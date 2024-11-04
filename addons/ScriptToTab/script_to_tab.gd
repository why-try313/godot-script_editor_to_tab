@tool
extends EditorPlugin

var plugin_enabled:bool = false
var container:Control
var script_editor # WindowWrapper type
var script_editor_win:ScriptEditor
var last_selected_dock:String = "2D"


func _ready() -> void: # Track screen changes
	connect("main_screen_changed", on_scene_change)

func _enter_tree() -> void:
	# Create and add dock holder
	container = Control.new();
	container.name = "Script Editor"
	plugin_enabled = true
	add_control_to_dock(DockSlot.DOCK_SLOT_LEFT_UL, container)

	# Grab the script editor
	script_editor = get_editor_interface().get_script_editor().get_parent()
	script_editor_win = get_editor_interface().get_script_editor()
	script_editor.remove_child(script_editor_win)

	container.add_child(script_editor_win) # Move the script editor to holder

	# Resize according parent
	container.connect("minimum_size_changed", resize_container)
	container.connect("resized", resize_container)
	resize_container()

	toggle_script_icon_visibility() # Tame icon color to show as disabled
	open_last_tab(false) # Click on 2D/3D/AssetLib tab
	focus_on_tab()

func focus_on_tab():
	container.get_parent().current_tab = container.get_parent().get_tab_idx_from_control(container)

func get_dock_button(btn_name:String): # Helper adding BettertoolbarTabs addon integration
	var btn = null

	# Find button in classic editor container
	var TopControl = get_editor_interface().get_base_control().get_child(0).get_child(0)
	var WorkspaceTabs = TopControl.get_child(2)
	for child in WorkspaceTabs.get_children():
		if child.name == btn_name: btn = child
	if btn: return btn # Break if found

	# BetterToolbar addon implementation
	var BettertoolbarTabs = TopControl.get_child(4)
	for child in BettertoolbarTabs.get_children():
		if child.name == btn_name: btn = child
	return btn

func toggle_script_icon_visibility() -> void:
	if plugin_enabled: # Fakes a click on the last scene to emulate as disabled
		get_dock_button("Script").connect("toggled", open_last_tab)
	else:
		get_dock_button("Script").disconnect("toggled", open_last_tab)

	var script_col:float = 1.0;
	if plugin_enabled: script_col = 0.25
	get_dock_button("Script").modulate = Color(1.0,1.0,1.0,script_col)

func open_last_tab(_toggled:bool):
	focus_on_tab()
	call_deferred("def_open_last_tab")
func def_open_last_tab():
	get_dock_button(last_selected_dock).pressed.emit()

func on_scene_change(dock_name:String):
	if dock_name != "Script": last_selected_dock = dock_name

func resize_container():
	container.size = container.get_parent().size - Vector2(0, 28)
	container.position = Vector2(0,28)
	script_editor_win.size = container.size

func _exit_tree() -> void:
	plugin_enabled = false
	toggle_script_icon_visibility()
	container.disconnect("resized", resize_container)
	container.disconnect("minimum_size_changed", resize_container)
	container.remove_child(script_editor_win)
	script_editor.add_child(script_editor_win)
	script_editor.move_child(script_editor_win, 0)
	script_editor_win.size = script_editor.size
	remove_control_from_docks(container)
