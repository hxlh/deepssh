import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../features/theme/theme_bridge.dart';
import '../../src/rust/rust_init.dart';
import '../../src/rust/theme.dart' as rust_theme;
import '../logging/app_logger.dart';
import '../models/theme_presets.dart';
import '../widgets/css_colors.dart' as css;

/// Persistence for the preset list (custom entries + hidden built-ins).
///
/// Presets now share `config/theme_settings.yaml` with the active theme. The
/// Rust store merges either half into the same document, so saving colors and
/// saving the preset catalogue cannot overwrite one another.
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

  static const String _legacyFileName = 'theme_presets.json';

  final AppLogPlatform _platform;

  File get _legacyFile => File(
    [
      _platform.configDirectory().path,
      _legacyFileName,
    ].join(Platform.pathSeparator),
  );

  @override
  Future<ThemePresetLibrary> load() async {
    await ensureRustInitialized();
    final stored = presetLibraryFromRust(await rust_theme.loadThemePresets());
    if (_hasPresetData(stored)) return stored;
    return _migrateLegacyJson();
  }

  @override
  Future<void> save(ThemePresetLibrary library) async {
    await ensureRustInitialized();
    await rust_theme.saveThemePresets(presets: presetLibraryToRust(library));
  }

  Future<ThemePresetLibrary> _migrateLegacyJson() async {
    try {
      final file = _legacyFile;
      if (!await file.exists()) return ThemePresetLibrary.empty();
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return ThemePresetLibrary.empty();
      final library = ThemePresetLibrary.fromJson(
        decoded.cast<String, Object?>(),
      );
      await save(library);
      await file.delete();
      return library;
    } catch (_) {
      // Keep a corrupt legacy file in place for manual recovery. The unified
      // YAML store remains usable with an empty catalogue.
      return ThemePresetLibrary.empty();
    }
  }
}

bool _hasPresetData(ThemePresetLibrary library) {
  return library.uiCustom.isNotEmpty ||
      library.terminalCustom.isNotEmpty ||
      library.hiddenUiIds.isNotEmpty ||
      library.hiddenTerminalIds.isNotEmpty;
}

ThemePresetLibrary presetLibraryFromRust(rust_theme.ThemePresetLibrary value) {
  return ThemePresetLibrary(
    uiCustom: [for (final preset in value.uiPresets) _presetFromRust(preset)],
    terminalCustom: [
      for (final preset in value.terminalPresets) _presetFromRust(preset),
    ],
    hiddenUiIds: value.hiddenUiPresetIds.toSet(),
    hiddenTerminalIds: value.hiddenTerminalPresetIds.toSet(),
  );
}

rust_theme.ThemePresetLibrary presetLibraryToRust(ThemePresetLibrary value) {
  final hiddenUi = value.hiddenUiIds.toList()..sort();
  final hiddenTerminal = value.hiddenTerminalIds.toList()..sort();
  return rust_theme.ThemePresetLibrary(
    uiPresets: [for (final preset in value.uiCustom) _presetToRust(preset)],
    terminalPresets: [
      for (final preset in value.terminalCustom) _presetToRust(preset),
    ],
    hiddenUiPresetIds: hiddenUi,
    hiddenTerminalPresetIds: hiddenTerminal,
  );
}

ThemePreset _presetFromRust(rust_theme.ThemePreset value) {
  return ThemePreset(
    id: value.id,
    name: value.name,
    swatch: css.hexToColor(value.swatch) ?? const Color(0xFF000000),
    ui: value.ui == null ? null : uiFromRust(value.ui!),
    terminal: value.terminal == null ? null : terminalFromRust(value.terminal!),
    custom: true,
  );
}

rust_theme.ThemePreset _presetToRust(ThemePreset value) {
  return rust_theme.ThemePreset(
    id: value.id,
    name: value.name,
    swatch: css.colorToHex(value.swatch),
    ui: value.ui == null ? null : uiToRust(value.ui!),
    terminal: value.terminal == null ? null : terminalToRust(value.terminal!),
  );
}
