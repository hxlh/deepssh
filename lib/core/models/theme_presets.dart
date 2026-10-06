import 'package:flutter/material.dart';

import '../widgets/css_colors.dart' as css;
import 'theme_settings.dart';

/// One selectable theme preset.
///
/// Built-ins are rebuilt from [UiThemeSettings] / [TerminalThemeSettings] so
/// they always track the shipped defaults; custom presets carry a serialized
/// snapshot of whatever was on screen when they were created.
class ThemePreset {
  const ThemePreset({
    required this.id,
    required this.name,
    required this.swatch,
    this.ui,
    this.terminal,
    this.custom = false,
  });

  final String id;
  final String name;
  final Color swatch;
  final UiThemeSettings? ui;
  final TerminalThemeSettings? terminal;
  final bool custom;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'swatch': css.colorToHex(swatch),
    if (ui != null) 'ui': uiToJson(ui!),
    if (terminal != null) 'terminal': terminalToJson(terminal!),
  };

  static ThemePreset? fromJson(
    Map<String, Object?> json, {
    required bool terminal,
  }) {
    final id = json['id'];
    final name = json['name'];
    if (id is! String || name is! String) return null;
    final swatch =
        css.hexToColor(json['swatch'] as String? ?? '') ??
        const Color(0xFF000000);
    final settings = json[terminal ? 'terminal' : 'ui'];
    if (settings is! Map) return null;
    final map = settings.cast<String, Object?>();
    if (terminal) {
      final parsed = terminalFromJson(map);
      if (parsed == null) return null;
      return ThemePreset(
        id: id,
        name: name,
        swatch: swatch,
        terminal: parsed,
        custom: true,
      );
    }
    final parsed = uiFromJson(map);
    if (parsed == null) return null;
    return ThemePreset(
      id: id,
      name: name,
      swatch: swatch,
      ui: parsed,
      custom: true,
    );
  }
}

/// The prototype ships a single built-in: Command Deck. Everything else in
/// the picker is a user-created preset.
List<ThemePreset> builtInUiPresets() => [
  ThemePreset(
    id: 'deck',
    name: 'Command Deck',
    swatch: const Color(0xFFFAF9F5),
    ui: UiThemeSettings.commandDeck(),
  ),
];

/// Terminal side of the same single built-in.
List<ThemePreset> builtInTerminalPresets() => [
  ThemePreset(
    id: 'deck',
    name: 'Command Deck',
    swatch: const Color(0xFF17181A),
    terminal: TerminalThemeSettings.commandDeck(),
  ),
];

/// Custom presets plus the built-ins the user removed from the list.
///
/// Mirrors the prototype's `deepssh.uiPresets` / `deepssh.uiHiddenPresets`
/// localStorage keys, but persists to `config/theme_presets.json` instead.
class ThemePresetLibrary {
  ThemePresetLibrary({
    List<ThemePreset>? uiCustom,
    List<ThemePreset>? terminalCustom,
    Set<String>? hiddenUiIds,
    Set<String>? hiddenTerminalIds,
  }) : uiCustom = uiCustom ?? <ThemePreset>[],
       terminalCustom = terminalCustom ?? <ThemePreset>[],
       hiddenUiIds = hiddenUiIds ?? <String>{},
       hiddenTerminalIds = hiddenTerminalIds ?? <String>{};

  factory ThemePresetLibrary.empty() => ThemePresetLibrary();

  final List<ThemePreset> uiCustom;
  final List<ThemePreset> terminalCustom;
  final Set<String> hiddenUiIds;
  final Set<String> hiddenTerminalIds;

  List<ThemePreset> get uiPresets => [
    for (final preset in builtInUiPresets())
      if (!hiddenUiIds.contains(preset.id)) preset,
    ...uiCustom,
  ];

  List<ThemePreset> get terminalPresets => [
    for (final preset in builtInTerminalPresets())
      if (!hiddenTerminalIds.contains(preset.id)) preset,
    ...terminalCustom,
  ];

  ThemePreset? uiPreset(String id) {
    for (final preset in uiPresets) {
      if (preset.id == id) return preset;
    }
    return null;
  }

  ThemePreset? terminalPreset(String id) {
    for (final preset in terminalPresets) {
      if (preset.id == id) return preset;
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    'uiCustom': [for (final preset in uiCustom) preset.toJson()],
    'terminalCustom': [for (final preset in terminalCustom) preset.toJson()],
    'uiHidden': hiddenUiIds.toList()..sort(),
    'terminalHidden': hiddenTerminalIds.toList()..sort(),
  };

  static ThemePresetLibrary fromJson(Map<String, Object?> json) {
    List<ThemePreset> read(String key, {required bool terminal}) {
      final raw = json[key];
      if (raw is! List) return <ThemePreset>[];
      return [
        for (final item in raw)
          if (item is Map)
            if (ThemePreset.fromJson(
                  item.cast<String, Object?>(),
                  terminal: terminal,
                )
                case final preset?)
              preset,
      ];
    }

    Set<String> readIds(String key) {
      final raw = json[key];
      if (raw is! List) return <String>{};
      return {
        for (final item in raw)
          if (item is String) item,
      };
    }

    return ThemePresetLibrary(
      uiCustom: read('uiCustom', terminal: false),
      terminalCustom: read('terminalCustom', terminal: true),
      hiddenUiIds: readIds('uiHidden'),
      hiddenTerminalIds: readIds('terminalHidden'),
    );
  }
}

Map<String, Object?> uiToJson(UiThemeSettings value) => {
  'presetName': value.presetName,
  'fontFamily': value.fontFamily,
  'fontSize': value.fontSize,
  'normalFontWeight': value.normalFontWeight,
  'boldFontWeight': value.boldFontWeight,
  'background': css.colorToHex(value.background),
  'panel': css.colorToHex(value.panel),
  'sidebar': css.colorToHex(value.sidebar),
  'accent': css.colorToHex(value.accent),
  'textPrimary': css.colorToHex(value.textPrimary),
  'textMuted': css.colorToHex(value.textMuted),
};

UiThemeSettings? uiFromJson(Map<String, Object?> json) {
  final presetName = json['presetName'];
  final fontFamily = json['fontFamily'];
  final fontSize = json['fontSize'];
  if (presetName is! String || fontFamily is! String || fontSize is! num) {
    return null;
  }
  Color? color(String key) => css.hexToColor(json[key] as String? ?? '');
  final background = color('background');
  final panel = color('panel');
  final sidebar = color('sidebar');
  final accent = color('accent');
  final textPrimary = color('textPrimary');
  final textMuted = color('textMuted');
  if (background == null ||
      panel == null ||
      sidebar == null ||
      accent == null ||
      textPrimary == null ||
      textMuted == null) {
    return null;
  }
  return UiThemeSettings(
    presetName: presetName,
    fontFamily: fontFamily,
    fontSize: fontSize.toDouble(),
    normalFontWeight: json['normalFontWeight'] as int? ?? 500,
    boldFontWeight: json['boldFontWeight'] as int? ?? 700,
    background: background,
    panel: panel,
    sidebar: sidebar,
    accent: accent,
    textPrimary: textPrimary,
    textMuted: textMuted,
  );
}

Map<String, Object?> terminalToJson(TerminalThemeSettings value) => {
  'presetName': value.presetName,
  'fontFamily': value.fontFamily,
  'fontSize': value.fontSize,
  'normalFontWeight': value.normalFontWeight,
  'boldFontWeight': value.boldFontWeight,
  'cursorStyle': value.cursorStyle.name,
  'cursorBlink': value.cursorBlink,
  'foreground': css.colorToHex(value.foreground),
  'terminalBackground': css.colorToHex(value.terminalBackground),
  'selectionColor': css.colorToHex(value.selectionColor),
  'cursorColor': css.colorToHex(value.cursorColor),
  'scrollbackLines': value.scrollbackLines,
  'regexHighlights': [
    for (final rule in value.regexHighlights)
      {
        'pattern': rule.pattern,
        'color': css.colorToHex(rule.color),
        'note': rule.note,
      },
  ],
};

TerminalThemeSettings? terminalFromJson(Map<String, Object?> json) {
  final presetName = json['presetName'];
  final fontFamily = json['fontFamily'];
  final fontSize = json['fontSize'];
  if (presetName is! String || fontFamily is! String || fontSize is! num) {
    return null;
  }
  Color? color(String key) => css.hexToColor(json[key] as String? ?? '');
  final foreground = color('foreground');
  final background = color('terminalBackground');
  final selection = color('selectionColor');
  final cursor = color('cursorColor');
  if (foreground == null ||
      background == null ||
      selection == null ||
      cursor == null) {
    return null;
  }
  final rules = <RegexHighlight>[];
  final rawRules = json['regexHighlights'];
  if (rawRules is List) {
    for (final item in rawRules) {
      if (item is! Map) continue;
      final map = item.cast<String, Object?>();
      final pattern = map['pattern'];
      final ruleColor = css.hexToColor(map['color'] as String? ?? '');
      if (pattern is! String || ruleColor == null) continue;
      rules.add(
        RegexHighlight(
          pattern: pattern,
          color: ruleColor,
          note: map['note'] as String? ?? '',
        ),
      );
    }
  }
  return TerminalThemeSettings(
    presetName: presetName,
    fontFamily: fontFamily,
    fontSize: fontSize.toDouble(),
    normalFontWeight: json['normalFontWeight'] as int? ?? 400,
    boldFontWeight: json['boldFontWeight'] as int? ?? 700,
    cursorStyle: CursorStyle.values.firstWhere(
      (style) => style.name == json['cursorStyle'],
      orElse: () => CursorStyle.block,
    ),
    cursorBlink: json['cursorBlink'] as bool? ?? true,
    foreground: foreground,
    terminalBackground: background,
    selectionColor: selection,
    cursorColor: cursor,
    scrollbackLines: json['scrollbackLines'] as int? ?? 10000,
    regexHighlights: rules,
  );
}
