###############################################################
# addons/proprofiler/file_space/file_space_analyzer.gd
# Recursively scans project directory and analyzes file sizes
###############################################################

extends RefCounted

const ProfilerDesign = preload("res://addons/proprofiler/profiler_design.gd")
const FileSpaceData = preload("res://addons/proprofiler/file_space/file_space_data.gd")

signal scan_started
signal scan_progress(processed: int, total: int)
signal scan_completed(result: FileSpaceData.AnalysisResult)

var analysis_result: FileSpaceData.AnalysisResult
var is_scanning: bool = false
var last_error: String = ""
var project_root: String = "res://"
var category_filter: String = ""  # Empty = show all


## Start scanning the project
func start_scan(root_path: String = "res://") -> void:
    project_root = root_path
    analysis_result = FileSpaceData.AnalysisResult.new()
    is_scanning = true
    last_error = ""
    
    emit_signal("scan_started")
    
    var start_time = Time.get_ticks_msec()
    
    # Scan main directories (excluding addons, generated, and Godot internal)
    var ignored_folders = ["addons", ".git", ".godot", "generated", ".import"]
    var ignored_extensions = ["import", "uid"]  # Skip .import and .uid files
    var root_folder = _scan_directory(project_root, analysis_result, ignored_folders, ignored_extensions, 0)
    analysis_result.root_folders.append(root_folder)
    
    analysis_result.scan_time_ms = Time.get_ticks_msec() - start_time
    analysis_result.last_scan_timestamp = Time.get_unix_time_from_system()
    is_scanning = false
    
    emit_signal("scan_completed", analysis_result)


## Recursively scan directory
func _scan_directory(dir_path: String, result: FileSpaceData.AnalysisResult, ignored_folders: Array, ignored_extensions: Array, depth: int) -> FileSpaceData.FolderEntry:
    var folder = FileSpaceData.FolderEntry.new(dir_path)
    
    var dir = DirAccess.open(dir_path)
    if dir == null:
        last_error = "Failed to open: " + dir_path
        return folder
    
    dir.list_dir_begin()
    var file_name = dir.get_next()
    
    while file_name != "":
        # Skip hidden and ignored files
        if file_name.begins_with("."):
            file_name = dir.get_next()
            continue
        
        var full_path = dir_path.path_join(file_name)
        
        if dir.current_is_dir():
            # Skip ignored folders
            if file_name in ignored_folders:
                file_name = dir.get_next()
                continue
            
            # Recursively scan subfolder
            if depth < 10:  # Limit recursion depth
                var sub_folder = _scan_directory(full_path, result, ignored_folders, ignored_extensions, depth + 1)
                folder.children.append(sub_folder)
                folder.size_bytes += sub_folder.size_bytes
                result.folder_count += 1
        else:
            # Skip files with ignored extensions
            var ext = file_name.get_extension()
            if ext in ignored_extensions:
                file_name = dir.get_next()
                continue
            
            # Process file
            var file_size = 0
            var file = FileAccess.open(full_path, FileAccess.READ)
            if file != null:
                file_size = file.get_length()
            var category = ProfilerDesign.get_file_category(ext)
            
            var file_entry = FileSpaceData.FileEntry.new(full_path, file_size, category, false)
            folder.children.append(file_entry)
            
            folder.size_bytes += file_size
            result.total_size_bytes += file_size
            result.file_count += 1
            result.add_to_category(category, file_size)
        
        file_name = dir.get_next()
    
    folder.file_count = result.file_count
    return folder


## Set category filter (empty string = show all)
func set_category_filter(category: String) -> void:
    category_filter = category


## Get filtered root folders based on category
func get_filtered_root_folders() -> Array:
    if category_filter.is_empty():
        return analysis_result.root_folders
    
    var filtered = []
    for root_folder in analysis_result.root_folders:
        var filtered_folder = _filter_folder_by_category(root_folder, category_filter)
        if filtered_folder.children.size() > 0:
            filtered.append(filtered_folder)
    return filtered


func _filter_folder_by_category(folder: FileSpaceData.FolderEntry, target_category: String) -> FileSpaceData.FolderEntry:
    var filtered = FileSpaceData.FolderEntry.new(folder.path)
    
    for child in folder.children:
        if child is FileSpaceData.FolderEntry:
            var sub_filtered = _filter_folder_by_category(child, target_category)
            if sub_filtered.children.size() > 0:
                filtered.children.append(sub_filtered)
                filtered.size_bytes += sub_filtered.size_bytes
        elif child.category == target_category:
            filtered.children.append(child)
            filtered.size_bytes += child.size_bytes
    
    return filtered
func get_sorted_categories() -> Array:
    var result = analysis_result
    var categories = []
    
    for cat in result.category_breakdown.keys():
        categories.append({
            "name": cat,
            "size": result.category_breakdown[cat]["size"],
            "count": result.category_breakdown[cat]["count"],
            "percent": (result.category_breakdown[cat]["size"] * 100.0) / maxf(result.total_size_bytes, 1)
        })
    
    # Sort by size descending
    categories.sort_custom(func(a, b): return a["size"] > b["size"])
    return categories
