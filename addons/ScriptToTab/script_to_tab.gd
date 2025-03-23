@tool
extends EditorPlugin

var interface = load("res://addons/ScriptToTab/Interface/Interface.tscn").instantiate()
var container:Control
var tab_title = "Script Editor"
var last_selected_dock:String = "2D"
var settings_data:Dictionary = {
	"plugins/ScriptToTab/file_explorer":           "opt_filesSystem",
	"plugins/ScriptToTab/reveal_ingnore_addons":   "opt_ignore_addn",
	"plugins/ScriptToTab/reveal_in_file_explorer": "opt_reveal_file",
	"plugins/ScriptToTab/hide_editor_side_panel":  "opt_hide_side_panel"
}
var toolbar_button:Button # The button be hidden
var toolbar_values:Dictionary = { "posix": 0 }

func _init() -> void: # Track screen changes
	# Create and add dock holder
	container = Control.new();
	container.name = tab_title
	container.visible = false # Required to toggle visibility_changed

#func _enter_tree() -> void:
func _install() -> void:
	await get_tree().create_timer(1).timeout

	var fileSystem := EditorInterface.get_resource_filesystem()
	if fileSystem.is_connected("filesystem_changed", _install):
		fileSystem.disconnect("filesystem_changed", _install)

	var settings:Dictionary = {}
	var editor_settings:EditorSettings = get_editor_interface().get_editor_settings()
	for key in settings_data.keys():
		if editor_settings.has_setting(key):
			settings[ key ] = {
				"button_var": settings_data[ key ],
				"value": editor_settings.get_setting(key)
			}
	connect("main_screen_changed", on_scene_change)
	add_control_to_dock(DockSlot.DOCK_SLOT_LEFT_UL, container)
	var editor_interface = get_editor_interface()
	interface.settings = settings
	container.add_child(interface) # Move the script editor to holder
	interface.size = container.size
	interface.ScriptEdit = editor_interface.get_script_editor()
	interface.FileSystem = editor_interface.get_file_system_dock()
	interface._install()
	interface.connect('settings_changed', save_settings)
	#container.connect("visibility_changed", interface._enter_tree)
	toolbar_button = get_dock_button("Script")
	# await get_tree().create_timer(2.0).timeout
	if toolbar_button:
		toolbar_values.posix = toolbar_button.get_index()
		toolbar_button.get_parent().move_child(toolbar_button, 0)
		toolbar_button.scale = Vector2(0.0, 0.0)
		toolbar_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		toolbar_button.modulate = Color(1.0,1.0,1.0,0.0)

func focus_on_tab() -> void:
	if container and container.get_parent():
		container.get_parent().current_tab = container.get_parent().get_tab_idx_from_control(container)
	else:
		print("no parent")

func get_toolbar():
	# Find button in classic editor container
	var TopControl = get_editor_interface().get_base_control().get_child(0).get_child(0)
	var bar = null
	for toolbar in TopControl.get_children():
		if bar: break
		for child in toolbar.get_children():
			if child.name and child.name == "Script":
				bar = toolbar; break
	return bar

func get_dock_button(btn_name:String): # Helper adding BettertoolbarTabs addon integration
	var btn = null
	for child in get_toolbar().get_children():
		if child.name == btn_name: btn = child
	return btn # Break if found

func open_last_tab(_toggled:bool) -> void: focus_on_tab(); call_deferred("def_open_last_tab")
func def_open_last_tab()          -> void: get_dock_button(last_selected_dock).pressed.emit()

func on_scene_change(dock_name:String) -> void:
	if dock_name != "Script": last_selected_dock = dock_name
	else: open_last_tab(false)

func save_settings():
	var editor_settings:EditorSettings = get_editor_interface().get_editor_settings()
	for key:String in settings_data.keys():
		editor_settings.set_setting(key, interface.options_buttons[ settings_data[key] ].button_pressed)

func _exit_tree() -> void:
	if toolbar_button:
		toolbar_button.get_parent().move_child(toolbar_button, toolbar_values.posix)
		toolbar_button.scale = Vector2(1.0, 1.0)
		toolbar_button.modulate = Color(1.0,1.0,1.0,1.0)
		toolbar_button.mouse_filter = Control.MOUSE_FILTER_STOP
	#container.disconnect("visibility_changed", interface._enter_tree)
	interface.disconnect('settings_changed', save_settings)
	interface._uninstall()
	container.remove_child(interface)
	remove_control_from_docks(container)

func _ready():
	var fileSystem := EditorInterface.get_resource_filesystem()
	if fileSystem.is_scanning():
		fileSystem.connect("filesystem_changed", _install)
	else:
		_install()