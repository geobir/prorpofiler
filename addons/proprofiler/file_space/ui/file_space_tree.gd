###############################################################
# addons/proprofiler/file_space/ui/file_space_tree.gd
# Tree view showing folder/file hierarchy with sizes
###############################################################

extends Tree

const ProfilerDesign = preload("res://addons/proprofiler/profiler_design.gd")
const FileSpaceData = preload("res://addons/proprofiler/file_space/file_space_data.gd")

# Signal emitted when a file is selected (path, extension)
signal file_selected(file_path: String, file_ext: String)


func _ready() -> void:
    custom_minimum_size = Vector2(500, 0)
    columns = 3
    column_titles_visible = true
    set_column_title(0, "Path")
    set_column_title(1, "Size")
    set_column_title(2, "Ratio")
    
    # Column configuration: Resizable and Balanced
    var configs = [
        {"ratio": 10, "min_w": 250}, # Path
        {"ratio": 2, "min_w": 100}, # Size
        {"ratio": 1, "min_w": 80}   # Ratio %
    ]
    
    for i in range(configs.size()):
        var cfg = configs[i]
        set_column_expand(i, true)
        set_column_expand_ratio(i, cfg.ratio)
        set_column_custom_minimum_width(i, cfg.min_w)
        set_column_clip_content(i, true)
    
    # Connect selection signal
    item_selected.connect(_on_item_selected)


func update_tree(root_folders: Array, total_bytes: int) -> void:
    clear()
    
    if root_folders.is_empty():
        var root = create_item()
        root.set_text(0, "No data - run scan first")
        # root.set_text_overline(0, false)
        return
    
    # Create root item
    var root = create_item()
    root.set_text(0, "Project Files")
    root.set_text(1, ProfilerDesign.format_bytes(total_bytes))
    root.set_text(2, "100%")
    root.set_metadata(0, "")  # Empty metadata for root
    _setup_item_style(root, ProfilerDesign.COLOR_TEXT, true)
    
    # Add folders
    for folder in root_folders:
        _add_folder_recursive(root, folder, total_bytes)
    
    # Expand root by default
    root.collapsed = false


func _add_folder_recursive(parent_item: TreeItem, folder: FileSpaceData.FolderEntry, total_bytes: int) -> void:
    var item = create_item(parent_item)
    
    # Folder name with size
    var folder_name = folder.path.get_file()
    if folder_name.is_empty():
        folder_name = folder.path
    
    item.set_text(0, folder_name + ("/"))
    item.set_text(1, ProfilerDesign.format_bytes(folder.size_bytes))
    item.set_metadata(0, folder.path)
    
    var percent = (folder.size_bytes * 100.0) / maxf(total_bytes, 1)
    item.set_text(2, ProfilerDesign.format_percent(percent))
    
    _setup_item_style(item, ProfilerDesign.COLOR_TEXT_DIM, false)
    
    # Add children (folders first, then files)
    var sub_folders = []
    var files = []
    
    for child in folder.children:
        if child is FileSpaceData.FolderEntry:
            sub_folders.append(child)
        else:
            files.append(child)
    
    # Add sub-folders recursively
    for sub_folder in sub_folders:
        _add_folder_recursive(item, sub_folder, total_bytes)
    
    # Add files
    for file in files:
        _add_file(item, file, total_bytes)
    
    # Expand folders by default if not too many items
    item.collapsed = folder.children.size() > 50


func _add_file(parent_item: TreeItem, file: FileSpaceData.FileEntry, total_bytes: int) -> void:
    var item = create_item(parent_item)
    
    var file_name = file.path.get_file()
    item.set_text(0, file_name)
    item.set_text(1, ProfilerDesign.format_bytes(file.size_bytes))
    item.set_metadata(0, file.path)  # Store full file path
    
    var percent = (file.size_bytes * 100.0) / maxf(total_bytes, 1)
    item.set_text(2, ProfilerDesign.format_percent(percent))
    
    # Color by file type
    var color = ProfilerDesign.get_type_color(file.path.get_extension())
    _setup_item_style(item, color, false)


func _setup_item_style(item: TreeItem, color: Color, is_header: bool) -> void:
    item.set_custom_color(0, color)
    item.set_custom_color(1, color)
    item.set_custom_color(2, color)
    
    if is_header:
        item.set_custom_font_size(0, ProfilerDesign.FONT_SIZE_HEADING)
        item.set_custom_font_size(1, ProfilerDesign.FONT_SIZE_HEADING)
        item.set_custom_font_size(2, ProfilerDesign.FONT_SIZE_HEADING)


func _on_item_selected() -> void:
    """Called when user selects an item in the tree"""
    var selected_item = get_selected()
    if not selected_item:
        return
    
    var file_path = selected_item.get_metadata(0)
    if not file_path or file_path.is_empty():
        return  # Root item has no path
    
    # Extract extension from file path
    var file_ext = file_path.get_extension().to_lower()
    
    # Emit signal with path and extension
    file_selected.emit(file_path, file_ext)
