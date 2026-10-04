import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/theme_presets.dart';
import '../../core/models/theme_settings.dart';
import '../../core/storage/theme_preset_store.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/color_picker_field.dart';
import '../../core/widgets/css_colors.dart' as css;
import '../../core/widgets/deck_fields.dart';
import '../../core/widgets/deck_page.dart';
import '../../core/widgets/deck_widgets.dart';

/// Appearance page, rebuilt from `design/deepssh-prototype.html#page-theme`.
///
/// Edits are buffered in this page and land in the app when 保存主题 is
/// pressed; 恢复默认 swaps the draft back to the Command Deck baseline. The
/// preset list itself (custom entries and hidden built-ins) persists through
/// [ThemePresetStore] as soon as it changes, matching the prototype where
/// localStorage updates immediately.
class ThemeConfigPage extends StatefulWidget {
  const ThemeConfigPage({
    super.key,
    required this.uiSettings,
    required this.terminalSettings,
    required this.onUiSettingsChanged,
    required this.onTerminalSettingsChanged,
    required this.onBack,
    this.presetStore,
  });

  final UiThemeSettings uiSettings;
  final TerminalThemeSettings terminalSettings;
  final ValueChanged<UiThemeSettings> onUiSettingsChanged;
  final ValueChanged<TerminalThemeSettings> onTerminalSettingsChanged;
  final VoidCallback onBack;
  final ThemePresetStore? presetStore;

  @override
  State<ThemeConfigPage> createState() => _ThemeConfigPageState();
}

class _ThemeConfigPageState extends State<ThemeConfigPage> {
  late UiThemeSettings uiSettings;
  late TerminalThemeSettings termSettings;
  late final ThemePresetStore _presetStore;
  late final ThemePresetLibrary _library;

  String? _uiPresetId;
  String? _terminalPresetId;
  final _regexRuleKeys = <Key>[];

  @override
  void initState() {
    super.initState();
    uiSettings = widget.uiSettings;
    termSettings = widget.terminalSettings;
    _presetStore = widget.presetStore ?? FileThemePresetStore();
    _library = ThemePresetLibrary.empty();
    _syncRegexRuleKeys(termSettings.regexHighlights.length);
    _uiPresetId = _matchUiPreset(uiSettings);
    _terminalPresetId = _matchTerminalPreset(termSettings);
    unawaited(_loadPresetLibrary());
  }

  @override
  void didUpdateWidget(covariant ThemeConfigPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uiSettings != widget.uiSettings) {
      uiSettings = widget.uiSettings;
    }
    if (oldWidget.terminalSettings != widget.terminalSettings) {
      termSettings = widget.terminalSettings;
      _syncRegexRuleKeys(termSettings.regexHighlights.length);
    }
  }

  void _syncRegexRuleKeys(int count) {
    while (_regexRuleKeys.length < count) {
      _regexRuleKeys.add(UniqueKey());
    }
    if (_regexRuleKeys.length > count) {
      _regexRuleKeys.removeRange(count, _regexRuleKeys.length);
    }
  }

  Future<void> _loadPresetLibrary() async {
    final loaded = await _presetStore.load();
    if (!mounted) return;
    setState(() {
      _library.uiCustom
        ..clear()
        ..addAll(loaded.uiCustom);
      _library.terminalCustom
        ..clear()
        ..addAll(loaded.terminalCustom);
      _library.hiddenUiIds
        ..clear()
        ..addAll(loaded.hiddenUiIds);
      _library.hiddenTerminalIds
        ..clear()
        ..addAll(loaded.hiddenTerminalIds);
      // A stored settings file can match a custom preset; only now is the
      // library available to name it.
      _uiPresetId ??= _matchUiPreset(uiSettings);
      _terminalPresetId ??= _matchTerminalPreset(termSettings);
    });
  }

  Future<void> _persistPresetLibrary() async {
    try {
      await _presetStore.save(_library);
    } catch (_) {
      // Presets are a convenience; a read-only config directory must not break
      // theme editing.
    }
  }

  String? _matchUiPreset(UiThemeSettings settings) {
    for (final preset in builtInUiPresets()) {
      if (preset.ui != null && _sameUi(preset.ui!, settings)) return preset.id;
    }
    for (final preset in _library.uiCustom) {
      if (preset.ui != null && _sameUi(preset.ui!, settings)) return preset.id;
    }
    return null;
  }

  String? _matchTerminalPreset(TerminalThemeSettings settings) {
    for (final preset in builtInTerminalPresets()) {
      if (preset.terminal != null &&
          _sameTerminal(preset.terminal!, settings)) {
        return preset.id;
      }
    }
    for (final preset in _library.terminalCustom) {
      if (preset.terminal != null &&
          _sameTerminal(preset.terminal!, settings)) {
        return preset.id;
      }
    }
    return null;
  }

  bool _sameUi(UiThemeSettings a, UiThemeSettings b) =>
      a.fontFamily == b.fontFamily &&
      a.fontSize == b.fontSize &&
      a.normalFontWeight == b.normalFontWeight &&
      a.boldFontWeight == b.boldFontWeight &&
      a.background == b.background &&
      a.panel == b.panel &&
      a.sidebar == b.sidebar &&
      a.accent == b.accent &&
      a.textPrimary == b.textPrimary &&
      a.textMuted == b.textMuted;

  bool _sameTerminal(TerminalThemeSettings a, TerminalThemeSettings b) =>
      a.fontFamily == b.fontFamily &&
      a.fontSize == b.fontSize &&
      a.normalFontWeight == b.normalFontWeight &&
      a.boldFontWeight == b.boldFontWeight &&
      a.cursorStyle == b.cursorStyle &&
      a.cursorBlink == b.cursorBlink &&
      a.foreground == b.foreground &&
      a.terminalBackground == b.terminalBackground &&
      a.selectionColor == b.selectionColor &&
      a.cursorColor == b.cursorColor &&
      a.scrollbackLines == b.scrollbackLines &&
      _sameRules(a.regexHighlights, b.regexHighlights);

  bool _sameRules(List<RegexHighlight> a, List<RegexHighlight> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].pattern != b[i].pattern ||
          a[i].color != b[i].color ||
          a[i].note != b[i].note) {
        return false;
      }
    }
    return true;
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        width: 280,
        duration: const Duration(milliseconds: 1800),
      ),
    );
  }

  void _updateUi(UiThemeSettings settings) {
    setState(() => uiSettings = settings);
  }

  void _updateTerm(TerminalThemeSettings settings) {
    setState(() {
      termSettings = settings;
      _syncRegexRuleKeys(settings.regexHighlights.length);
    });
  }

  void _save() {
    widget.onUiSettingsChanged(uiSettings);
    widget.onTerminalSettingsChanged(termSettings);
    _showMessage('已保存主题');
  }

  void _reset() {
    setState(() {
      uiSettings = UiThemeSettings.commandDeck();
      termSettings = TerminalThemeSettings.commandDeck();
      _uiPresetId = 'deck';
      _terminalPresetId = 'deck';
    });
    _showMessage('已恢复默认主题');
  }

  void _applyUiPreset(String id) {
    final preset = _library.uiPreset(id);
    final settings = preset?.ui;
    if (settings == null) return;
    setState(() {
      _uiPresetId = id;
      uiSettings = settings;
    });
    _showMessage('界面主题已切换为 ${preset!.name}');
  }

  void _applyTerminalPreset(String id) {
    final preset = _library.terminalPreset(id);
    final settings = preset?.terminal;
    if (settings == null) return;
    setState(() {
      _terminalPresetId = id;
      termSettings = settings;
      _syncRegexRuleKeys(settings.regexHighlights.length);
    });
    _showMessage(
      '终端主题已切换为 ${preset!.name}，高亮规则共 ${settings.regexHighlights.length} 条',
    );
  }

  void _createPreset({required bool terminal}) {
    final now = DateTime.now().microsecondsSinceEpoch;
    if (terminal) {
      final preset = ThemePreset(
        id: 'term-c$now',
        name: '自定义方案 ${_library.terminalCustom.length + 1}',
        swatch: termSettings.terminalBackground,
        terminal: termSettings,
        custom: true,
      );
      setState(() {
        _library.terminalCustom.add(preset);
        _terminalPresetId = preset.id;
      });
      _showMessage('已把当前设置存为「${preset.name}」');
    } else {
      final preset = ThemePreset(
        id: 'ui-c$now',
        name: '自定义方案 ${_library.uiCustom.length + 1}',
        swatch: uiSettings.background,
        ui: uiSettings,
        custom: true,
      );
      setState(() {
        _library.uiCustom.add(preset);
        _uiPresetId = preset.id;
      });
      _showMessage('已把当前设置存为「${preset.name}」');
    }
    unawaited(_persistPresetLibrary());
  }

  void _deletePreset(String id, {required bool terminal}) {
    if (terminal) {
      final preset = _library.terminalPreset(id);
      if (preset == null) return;
      final customIndex = _library.terminalCustom.indexWhere((p) => p.id == id);
      if (customIndex >= 0) {
        _library.terminalCustom.removeAt(customIndex);
      } else {
        _library.hiddenTerminalIds.add(id);
      }
      setState(() {});
      if (_terminalPresetId == id) {
        final rest = _library.terminalPresets;
        if (rest.isEmpty) {
          _terminalPresetId = null;
        } else {
          _applyTerminalPreset(rest.first.id);
        }
      }
      _showMessage(
        '已删除方案「${preset.name}」${preset.custom ? '' : '，可从「恢复内置方案」取回'}',
      );
    } else {
      final preset = _library.uiPreset(id);
      if (preset == null) return;
      final customIndex = _library.uiCustom.indexWhere((p) => p.id == id);
      if (customIndex >= 0) {
        _library.uiCustom.removeAt(customIndex);
      } else {
        _library.hiddenUiIds.add(id);
      }
      setState(() {});
      if (_uiPresetId == id) {
        final rest = _library.uiPresets;
        if (rest.isEmpty) {
          _uiPresetId = null;
        } else {
          _applyUiPreset(rest.first.id);
        }
      }
      _showMessage(
        '已删除方案「${preset.name}」${preset.custom ? '' : '，可从「恢复内置方案」取回'}',
      );
    }
    unawaited(_persistPresetLibrary());
  }

  void _restoreBuiltIns({required bool terminal}) {
    final hidden = terminal ? _library.hiddenTerminalIds : _library.hiddenUiIds;
    if (hidden.isEmpty) return;
    final count = hidden.length;
    setState(hidden.clear);
    _showMessage('已恢复 $count 个内置方案');
    unawaited(_persistPresetLibrary());
  }

  String _copyName(String name) {
    final base = name.replaceAll(RegExp(r'( 副本)+$'), '');
    final count = RegExp(' 副本').allMatches(name).length;
    return '$base${' 副本' * (count + 1)}';
  }

  void _copyPreset(String id, {required bool terminal}) {
    if (terminal) {
      final source = _library.terminalPreset(id);
      final settings = source?.terminal;
      if (source == null || settings == null) return;
      final copy = ThemePreset(
        id: 'term-c${DateTime.now().microsecondsSinceEpoch}',
        name: _copyName(source.name),
        swatch: source.swatch,
        terminal: settings,
        custom: true,
      );
      setState(() {
        final index = _library.terminalCustom.indexWhere((p) => p.id == id);
        if (index >= 0) {
          _library.terminalCustom.insert(index + 1, copy);
        } else {
          _library.terminalCustom.insert(0, copy);
        }
        _terminalPresetId = copy.id;
      });
      _showMessage('已复制方案「${source.name}」');
    } else {
      final source = _library.uiPreset(id);
      final settings = source?.ui;
      if (source == null || settings == null) return;
      final copy = ThemePreset(
        id: 'ui-c${DateTime.now().microsecondsSinceEpoch}',
        name: _copyName(source.name),
        swatch: source.swatch,
        ui: settings,
        custom: true,
      );
      setState(() {
        final index = _library.uiCustom.indexWhere((p) => p.id == id);
        if (index >= 0) {
          _library.uiCustom.insert(index + 1, copy);
        } else {
          _library.uiCustom.insert(0, copy);
        }
        _uiPresetId = copy.id;
      });
      _showMessage('已复制方案「${source.name}」');
    }
    unawaited(_persistPresetLibrary());
  }

  ThemePreset? get _currentUiPreset =>
      _uiPresetId == null ? null : _library.uiPreset(_uiPresetId!);

  ThemePreset? get _currentTerminalPreset => _terminalPresetId == null
      ? null
      : _library.terminalPreset(_terminalPresetId!);

  @override
  Widget build(BuildContext context) {
    return DeckPageScaffold(
      eyebrow: 'Appearance',
      title: '主题配置',
      subtitle: '分别设置界面外观与终端渲染，并配置基于正则的输出高亮规则。',
      actions: [
        DeckButton(
          key: const ValueKey('theme-reset'),
          label: '恢复默认',
          style: DeckButtonStyle.outline,
          onPressed: _reset,
        ),
        DeckButton(
          key: const ValueKey('theme-save'),
          label: '保存主题',
          style: DeckButtonStyle.accent,
          onPressed: _save,
        ),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final uiPanel = _ThemePanel(
            title: '界面主题',
            icon: Icons.palette_outlined,
            child: _buildUiSection(),
          );
          final terminalPanel = _ThemePanel(
            title: '终端主题',
            icon: Icons.terminal,
            child: _buildTerminalSection(),
          );
          return SingleChildScrollView(
            child: constraints.maxWidth < 980
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      uiPanel,
                      const SizedBox(height: 16),
                      terminalPanel,
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: uiPanel),
                      const SizedBox(width: 16),
                      Expanded(child: terminalPanel),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _buildUiSection() {
    final knownFamilies = {for (final option in _uiFontOptions) option.family};
    final families = [
      for (final option in _uiFontOptions) option.family,
      if (uiSettings.fontFamily.isNotEmpty &&
          !knownFamilies.contains(uiSettings.fontFamily))
        uiSettings.fontFamily,
    ];
    final sizes = {
      13,
      14,
      15,
      if (uiSettings.fontSize != 13 &&
          uiSettings.fontSize != 14 &&
          uiSettings.fontSize != 15)
        uiSettings.fontSize,
    }.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PresetDropdown(
          kind: _PresetKind.ui,
          entries: _library.uiPresets,
          selectedId: _uiPresetId,
          currentName:
              _currentUiPreset?.name ??
              (uiSettings.presetName.isEmpty ? '自定义方案' : uiSettings.presetName),
          custom: _currentUiPreset?.custom ?? _currentUiPreset == null,
          onPick: _applyUiPreset,
          onCreate: () => _createPreset(terminal: false),
          onDelete: (id) => _deletePreset(id, terminal: false),
          onCopy: (id) => _copyPreset(id, terminal: false),
          onRestore: () => _restoreBuiltIns(terminal: false),
          hiddenCount: _library.hiddenUiIds.length,
        ),
        const SizedBox(height: 16),
        const _SectionLabel('字体'),
        const SizedBox(height: 9),
        DeckFieldRow(
          children: [
            DeckSelect<String>(
              key: const ValueKey('ui-font-select'),
              label: '界面字体',
              value: uiSettings.fontFamily,
              items: families,
              itemBuilder: (context, family) => Text(_uiFontLabel(family)),
              onChanged: (family) {
                if (family == null) return;
                _updateUi(uiSettings.copyWith(fontFamily: family));
              },
            ),
            DeckSelect<int>(
              key: const ValueKey('ui-size-select'),
              label: '基准字号',
              value: uiSettings.fontSize,
              items: sizes,
              itemBuilder: (context, size) => Text('$size px'),
              onChanged: (size) {
                if (size == null) return;
                _updateUi(uiSettings.copyWith(fontSize: size));
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _SectionLabel('配色'),
        const SizedBox(height: 9),
        _SwatchGrid(
          columns: 3,
          children: [
            _SwatchCard(
              key: const ValueKey('swatch-ui-background'),
              label: '背景',
              value: uiSettings.background,
              onChanged: (c) => _updateUi(uiSettings.copyWith(background: c)),
            ),
            _SwatchCard(
              key: const ValueKey('swatch-ui-panel'),
              label: '面板',
              value: uiSettings.panel,
              onChanged: (c) => _updateUi(uiSettings.copyWith(panel: c)),
            ),
            _SwatchCard(
              key: const ValueKey('swatch-ui-sidebar'),
              label: '侧栏',
              value: uiSettings.sidebar,
              onChanged: (c) => _updateUi(uiSettings.copyWith(sidebar: c)),
            ),
            _SwatchCard(
              key: const ValueKey('swatch-ui-accent'),
              label: '强调',
              value: uiSettings.accent,
              onChanged: (c) => _updateUi(uiSettings.copyWith(accent: c)),
            ),
            _SwatchCard(
              key: const ValueKey('swatch-ui-text-primary'),
              label: '主文本',
              value: uiSettings.textPrimary,
              onChanged: (c) => _updateUi(uiSettings.copyWith(textPrimary: c)),
            ),
            _SwatchCard(
              key: const ValueKey('swatch-ui-text-muted'),
              label: '次要文本',
              value: uiSettings.textMuted,
              onChanged: (c) => _updateUi(uiSettings.copyWith(textMuted: c)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTerminalSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PresetDropdown(
          kind: _PresetKind.terminal,
          entries: _library.terminalPresets,
          selectedId: _terminalPresetId,
          currentName:
              _currentTerminalPreset?.name ??
              (termSettings.presetName.isEmpty
                  ? '自定义方案'
                  : termSettings.presetName),
          custom:
              _currentTerminalPreset?.custom ?? _currentTerminalPreset == null,
          onPick: _applyTerminalPreset,
          onCreate: () => _createPreset(terminal: true),
          onDelete: (id) => _deletePreset(id, terminal: true),
          onCopy: (id) => _copyPreset(id, terminal: true),
          onRestore: () => _restoreBuiltIns(terminal: true),
          hiddenCount: _library.hiddenTerminalIds.length,
        ),
        const SizedBox(height: 16),
        const _SectionLabel('实时预览'),
        const SizedBox(height: 9),
        _MiniTerminalPreview(settings: termSettings),
        const SizedBox(height: 16),
        const _SectionLabel('光标'),
        const SizedBox(height: 9),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: DeckSelect<CursorStyle>(
                key: const ValueKey('cursor-style-select'),
                label: '样式',
                value: termSettings.cursorStyle,
                items: CursorStyle.values,
                itemBuilder: (context, style) => Text(_cursorStyleLabel(style)),
                onChanged: (style) {
                  if (style == null) return;
                  _updateTerm(termSettings.copyWith(cursorStyle: style));
                },
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: _DeckCheckbox(
                label: '光标闪烁',
                value: termSettings.cursorBlink,
                onChanged: (value) =>
                    _updateTerm(termSettings.copyWith(cursorBlink: value)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _SectionLabel('终端配色'),
        const SizedBox(height: 9),
        _SwatchGrid(
          columns: 2,
          children: [
            _SwatchCard(
              key: const ValueKey('swatch-term-foreground'),
              label: '前景',
              value: termSettings.foreground,
              onChanged: (c) =>
                  _updateTerm(termSettings.copyWith(foreground: c)),
            ),
            _SwatchCard(
              key: const ValueKey('swatch-term-background'),
              label: '背景',
              value: termSettings.terminalBackground,
              onChanged: (c) =>
                  _updateTerm(termSettings.copyWith(terminalBackground: c)),
            ),
            _SwatchCard(
              key: const ValueKey('swatch-term-selection'),
              label: '高亮',
              value: termSettings.selectionColor,
              onChanged: (c) =>
                  _updateTerm(termSettings.copyWith(selectionColor: c)),
            ),
            _SwatchCard(
              key: const ValueKey('swatch-term-cursor'),
              label: '光标',
              value: termSettings.cursorColor,
              onChanged: (c) =>
                  _updateTerm(termSettings.copyWith(cursorColor: c)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _SectionLabel('正则高亮'),
        const SizedBox(height: 8),
        if (termSettings.regexHighlights.isEmpty)
          const _RegexEmptyState()
        else
          SizedBox(
            // 40px per row, plus the inline error line on whichever rules are
            // currently broken.
            height:
                termSettings.regexHighlights.length * 40 +
                (termSettings.regexHighlights
                        .where(
                          (rule) =>
                              RegexHighlight.patternError(rule.pattern) != null,
                        )
                        .length *
                    18),
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: termSettings.regexHighlights.length,
              onReorder: (oldIndex, newIndex) {
                final highlights = List<RegexHighlight>.from(
                  termSettings.regexHighlights,
                );
                if (oldIndex < newIndex) newIndex -= 1;
                final item = highlights.removeAt(oldIndex);
                final key = _regexRuleKeys.removeAt(oldIndex);
                highlights.insert(newIndex, item);
                _regexRuleKeys.insert(newIndex, key);
                _updateTerm(termSettings.copyWith(regexHighlights: highlights));
              },
              itemBuilder: (context, index) {
                final highlight = termSettings.regexHighlights[index];
                return _RegexRuleRow(
                  key: _regexRuleKeys[index],
                  index: index,
                  pattern: highlight.pattern,
                  note: highlight.note,
                  color: highlight.color,
                  patternError: RegexHighlight.patternError(highlight.pattern),
                  onPatternChanged: (v) {
                    final highlights = List<RegexHighlight>.from(
                      termSettings.regexHighlights,
                    );
                    highlights[index] = highlight.copyWith(pattern: v);
                    _updateTerm(
                      termSettings.copyWith(regexHighlights: highlights),
                    );
                  },
                  onNoteChanged: (v) {
                    final highlights = List<RegexHighlight>.from(
                      termSettings.regexHighlights,
                    );
                    highlights[index] = highlight.copyWith(note: v);
                    _updateTerm(
                      termSettings.copyWith(regexHighlights: highlights),
                    );
                  },
                  onColorChanged: (c) {
                    final highlights = List<RegexHighlight>.from(
                      termSettings.regexHighlights,
                    );
                    highlights[index] = highlight.copyWith(color: c);
                    _updateTerm(
                      termSettings.copyWith(regexHighlights: highlights),
                    );
                  },
                  onRemove: () {
                    final highlights = List<RegexHighlight>.from(
                      termSettings.regexHighlights,
                    )..removeAt(index);
                    _regexRuleKeys.removeAt(index);
                    _updateTerm(
                      termSettings.copyWith(regexHighlights: highlights),
                    );
                  },
                );
              },
            ),
          ),
        const SizedBox(height: 6),
        TextButton.icon(
          key: const ValueKey('regex-add'),
          onPressed: () {
            _regexRuleKeys.add(UniqueKey());
            _updateTerm(
              termSettings.copyWith(
                regexHighlights: [
                  ...termSettings.regexHighlights,
                  const RegexHighlight(
                    pattern: '',
                    color: Color(0xFFFFFFFF),
                    note: '',
                  ),
                ],
              ),
            );
          },
          icon: const Icon(Icons.add, size: 16),
          label: const Text('添加规则'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textMuted,
            shape: const RoundedRectangleBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 220,
          child: _ScrollbackField(
            value: termSettings.scrollbackLines,
            onChanged: (lines) =>
                _updateTerm(termSettings.copyWith(scrollbackLines: lines)),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class _ScrollbackField extends StatefulWidget {
  const _ScrollbackField({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<_ScrollbackField> createState() => _ScrollbackFieldState();
}

class _ScrollbackFieldState extends State<_ScrollbackField> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.value}',
  );

  @override
  void didUpdateWidget(covariant _ScrollbackField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = '${widget.value}';
    if (_controller.text != next) _controller.text = next;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DeckTextField(
      key: const ValueKey('scrollback-input'),
      label: '回滚缓冲行数',
      controller: _controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (value) {
        final lines = int.tryParse(value);
        if (lines != null) widget.onChanged(lines);
      },
    );
  }
}

const _uiFontOptions = <({String label, String family})>[
  (label: '系统默认（含中文）', family: ''),
  (label: '苹方 / PingFang SC', family: 'PingFang SC'),
  (label: '思源黑体 / Noto Sans CJK', family: 'Noto Sans CJK SC'),
];

String _uiFontLabel(String family) {
  for (final option in _uiFontOptions) {
    if (option.family == family) return option.label;
  }
  return family;
}

String _cursorStyleLabel(CursorStyle style) => switch (style) {
  CursorStyle.block => '方块',
  CursorStyle.underline => '下划线',
  CursorStyle.bar => '竖线',
};

enum _PresetKind { ui, terminal }

class _ThemePanel extends StatelessWidget {
  const _ThemePanel({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DeckPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.accentInk),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontFamilyFallback: DeckTokens.fontDisplay,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: DeckLabel(text, size: 10),
    );
  }
}

class _SwatchGrid extends StatelessWidget {
  const _SwatchGrid({required this.columns, required this.children});

  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class _SwatchCard extends StatelessWidget {
  const _SwatchCard({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final Color value;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => showColorPickerDialog(
          context,
          initialColor: value,
          onChanged: onChanged,
        ),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 24,
                decoration: BoxDecoration(
                  color: value,
                  border: Border.all(color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontFamilyFallback: DeckTokens.fontMono,
                  fontSize: 10,
                  letterSpacing: 0.5,
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                css.colorToHex(value),
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontFamilyFallback: DeckTokens.fontMono,
                  fontSize: 11,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniTerminalPreview extends StatelessWidget {
  const _MiniTerminalPreview({required this.settings});

  final TerminalThemeSettings settings;

  @override
  Widget build(BuildContext context) {
    final mono = settings.fontFamily.isEmpty ? null : settings.fontFamily;
    TextStyle style(Color color) => TextStyle(
      fontFamily: mono,
      fontFamilyFallback: DeckTokens.fontMono,
      fontSize: 11.5,
      height: 1.55,
      color: color,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: settings.terminalBackground,
        border: Border.all(color: AppColors.textPrimary),
      ),
      child: RichText(
        text: TextSpan(
          style: style(settings.foreground),
          children: [
            TextSpan(text: r'$ ', style: style(settings.foreground)),
            TextSpan(
              text: 'deploy@prod-web-01',
              style: style(DeckTokens.termGreen),
            ),
            TextSpan(text: ':', style: style(settings.foreground)),
            TextSpan(text: '~', style: style(DeckTokens.termBlue)),
            TextSpan(
              text: r'$ tail -f app.log',
              style: style(settings.foreground),
            ),
            TextSpan(text: '\n', style: style(settings.foreground)),
            TextSpan(text: 'INFO', style: style(DeckTokens.termCyan)),
            TextSpan(
              text: '  server listening on :8080',
              style: style(settings.foreground),
            ),
            TextSpan(text: '\n', style: style(settings.foreground)),
            TextSpan(text: 'WARN', style: style(DeckTokens.termAmber)),
            TextSpan(
              text: '  cache miss for key ',
              style: style(settings.foreground),
            ),
            TextSpan(text: 'user:184213', style: style(DeckTokens.termBlue)),
            TextSpan(text: '\n', style: style(settings.foreground)),
            TextSpan(text: 'ERROR', style: style(DeckTokens.termRed)),
            TextSpan(
              text: ' upstream timeout after 3.0s',
              style: style(settings.foreground),
            ),
            TextSpan(text: '  ', style: style(settings.foreground)),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Container(
                width: 7,
                height: 13,
                color: settings.cursorColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeckCheckbox extends StatelessWidget {
  const _DeckCheckbox({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: value ? AppColors.accent : Colors.transparent,
                border: Border.all(
                  color: value ? AppColors.accent : AppColors.textPrimary,
                ),
              ),
              child: value
                  ? Icon(Icons.check, size: 11, color: AppColors.panel)
                  : null,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegexEmptyState extends StatelessWidget {
  const _RegexEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '当前预设没有高亮规则',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '添加规则后按从上到下的顺序逐条匹配，先命中者着色。',
            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _RegexRuleRow extends StatelessWidget {
  const _RegexRuleRow({
    super.key,
    required this.index,
    required this.pattern,
    required this.note,
    required this.color,
    required this.onPatternChanged,
    required this.onNoteChanged,
    required this.onColorChanged,
    required this.onRemove,
    required this.patternError,
  });

  final int index;
  final String pattern;
  final String note;
  final Color color;

  /// Non-null when [pattern] is not a valid regular expression. The rule keeps
  /// its slot in the list so the user can fix it instead of losing it.
  final String? patternError;
  final ValueChanged<String> onPatternChanged;
  final ValueChanged<String> onNoteChanged;
  final ValueChanged<Color> onColorChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exact prototype `.rx`: 40px row, 18px grip, pattern ≤280,
          // note ≤150, auto colour cell, 32px delete, 8px gaps.
          SizedBox(
            height: 32,
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 32,
                  child: Center(
                    child: ReorderableDragStartListener(
                      index: index,
                      child: Tooltip(
                        message: '拖动调整优先级',
                        child: Icon(
                          Icons.drag_indicator,
                          size: 15,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  flex: 280,
                  child: _RuleInput(
                    key: ValueKey('regex-pattern-$index'),
                    value: pattern,
                    hint: '正则表达式',
                    mono: true,
                    isError: patternError != null,
                    onChanged: onPatternChanged,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  flex: 150,
                  child: _RuleInput(
                    key: ValueKey('regex-note-$index'),
                    value: note,
                    hint: '备注',
                    onChanged: onNoteChanged,
                  ),
                ),
                const SizedBox(width: 8),
                _RuleColorButton(value: color, onChanged: onColorChanged),
                const SizedBox(width: 8),
                Tooltip(
                  message: '移除正则规则',
                  child: _RuleDeleteButton(onPressed: onRemove),
                ),
              ],
            ),
          ),
          if (patternError != null) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 12,
                    color: DeckTokens.danger,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '正则无效：$patternError',
                      style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontFamilyFallback: DeckTokens.fontMono,
                        fontSize: 10.5,
                        color: DeckTokens.danger,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RuleInput extends StatefulWidget {
  const _RuleInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint,
    this.mono = false,
    this.isError = false,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String? hint;
  final bool mono;
  final bool isError;

  @override
  State<_RuleInput> createState() => _RuleInputState();
}

class _RuleInputState extends State<_RuleInput> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChanged);
  }

  void _handleFocusChanged() {
    if (mounted) setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  void didUpdateWidget(covariant _RuleInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.isError
        ? DeckTokens.danger
        : (_focused ? AppColors.accent : AppColors.border);
    return Container(
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _focused ? AppColors.panel : AppColors.background,
        border: Border.all(color: borderColor),
      ),
      child: TextField(
        focusNode: _focusNode,
        controller: _controller,
        onChanged: widget.onChanged,
        textAlignVertical: TextAlignVertical.center,
        style: widget.mono
            ? TextStyle(
                fontFamily: 'JetBrains Mono',
                fontFamilyFallback: DeckTokens.fontMono,
                fontSize: 11.5,
                color: AppColors.textPrimary,
              )
            : TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
        decoration: InputDecoration(
          isDense: true,
          isCollapsed: true,
          border: InputBorder.none,
          hintText: widget.hint,
          hintStyle: widget.mono
              ? TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontFamilyFallback: DeckTokens.fontMono,
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                )
              : TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
    );
  }
}

class _RuleColorButton extends StatelessWidget {
  const _RuleColorButton({required this.value, required this.onChanged});

  final Color value;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => showColorPickerDialog(
          context,
          initialColor: value,
          onChanged: onChanged,
        ),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: value,
                  border: Border.all(color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                css.colorToHex(value),
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontFamilyFallback: DeckTokens.fontMono,
                  fontSize: 11,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.keyboard_arrow_down,
                size: 11,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleDeleteButton extends StatefulWidget {
  const _RuleDeleteButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_RuleDeleteButton> createState() => _RuleDeleteButtonState();
}

class _RuleDeleteButtonState extends State<_RuleDeleteButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Container(
            decoration: BoxDecoration(
              color: _hovered ? AppColors.background : Colors.transparent,
              border: Border.all(
                color: _hovered ? AppColors.border : Colors.transparent,
              ),
            ),
            child: Icon(
              Icons.close,
              size: 13,
              color: _hovered ? DeckTokens.danger : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _PresetDropdown extends StatefulWidget {
  const _PresetDropdown({
    required this.kind,
    required this.entries,
    required this.selectedId,
    required this.currentName,
    required this.custom,
    required this.onPick,
    required this.onCreate,
    required this.onDelete,
    required this.onCopy,
    required this.onRestore,
    required this.hiddenCount,
  });

  final _PresetKind kind;
  final List<ThemePreset> entries;
  final String? selectedId;
  final String currentName;
  final bool custom;
  final ValueChanged<String> onPick;
  final VoidCallback onCreate;
  final ValueChanged<String> onDelete;
  final ValueChanged<String> onCopy;
  final VoidCallback onRestore;
  final int hiddenCount;

  @override
  State<_PresetDropdown> createState() => _PresetDropdownState();
}

class _PresetDropdownState extends State<_PresetDropdown> {
  final OverlayPortalController _overlay = OverlayPortalController();
  final LayerLink _link = LayerLink();
  double _width = 320;
  bool _open = false;

  void _toggle() {
    setState(() {
      _open = !_open;
      if (_open) {
        _overlay.show();
      } else {
        _overlay.hide();
      }
    });
  }

  void _close() {
    if (!_open) return;
    setState(() {
      _open = false;
      _overlay.hide();
    });
  }

  @override
  Widget build(BuildContext context) {
    final trigger = Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(
          color: _open ? AppColors.textPrimary : AppColors.border,
        ),
        boxShadow: _open ? AppColors.shadowHard : null,
      ),
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: _selectedSwatch,
              border: Border.all(color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              widget.currentName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
            ),
          ),
          if (widget.custom) ...[
            const SizedBox(width: 6),
            Text(
              '自定义',
              style: TextStyle(fontSize: 10.5, color: AppColors.textMuted),
            ),
          ],
          const SizedBox(width: 6),
          Icon(
            Icons.keyboard_arrow_down,
            size: 14,
            color: _open ? AppColors.textPrimary : AppColors.textMuted,
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('预设方案'),
        const SizedBox(height: 9),
        TapRegion(
          groupId: this,
          onTapOutside: (_) => _close(),
          child: CompositedTransformTarget(
            link: _link,
            child: OverlayPortal(
              controller: _overlay,
              overlayChildBuilder: (context) => CompositedTransformFollower(
                link: _link,
                showWhenUnlinked: false,
                targetAnchor: Alignment.bottomLeft,
                followerAnchor: Alignment.topLeft,
                offset: const Offset(0, 4),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: TapRegion(
                    groupId: this,
                    child: SizedBox(width: _width, child: _menu(context)),
                  ),
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _width = constraints.maxWidth;
                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      key: ValueKey(
                        widget.kind == _PresetKind.ui
                            ? 'preset-trigger-ui'
                            : 'preset-trigger-terminal',
                      ),
                      onTap: _toggle,
                      child: trigger,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color get _selectedSwatch {
    for (final preset in widget.entries) {
      if (preset.id == widget.selectedId) return preset.swatch;
    }
    return widget.kind == _PresetKind.ui
        ? AppColors.background
        : DeckTokens.termBg;
  }

  Widget _menu(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.textPrimary),
        boxShadow: AppColors.shadowSolid,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.entries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '暂无方案，可从下方新建。',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            )
          else
            for (final preset in widget.entries)
              _PresetRow(
                preset: preset,
                selected: preset.id == widget.selectedId,
                onPick: () {
                  widget.onPick(preset.id);
                  _close();
                },
                onDelete: () => widget.onDelete(preset.id),
                onCopy: () => widget.onCopy(preset.id),
              ),
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MenuAction(
                  icon: Icons.add,
                  label: '新建自定义方案',
                  onTap: widget.onCreate,
                ),
                if (widget.hiddenCount > 0)
                  _MenuAction(
                    icon: Icons.restore,
                    label: '恢复内置方案（${widget.hiddenCount}）',
                    onTap: widget.onRestore,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetRow extends StatefulWidget {
  const _PresetRow({
    required this.preset,
    required this.selected,
    required this.onPick,
    required this.onDelete,
    required this.onCopy,
  });

  final ThemePreset preset;
  final bool selected;
  final VoidCallback onPick;
  final VoidCallback onDelete;
  final VoidCallback onCopy;

  @override
  State<_PresetRow> createState() => _PresetRowState();
}

class _PresetRowState extends State<_PresetRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              onTap: widget.onPick,
              onSecondaryTap: widget.onCopy,
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: widget.selected || _hovered
                      ? AppColors.background
                      : Colors.transparent,
                  border: Border(
                    left: BorderSide(
                      color: widget.selected
                          ? AppColors.accent
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: widget.preset.swatch,
                        border: Border.all(color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        widget.preset.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (widget.preset.custom)
                      Text(
                        '自定义',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Tooltip(
          message: widget.preset.custom ? '删除此自定义方案' : '从列表中移除此内置方案',
          child: IconButton(
            onPressed: widget.onDelete,
            icon: const Icon(Icons.close, size: 13),
            color: AppColors.textMuted,
            hoverColor: AppColors.fgSoft,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
          ),
        ),
      ],
    );
  }
}

class _MenuAction extends StatefulWidget {
  const _MenuAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_MenuAction> createState() => _MenuActionState();
}

class _MenuActionState extends State<_MenuAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: _hovered ? AppColors.accent : Colors.transparent,
            ),
            color: _hovered ? AppColors.accentSoft : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 14,
                color: _hovered ? AppColors.accentInk : AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  color: _hovered ? AppColors.accentInk : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
