import 'dart:convert';
import 'dart:io';

import '../logging/app_logger.dart';
import '../models/theme_presets.dart';

/// Persistence for the preset list (custom entries + hidden built-ins).
///
/// The applied theme itself still goes through the Rust theme bridge; this
/// store only owns the `deepssh.uiPresets` / `deepssh.uiHiddenPresets`
/// equivalent the prototype keeps in localStorage.
abstract interface class ThemePresetStore {
  Future<ThemePresetLibrary> load();

  Future<void> save(ThemePresetLibrary library);
}

class InMemoryThemePresetStore implements ThemePresetStore {
  InMemoryThemePresetStore([ThemePresetLibrary? initial])
    : _library = initial ?? ThemePresetLibrary.empty();

  ThemePresetLibrary _library;

  @override
  Future<ThemePresetLibrary> load() async => _library;

  @override
  Future<void> save(ThemePresetLibrary library) async {
    _library = library;
  }
}

class FileThemePresetStore implements ThemePresetStore {
  FileThemePresetStore({AppLogPlatform? platform})
    : _platform = platform ?? AppLogPlatform.current();

  static const String _fileName = 'theme_presets.json';

  final AppLogPlatform _platform;

  File get _file => File(
    [_platform.configDirectory().path, _fileName].join(Platform.pathSeparator),
  );

  @override
  Future<ThemePresetLibrary> load() async {
    try {
      final file = _file;
      if (!await file.exists()) return ThemePresetLibrary.empty();
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return ThemePresetLibrary.empty();
      return ThemePresetLibrary.fromJson(decoded.cast<String, Object?>());
    } catch (_) {
      // A corrupt preset file must never take the theme page down; the user
      // can still create presets again.
      return ThemePresetLibrary.empty();
    }
  }

  @override
  Future<void> save(ThemePresetLibrary library) async {
    final file = _file;
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(library.toJson()));
  }
}
