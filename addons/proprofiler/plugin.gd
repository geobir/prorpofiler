@tool
extends EditorPlugin

var CPUProfilerUI = preload("res://addons/proprofiler/cpu_profiler/ui/cpu_profiler_ui.gd")
var FileSpaceUI = preload("res://addons/proprofiler/file_space/ui/file_space_ui.gd")
var LogInspectorUI = preload("res://addons/proprofiler/log_inspector/ui/log_inspector_ui.gd")
var LogDebuggerPlugin = preload("res://addons/proprofiler/log_inspector/debugger_plugin.gd")
var EditorLogCapture = preload("res://addons/proprofiler/log_inspector/editor_logger.gd")
var SettingsUI = preload("res://addons/proprofiler/settings_ui.gd")

var _profiler_dock: Panel
var _tabs: TabContainer
var _log_debugger: EditorDebuggerPlugin
var _editor_logger: Logger
var tab_name: String = "🔎ProProfiler"


func _enter_tree():
    ProProfilerLocalization.load_translations()
    
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
    _tabs = TabContainer.new()
    _tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _tabs.custom_minimum_size = Vector2(400, 240)
    main_container.add_child(_tabs)

    # Main profiler tabs: Logs, CPU Profiler, Disk Usage
    var log_inspector_ui = LogInspectorUI.new()
    log_inspector_ui.plugin = self # Pass editor plugin for EditorInterface access
    
    var cpu_profiler_ui = CPUProfilerUI.new()
    var file_space_ui = FileSpaceUI.new()
    var settings_ui = SettingsUI.new()
    settings_ui.plugin = self

    _tabs.add_child(log_inspector_ui)
    _tabs.add_child(cpu_profiler_ui)
    _tabs.add_child(file_space_ui)
    _tabs.add_child(settings_ui)

    # Set titles for tabs
    _tabs.set_tab_title(0, ProProfilerLocalization.localize("tabs.logs", "🖨️ Logs"))
    _tabs.set_tab_title(1, ProProfilerLocalization.localize("tabs.cpu", "⚡ CPU Profiler"))
    _tabs.set_tab_title(2, ProProfilerLocalization.localize("tabs.disk", "💾 Disk Usage"))
    _tabs.set_tab_title(3, ProProfilerLocalization.localize("tabs.settings", "⚙️ Settings"))

    # Connect settings change
    settings_ui.setting_changed.connect(_on_setting_changed)
    
    # Apply initial visibility
    _apply_initial_visibility(settings_ui)

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

    print_rich(ProProfilerLocalization.localize("logs.loaded", "[b]Godot ProProfiler has Loaded![/b]"))


func _on_setting_changed(key: String, value: Variant) -> void:
    match key:
        "show_logs": _tabs.set_tab_hidden(0, !value)
        "show_cpu": _tabs.set_tab_hidden(1, !value)
        "show_disk": _tabs.set_tab_hidden(2, !value)
        "language":
            # Update titles with new language
            _tabs.set_tab_title(0, ProProfilerLocalization.localize("tabs.logs", "🖨️ Logs"))
            _tabs.set_tab_title(1, ProProfilerLocalization.localize("tabs.cpu", "⚡ CPU Profiler"))
            _tabs.set_tab_title(2, ProProfilerLocalization.localize("tabs.disk", "💾 Disk Usage"))
            _tabs.set_tab_title(3, ProProfilerLocalization.localize("tabs.settings", "⚙️ Settings"))


func _apply_initial_visibility(settings_ui: Control) -> void:
    _tabs.set_tab_hidden(0, !settings_ui._get_setting("show_logs", true))
    _tabs.set_tab_hidden(1, !settings_ui._get_setting("show_cpu", false))
    _tabs.set_tab_hidden(2, !settings_ui._get_setting("show_disk", true))


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

    print_rich(ProProfilerLocalization.localize("logs.stopped", "[b]Godot Profiler was Stopped.[/b]"))
