###############################################################
# addons/proprofiler/file_space/file_space_data.gd
# Data structures for file/folder analysis results
###############################################################

extends RefCounted


## Single file/folder entry
class FileEntry:
    var path: String
    var size_bytes: int = 0
    var category: String = "Other"
    var is_folder: bool = false
    var file_count: int = 0  # For folders, total files inside
    
    func _init(p_path: String, p_size: int, p_cat: String, p_folder: bool = false) -> void:
        path = p_path
        size_bytes = p_size
        category = p_cat
        is_folder = p_folder


## Folder hierarchy with children
class FolderEntry extends FileEntry:
    var children: Array[FileEntry] = []
    
    func _init(p_path: String, p_folder: bool = true) -> void:
        path = p_path
        is_folder = p_folder
        size_bytes = 0


## Analysis results container
class AnalysisResult:
    var total_size_bytes: int = 0
    var file_count: int = 0
    var folder_count: int = 0
    var root_folders: Array[FolderEntry] = []
    var category_breakdown: Dictionary = {}  # category -> {size, count}
    var scan_time_ms: float = 0.0
    var last_scan_timestamp: float = 0.0
    
    ## Add bytes to category breakdown
    func add_to_category(category: String, bytes: int) -> void:
        if not category_breakdown.has(category):
            category_breakdown[category] = {"size": 0, "count": 0}
        category_breakdown[category]["size"] += bytes
        category_breakdown[category]["count"] += 1


## Main analysis data holder
var analysis_result: AnalysisResult = AnalysisResult.new()
var is_scanning: bool = false
var last_error: String = ""
