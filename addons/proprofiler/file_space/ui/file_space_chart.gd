###############################################################
# addons/proprofiler/file_space/ui/file_space_chart.gd
# Horizontal bar chart showing space breakdown by file type
###############################################################

extends Control

const ProfilerDesign = preload("res://addons/proprofiler/profiler_design.gd")


var categories: Array = []

# Map category names to representative file extensions for color lookup
var category_to_color_map = {
    "Images": ProfilerDesign.COLOR_TYPE_IMAGE,
    "Videos": ProfilerDesign.COLOR_TYPE_VIDEO,
    "Audio": ProfilerDesign.COLOR_TYPE_AUDIO,
    "Code": ProfilerDesign.COLOR_TYPE_CODE,
    "Scenes": ProfilerDesign.COLOR_TYPE_SCENE,
    "Data": ProfilerDesign.COLOR_TYPE_DATA,
    "Shaders": ProfilerDesign.COLOR_TYPE_SHADER,
    "Fonts": ProfilerDesign.COLOR_TYPE_FONT,
    "Other": ProfilerDesign.COLOR_TYPE_OTHER,
}


func _ready() -> void:
    custom_minimum_size = Vector2(0, 280)
    
    # Create legend label
    var legend_label = Label.new()
    legend_label.text = "Space Breakdown by Type"
    legend_label.add_theme_font_size_override("font_size", ProfilerDesign.FONT_SIZE_HEADING)
    legend_label.add_theme_color_override("font_color", ProfilerDesign.COLOR_TEXT)
    
    var parent = get_parent()
    if parent:
        parent.add_child(legend_label)
        parent.move_child(legend_label, parent.get_child_count() - 2)


func update_chart(sorted_categories: Array) -> void:
    categories = sorted_categories
    queue_redraw()


func _draw() -> void:
    # Draw background
    draw_rect(Rect2(0, 0, size.x, size.y), ProfilerDesign.COLOR_BG_SECONDARY)
    
    if categories.is_empty():
        var text_pos = Vector2(20, size.y / 2)
        draw_string(get_theme_font("font"), text_pos, "No data - run scan first", HORIZONTAL_ALIGNMENT_LEFT, -1, ProfilerDesign.FONT_SIZE_BODY, ProfilerDesign.COLOR_TEXT_DIM)
        return
    
    var y_offset = 20
    var bar_height = 18
    var spacing = 6
    var label_width = 150
    var max_bar_width = maxi(size.x - label_width - 150, 150)  # Ensure minimum width
    
    # Find max size for scaling
    var max_size = 1
    for cat in categories:
        max_size = maxi(max_size, cat["size"])
    
    # Draw each category bar
    for cat in categories:
        # Category label
        draw_string(get_theme_font("font"), Vector2(10, y_offset + 12), cat["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, ProfilerDesign.FONT_SIZE_SMALL, ProfilerDesign.COLOR_TEXT)
        
        # Bar background
        var bar_rect = Rect2(label_width, y_offset, max_bar_width, bar_height)
        draw_rect(bar_rect, ProfilerDesign.COLOR_GRID)
        
        # Bar fill - use category name mapping
        var bar_width = (cat["size"] * max_bar_width) / float(max_size)
        var color = category_to_color_map.get(cat["name"], ProfilerDesign.COLOR_TYPE_OTHER)
        draw_rect(Rect2(label_width, y_offset, bar_width, bar_height), color)
        
        # Size and percentage label (positioned after bar)
        var size_text = "%s (%.1f%%)" % [ProfilerDesign.format_bytes(cat["size"]), cat["percent"]]
        draw_string(get_theme_font("font"), Vector2(label_width + max_bar_width + 10, y_offset + 12), size_text, HORIZONTAL_ALIGNMENT_LEFT, -1, ProfilerDesign.FONT_SIZE_TINY, ProfilerDesign.COLOR_TEXT_DIM)
        
        y_offset += bar_height + spacing
