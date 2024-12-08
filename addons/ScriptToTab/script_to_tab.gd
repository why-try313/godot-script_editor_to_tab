@tool
extends EditorPlugin

# Options
var select_file_in_FileSystem_on_open = true
var display_script_name_on_tab_title  = true

var plugin_enabled:bool = false
var container:Control
var script_editor # WindowWrapper type
var editor_interface:EditorInterface
var script_editor_win:ScriptEditor
var last_selected_dock:String = "2D"
var EXPORT_BUTTONS:Array = [ "Script" ]
var last_script_selected = null
var editor_ready = false
var tab_title = "Script Editor"

# Utils
func _find_node_loop(_root, compare:Callable, only_first:bool, trail:Array = []):
	var found:Array = trail
	if _root is Node:
		for child in _root.get_children():
			if compare.call(child):
				found.push_back(child)
				if only_first: break
			found = _find_node_loop(child, compare, only_first, found)
	return found

func find_node(stack:Node, compare:Callable, only_first:bool):
	var found = _find_node_loop(stack, compare, only_first)
	if len(found) > 0:
		if only_first: return found[0]
		return found
	return null

# Display file on FileSystem Tab
func display_on_fileSystem_tree(filepath:GDScript):
	var file_path = filepath.resource_path
	last_script_selected = filepath

	if display_script_name_on_tab_title:
		var path = file_path.split("/")
		container.name = tab_title+"  " + path[ len(path) - 1 ]
	elif container.name != tab_title:
		container.name = tab_title

	if !select_file_in_FileSystem_on_open: return
	if editor_interface and editor_ready:
		editor_interface.select_file(file_path)

func _init() -> void: # Track screen changes
	# Create and add dock holder
	container = Control.new();
	container.name = tab_title
	plugin_enabled = true

func _ready():
	connect("main_screen_changed", on_scene_change)

func on_ready():
	editor_ready = true
	if last_script_selected: display_on_fileSystem_tree(last_script_selected)
	var diff_size_tab_and_textEditor = abs(script_editor_win.size.x - script_editor_win.get_current_editor().size.x)
	if diff_size_tab_and_textEditor > 10: # Means the scripts panel is open
		var has_button = find_node(script_editor_win.get_current_editor(), func(node):
			return node is Button and node.tooltip_text.to_lower().contains("scripts panel"), true)
		if has_button: has_button.pressed.emit() # Click on the Togggle Script Panel button

func _enter_tree() -> void:
	add_control_to_dock(DockSlot.DOCK_SLOT_LEFT_UL, container)
	get_tree().create_timer(1).connect("timeout", on_ready)

	# Grab the script editor
	editor_interface = get_editor_interface()
	#editor_interface.distraction_free_mode = true
	script_editor_win = editor_interface.get_script_editor()
	script_editor = script_editor_win.get_parent()
	script_editor.remove_child(script_editor_win)
	script_editor_win.connect("editor_script_changed", display_on_fileSystem_tree)

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

func get_toolbar():
	# Find button in classic editor container
	var TopControl = get_editor_interface().get_base_control().get_child(0).get_child(0)
	var bar = null
	for toolbar in TopControl.get_children():
		if bar: break
		for child in toolbar.get_children():
			if child.name and child.name == "Script":
				bar = toolbar
				break
	return bar

func get_dock_button(btn_name:String): # Helper adding BettertoolbarTabs addon integration
	var btn = null
	for child in get_toolbar().get_children():
		if child.name == btn_name: btn = child
	return btn # Break if found

func toggle_script_icon_visibility() -> void:
	var padding:int = 2; var next_left: int = 0
	for icon in  get_toolbar().get_children():
		var found = EXPORT_BUTTONS.find(icon.name)
		if plugin_enabled and found > -1:
			icon.modulate = Color(1.0,1.0,1.0,0.0)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			icon.position.x = next_left
			icon.modulate = Color(1.0,1.0,1.0,1.0);
			icon.mouse_filter = Control.MOUSE_FILTER_STOP
			next_left = next_left + icon.size.x + padding

	# Fakes a click on the last scene to emulate as disabled
	if plugin_enabled: get_dock_button("Script").connect("toggled", open_last_tab)
	else:              get_dock_button("Script").disconnect("toggled", open_last_tab)

func open_last_tab(_toggled:bool): focus_on_tab(); call_deferred("def_open_last_tab")
func def_open_last_tab(): get_dock_button(last_selected_dock).pressed.emit()

func on_scene_change(dock_name:String):
	if dock_name != "Script": last_selected_dock = dock_name
	else: open_last_tab(false)

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
