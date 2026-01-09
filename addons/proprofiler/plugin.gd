@tool
extends EditorPlugin

var CPUProfilerUI = preload("res://addons/proprofiler/cpu_profiler/ui/cpu_profiler_ui.gd")
var FileSpaceUI = preload("res://addons/proprofiler/file_space/ui/file_space_ui.gd")
var LogInspectorUI = preload("res://addons/proprofiler/log_inspector/ui/log_inspector_ui.gd")
var LogDebuggerPlugin = preload("res://addons/proprofiler/log_inspector/debugger_plugin.gd")
var EditorLogCapture = preload("res://addons/proprofiler/log_inspector/editor_logger.gd")
var SettingsUI = preload("res://addons/proprofiler/settings_ui.gd")

var _profiler_dock: Panel
var _log_debugger: EditorDebuggerPlugin
var _editor_logger: Logger
var tab_name: String = "🔎ProProfiler"


func _enter_tree():
    # Create a dock with a TabContainer and multiple sub-tabs for profiling info.
    _profiler_dock = Panel.new()
    _profiler_dock.name = "GDProfilerDock"
    
    # Main container
    var main_container = VBoxContainer.new()
    main_container.anchor_left = 0.0
    main_container.anchor_top = 0.0
    main_container.anchor_right = 1.0
    main_container.anchor_bottom = 1.0
    main_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    main_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _profiler_dock.add_child(main_container)
    
    # TabContainer for all tabs
    var tabs = TabContainer.new()
    tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
    tabs.custom_minimum_size = Vector2(400, 240)
    main_container.add_child(tabs)

    # Main profiler tabs: Logs, CPU Profiler, Disk Usage
    var log_inspector_ui = LogInspectorUI.new()
    var cpu_profiler_ui = CPUProfilerUI.new()
    var file_space_ui = FileSpaceUI.new()
    var settings_ui = SettingsUI.new()

    tabs.add_child(log_inspector_ui)
    tabs.add_child(cpu_profiler_ui)
    tabs.add_child(file_space_ui)
    tabs.add_child(settings_ui)

    # Set titles for tabs
    tabs.set_tab_title(0, "🖨️ Logs")
    tabs.set_tab_title(1, "⚡ CPU Profiler")
    tabs.set_tab_title(2, "💾 Disk Usage")
    tabs.set_tab_title(3, "⚙️ Settings")

    add_control_to_bottom_panel(_profiler_dock, tab_name)

    # Setup Log Debugger (Game Runtime)
    _log_debugger = LogDebuggerPlugin.new()
    _log_debugger.log_received.connect(log_inspector_ui.add_log)
    add_debugger_plugin(_log_debugger)
    
    # Setup Editor Logger (Editor/tool script errors)
    _editor_logger = EditorLogCapture.new()
    _editor_logger.log_received.connect(log_inspector_ui.add_log)
    OS.add_logger(_editor_logger)
    
    # Add Runtime Logger as Autoload to capture advanced backtraces in game
    add_autoload_singleton("GDProfilerLogger", "res://addons/proprofiler/log_inspector/runtime_logger.gd")

    print_rich("[b]Godot ProProfiler has Loaded![/b]")


func _exit_tree():
    # Clean-up of the plugin goes here.
    if _log_debugger:
        remove_debugger_plugin(_log_debugger)
        _log_debugger = null
        
    if _editor_logger:
        OS.remove_logger(_editor_logger)
        _editor_logger = null

    remove_autoload_singleton("GDProfilerLogger")

    remove_custom_type("GodotProfiler")
    remove_custom_type("MovableProfiler")
    if _profiler_dock:
        remove_control_from_bottom_panel(_profiler_dock)
        _profiler_dock.free()

    print_rich("[b]Godot Profiler was Stopped.[/b]")
