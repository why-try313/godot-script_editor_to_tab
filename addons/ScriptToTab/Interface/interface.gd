@tool
extends Control
signal settings_changed

var is_set = false
var FileSysteParent  = null
var ScriptEditParent = null

@export var settings:Dictionary = {}:
	set(v): settings = v; _set_settings()
@export var FileSystem:FileSystemDock = null:
	set(v): FileSystem = v; install_file_manager()
@export var ScriptEdit:ScriptEditor = null:
	set(v): ScriptEdit = v; install_script_editor()

@onready var el_fileDock:Control      = $VBoxContainer/HBoxContainer/FileDock
@onready var el_scriptDock:Control    = $VBoxContainer/HBoxContainer/ScriptDock
@onready var el_resize:ColorRect      = $VBoxContainer/HBoxContainer/resize
@onready var el_resize_handle:ColorRect = $VBoxContainer/HBoxContainer/resize/handle
# @export var options_buttons:Dictionary[String, CheckBox] = { # Godot 4.4
@onready var opt_filesSystem:CheckBox = $VBoxContainer/OptionsFooter/FileExplorer
@onready var opt_reveal_file:CheckBox = $VBoxContainer/OptionsFooter/RevealInFileExplorer
@onready var opt_ignore_addn:CheckBox = $VBoxContainer/OptionsFooter/IngoreAddons
@onready var opt_switch_pannels:CheckBox  = $VBoxContainer/OptionsFooter/SwitchPannels
@onready var opt_hide_side_panel:CheckBox = $VBoxContainer/OptionsFooter/SidePanel
var options_buttons:Dictionary = {}
var settings_data:Dictionary = { "options": {}, "file_manager_size": 0 }

var dock_size:float = 0.0
var is_active_mouse:bool = false:
	set(v): is_active_mouse = v; color_resize_bar(true)

func _install() -> void:
	options_buttons = {
		"opt_filesSystem": opt_filesSystem,
		"opt_reveal_file": opt_reveal_file,
		"opt_ignore_addn": opt_ignore_addn,
		"opt_switch_pannels": opt_switch_pannels,
		"opt_hide_side_panel": opt_hide_side_panel,
	}
	if ScriptEdit and ScriptEdit.get_parent() == el_scriptDock: return
	_set_settings()
	#if is_inside_tree(): await get_tree().create_timer(0.2).timeout; resize_panels()
	#if is_inside_tree(): await get_tree().create_timer(0.2).timeout; resize_panels()
	if is_inside_tree(): await get_tree().create_timer(1.0).timeout; resize_panels()
	if !is_set and settings.has("plugins/script_to_tab/hide_editor_side_panel"):
		toggle_script_panel(settings["plugins/script_to_tab/hide_editor_side_panel"].value)
		is_set = true


func _set_settings():
	if !is_inside_tree(): return
	for key in settings.keys():
		var btn_name = settings[ key ].button_var
		if options_buttons.has(btn_name):
			assert(options_buttons[ btn_name ] is CheckBox, "Checkbox expected")
			options_buttons[ btn_name ].button_pressed = settings[ key ].value


func _ready() -> void:
	_install()
	_set_settings()
	el_resize.connect("gui_input", resize_dock)
	el_resize.connect("mouse_entered", color_resize_bar.bind(true))
	el_resize.connect("mouse_exited", color_resize_bar.bind(false))
	el_resize_handle.color = EditorInterface.get_editor_settings().get_setting("interface/theme/accent_color")
	opt_filesSystem.connect("toggled", toggle_file_explorer)
	opt_switch_pannels.connect("toggled", toggled_switch_pannels)
	opt_hide_side_panel.connect("toggled", toggle_script_panel)
	opt_reveal_file.connect("toggled", toggle_reveal_in_fileSystem)
	if get_parent().has_signal("resized"): get_parent().connect("resized", resize_panels)
	position.x = 0.0; position.y = 0.0;
	color_resize_bar(false)
	toggled_switch_pannels(false)

func toggled_switch_pannels(_pass:bool):
	if opt_switch_pannels.button_pressed:
		el_scriptDock.get_parent().move_child(el_scriptDock, 0)
	else:
		el_fileDock.get_parent().move_child(el_fileDock, 0)


func color_resize_bar(active:bool):
	if is_active_mouse: el_resize_handle.modulate = Color(1.0,1.0,1.0,1.0)
	elif !active: el_resize_handle.modulate = Color(1.0,1.0,1.0,0.0)
	else:
		el_resize_handle.modulate = Color(1.0,1.0,1.0,0.5);
		el_resize_handle.color = EditorInterface.get_editor_settings().get_setting("interface/theme/accent_color");


func set_panel_props(element:Control) -> void:
	element.visible = true
	#element.anchor_top = 0.0;   element.anchor_left = 0.0;
	#element.anchor_bottom = 0.0 element.anchor_right = 0.0
	element.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 0)
	element.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	element.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	element.size_flags_stretch_ratio = 1.0
	element.position.x = 0.0; element.position.y = 0.0


func install_file_manager():
	if FileSystem:
		FileSysteParent = FileSystem.get_parent()
		toggle_file_manager()
	set_layout()


func install_script_editor():
	if ScriptEdit:
		ScriptEditParent = ScriptEdit.get_parent()
		ScriptEditParent.remove_child(ScriptEdit)
		el_scriptDock.add_child(ScriptEdit)
		ScriptEdit.connect("editor_script_changed", on_script_changed)
		set_panel_props(ScriptEdit)


func on_script_changed(script:Script):
	if !script: return
	var path = script.resource_path
	if opt_reveal_file.button_pressed:
		if opt_ignore_addn.button_pressed and path.begins_with("res://addons/"): return
		EditorInterface.select_file(path)


func resize_panels():
	if !is_inside_tree(): return
	size = get_parent().size
	if ScriptEdit: ScriptEdit.size = ScriptEdit.get_parent().size
	if FileSystem: FileSystem.size = FileSystem.get_parent().size


func set_layout():
	if len(el_fileDock.get_children()) == 0:
		el_resize.visible = false
		el_fileDock.visible = false
	else:
		el_resize.visible     = true
		el_scriptDock.visible = true
		el_fileDock.visible   = true
	call_deferred("resize_panels")


static func find_or_null(arr: Array[Node], index: int = 0) -> Node:
	if arr.is_empty():
		push_error("Node not found - Plugin will not work correctly. This might be due to some other plugins or changes in the Engine.")
		return null
	return arr[index]


func toggle_file_manager():
	if !FileSystem: return
	if opt_filesSystem.button_pressed and FileSystem.get_parent() == FileSysteParent:
		FileSysteParent = FileSystem.get_parent()
		FileSysteParent.remove_child(FileSystem)
		el_fileDock.add_child(FileSystem)
		set_panel_props(FileSystem)
	elif !opt_filesSystem.button_pressed and FileSystem.get_parent() == el_fileDock:
		el_fileDock.remove_child(FileSystem);
		FileSysteParent.add_child(FileSystem)
		FileSysteParent.visible = true
	set_layout()
	settings_changed.emit()


func toggle_reveal_in_fileSystem(val:bool): settings_changed.emit()
func toggle_file_explorer(val:bool):
	opt_filesSystem.button_pressed = val
	toggle_file_manager()
	settings_changed.emit()


func toggle_script_panel(val:bool):
	opt_hide_side_panel.button_pressed = val
	var script_list = find_or_null(ScriptEdit.find_children("*", "VSplitContainer", true, false))
	if script_list: script_list.visible = !opt_hide_side_panel.button_pressed
	settings_changed.emit()


func resize_dock(event:InputEvent) -> void:
	if event is InputEventMouseButton:
		is_active_mouse = event.pressed


func _input(event: InputEvent) -> void:
	if !is_active_mouse: return
	if event is InputEventMouseMotion:
		el_fileDock.custom_minimum_size.x = el_fileDock.custom_minimum_size.x + event.relative.x
		call_deferred("resize_panels")


func _uninstall()  -> void:
	el_resize.disconnect("gui_input", resize_dock)
	el_resize.disconnect("mouse_entered", color_resize_bar)
	el_resize.disconnect("mouse_exited", color_resize_bar)
	ScriptEdit.disconnect("editor_script_changed", on_script_changed)
	opt_filesSystem.disconnect("toggled", toggle_file_explorer)
	opt_hide_side_panel.disconnect("toggled", toggle_script_panel)
	opt_reveal_file.disconnect("toggled", toggle_reveal_in_fileSystem)
	# el_fileDock.remove_child(FileSystem);    FileSysteParent.add_child(FileSystem)
	el_scriptDock.remove_child(ScriptEdit);  ScriptEditParent.add_child(ScriptEdit)
	if get_parent().has_signal("resized"): get_parent().disconnect("resized", resize_panels)
