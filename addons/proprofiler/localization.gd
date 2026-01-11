###############################################################
# addons/proprofiler/localization.gd
# Key funcs/classes: • ProProfilerLocalization – addon translation helper
###############################################################
@tool
class_name ProProfilerLocalization

const TRANSLATIONS_DIR = "res://addons/proprofiler/i18n/"
const DEFAULT_LOCALE = "en"

static var _catalog: Dictionary = {}
static var _current_locale: String = ""

static func load_translations() -> void:
    var locale = DEFAULT_LOCALE
    
    # Try to load saved locale first
    if FileAccess.file_exists("user://proprofiler_settings.cfg"):
        var config = ConfigFile.new()
        config.load("user://proprofiler_settings.cfg")
        locale = config.get_value("settings", "language", "")
    
    if locale == "":
        if Engine.is_editor_hint():
            # In editor, use the editor language
            if TranslationServer.has_method("get_tool_locale"):
                locale = TranslationServer.get_tool_locale()
            else:
                # Fallback for older versions if needed, but 4.5 should have it
                var editor_settings = EditorInterface.get_editor_settings()
                if editor_settings:
                    locale = editor_settings.get_setting("interface/editor/editor_language")
        else:
            # At runtime, use the game locale
            locale = TranslationServer.get_locale()

    # Handle sub-locales (e.g., 'en_US' -> 'en')
    if "_" in locale:
        var base_locale = locale.split("_")[0]
        if FileAccess.file_exists(TRANSLATIONS_DIR + locale + ".json"):
            pass # Keep specific locale
        elif FileAccess.file_exists(TRANSLATIONS_DIR + base_locale + ".json"):
            locale = base_locale

    _current_locale = locale
    _catalog = _load_json(locale)
    
    # Fill missing keys from default locale
    if locale != DEFAULT_LOCALE:
        var default_catalog = _load_json(DEFAULT_LOCALE)
        for key in default_catalog:
            if not _catalog.has(key):
                _catalog[key] = default_catalog[key]

static func _load_json(locale_code: String) -> Dictionary:
    var path = TRANSLATIONS_DIR + locale_code + ".json"
    if not FileAccess.file_exists(path):
        return {}
    
    var file = FileAccess.open(path, FileAccess.READ)
    if not file:
        return {}
    
    var text = file.get_as_text()
    file.close()
    
    if text == "":
        return {}
        
    # Remove UTF-8 BOM if present
    if text.begins_with("\ufeff"):
        text = text.substr(1)
    
    var json = JSON.new()
    var error = json.parse(text)
    
    if error != OK:
        push_error("ProProfiler: Failed to parse JSON in %s: %s" % [path, json.get_error_message()])
        return {}
    
    var data = json.data
    if typeof(data) == TYPE_DICTIONARY:
        return data
    
    return {}

static func localize(key: String, fallback: String = "") -> String:
    if _catalog.is_empty():
        load_translations()
    
    if _catalog.has(key):
        return _catalog[key]
        
    return fallback if fallback != "" else key

static func get_current_locale() -> String:
    return _current_locale

static func set_forced_locale(locale: String) -> void:
    _current_locale = locale
    _catalog = _load_json(locale)
    
    # Fill missing keys from default locale
    if locale != DEFAULT_LOCALE:
        var default_catalog = _load_json(DEFAULT_LOCALE)
        for key in default_catalog:
            if not _catalog.has(key):
                _catalog[key] = default_catalog[key]
