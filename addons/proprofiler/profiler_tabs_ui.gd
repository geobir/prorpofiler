###############################################################
# addons/proprofiler/profiler_tabs_ui.gd
# Main container with tabs for CPU Profiler and File Space
###############################################################

extends VBoxContainer

const ProfilerDesign = preload("res://addons/proprofiler/profiler_design.gd")
const CPUProfilerUI = preload("res://addons/proprofiler/cpu_profiler/ui/cpu_profiler_ui.gd")
const FileSpaceUI = preload("res://addons/proprofiler/file_space/ui/file_space_ui.gd")


var tab_container: TabContainer
var cpu_profiler_tab: CPUProfilerUI
var file_space_tab: FileSpaceUI

# OLD TO REMOVE?

func _ready() -> void:
    custom_minimum_size = Vector2(1200, 700)
    
    # Create tab container
    tab_container = TabContainer.new()
    tab_container.add_theme_color_override("font_disabled_color", ProfilerDesign.COLOR_TEXT_DIM)
    tab_container.add_theme_color_override("font_focus_color", ProfilerDesign.COLOR_TEXT)
    tab_container.add_theme_color_override("font_outline_color", ProfilerDesign.COLOR_TEXT)
    add_child(tab_container)
    
    # CPU Profiler tab
    cpu_profiler_tab = CPUProfilerUI.new()
    tab_container.add_child(cpu_profiler_tab)
    tab_container.set_tab_title(0, "⚡ CPU Profiler")
    
    # File Space tab
    file_space_tab = FileSpaceUI.new()
    tab_container.add_child(file_space_tab)
    tab_container.set_tab_title(1, "💾 Disk Usage")
