import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/theme_settings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/color_picker_field.dart';

class ThemeConfigPage extends StatefulWidget {
  const ThemeConfigPage({
    super.key,
    required this.uiSettings,
    required this.terminalSettings,
    required this.onUiSettingsChanged,
    required this.onTerminalSettingsChanged,
    required this.onBack,
  });

  final UiThemeSettings uiSettings;
  final TerminalThemeSettings terminalSettings;
  final ValueChanged<UiThemeSettings> onUiSettingsChanged;
  final ValueChanged<TerminalThemeSettings> onTerminalSettingsChanged;
  final VoidCallback onBack;

  @override
  State<ThemeConfigPage> createState() => _ThemeConfigPageState();
}

class _ThemeConfigPageState extends State<ThemeConfigPage> {
  late UiThemeSettings uiSettings;
  late TerminalThemeSettings termSettings;
  final _regexRuleKeys = <Key>[];

  @override
  void initState() {
    super.initState();
    uiSettings = widget.uiSettings;
    termSettings = widget.terminalSettings;
    _syncRegexRuleKeys(termSettings.regexHighlights.length);
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

  void _updateUi(UiThemeSettings settings) {
    setState(() => uiSettings = settings);
    widget.onUiSettingsChanged(settings);
  }

  void _updateTerm(TerminalThemeSettings settings) {
    setState(() => termSettings = settings);
    widget.onTerminalSettingsChanged(settings);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '主题配置',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionCard(title: '界面主题', child: _buildUiSection()),
                  const SizedBox(height: 20),
                  _SectionCard(title: '终端主题', child: _buildTerminalSection()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUiSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PresetSelector(
          options: const ['Command Deck', 'VS Code Dark'],
          selected: uiSettings.presetName,
          onSelect: (name) {
            final preset = name == 'VS Code Dark'
                ? UiThemeSettings.vsCodeDark()
                : UiThemeSettings.commandDeck();
            _updateUi(preset);
          },
        ),
        const SizedBox(height: 16),
        _FontRow(
          family: uiSettings.fontFamily,
          size: uiSettings.fontSize,
          onFamilyChanged: (v) => _updateUi(uiSettings.copyWith(fontFamily: v)),
          onSizeChanged: (v) => _updateUi(uiSettings.copyWith(fontSize: v)),
        ),
        const SizedBox(height: 16),
        const _SectionLabel('配色'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _ColorField(
              label: '背景',
              value: uiSettings.background,
              onChanged: (c) => _updateUi(uiSettings.copyWith(background: c)),
            ),
            _ColorField(
              label: '面板',
              value: uiSettings.panel,
              onChanged: (c) => _updateUi(uiSettings.copyWith(panel: c)),
            ),
            _ColorField(
              label: '侧栏',
              value: uiSettings.sidebar,
              onChanged: (c) => _updateUi(uiSettings.copyWith(sidebar: c)),
            ),
            _ColorField(
              label: '强调',
              value: uiSettings.accent,
              onChanged: (c) => _updateUi(uiSettings.copyWith(accent: c)),
            ),
            _ColorField(
              label: '文字',
              value: uiSettings.textPrimary,
              onChanged: (c) => _updateUi(uiSettings.copyWith(textPrimary: c)),
            ),
            _ColorField(
              label: '次要文字',
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
        _PresetSelector(
          options: const ['Command Deck', 'One Dark', 'Solarized'],
          selected: termSettings.presetName,
          onSelect: (name) {
            final preset = switch (name) {
              'One Dark' => TerminalThemeSettings.oneDark(),
              'Solarized' => TerminalThemeSettings.solarized(),
              _ => TerminalThemeSettings.commandDeck(),
            };
            _updateTerm(preset);
          },
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _FontRow(
                family: termSettings.fontFamily,
                size: termSettings.fontSize,
                onFamilyChanged: (v) =>
                    _updateTerm(termSettings.copyWith(fontFamily: v)),
                onSizeChanged: (v) =>
                    _updateTerm(termSettings.copyWith(fontSize: v)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _CursorRow(
                style: termSettings.cursorStyle,
                blink: termSettings.cursorBlink,
                onStyleChanged: (v) =>
                    _updateTerm(termSettings.copyWith(cursorStyle: v)),
                onBlinkChanged: (v) =>
                    _updateTerm(termSettings.copyWith(cursorBlink: v)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _SectionLabel('配色'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _ColorField(
              label: '前景色',
              value: termSettings.foreground,
              onChanged: (c) =>
                  _updateTerm(termSettings.copyWith(foreground: c)),
            ),
            _ColorField(
              label: '背景色',
              value: termSettings.terminalBackground,
              onChanged: (c) =>
                  _updateTerm(termSettings.copyWith(terminalBackground: c)),
            ),
            _ColorField(
              label: '高亮色',
              value: termSettings.selectionColor,
              onChanged: (c) =>
                  _updateTerm(termSettings.copyWith(selectionColor: c)),
            ),
            _ColorField(
              label: '光标色',
              value: termSettings.cursorColor,
              onChanged: (c) =>
                  _updateTerm(termSettings.copyWith(cursorColor: c)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const _SectionLabel('正则高亮'),
        const SizedBox(height: 8),
        SizedBox(
          height: termSettings.regexHighlights.length * 40,
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
        const SizedBox(height: 8),
        TextButton.icon(
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
          style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
        ),
        const SizedBox(height: 16),
        const _SectionLabel('其他'),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 160,
              child: _NumberInput(
                label: 'Scrollback lines',
                value: termSettings.scrollbackLines,
                onChanged: (v) =>
                    _updateTerm(termSettings.copyWith(scrollbackLines: v)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0F0F),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFD6C7B8),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
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
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFFD6C7B8),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _PresetSelector extends StatelessWidget {
  const _PresetSelector({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('预设方案'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: options.map((option) {
            return _PresetOption(
              label: option,
              selected: option == selected,
              onTap: () => onSelect(option),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _PresetOption extends StatefulWidget {
  const _PresetOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_PresetOption> createState() => _PresetOptionState();
}

class _PresetOptionState extends State<_PresetOption> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final highlight = selected || hovered;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF1A1B1C)
                : (hovered ? const Color(0xFF181A1B) : const Color(0xFF121314)),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: selected
                  ? const Color(0xFFFFB280)
                  : (hovered
                        ? const Color(0xFF3A3A3A)
                        : const Color(0xFF262626)),
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: highlight
                  ? const Color(0xFFFFF2D9)
                  : const Color(0xFFB8ADA6),
              fontSize: 13,
              fontWeight: highlight ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _FontRow extends StatelessWidget {
  const _FontRow({
    required this.family,
    required this.size,
    required this.onFamilyChanged,
    required this.onSizeChanged,
  });

  final String family;
  final int size;
  final ValueChanged<String> onFamilyChanged;
  final ValueChanged<int> onSizeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('字体'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _TextInput(value: family, onChanged: onFamilyChanged),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 80,
              child: _NumberInput(
                label: '',
                value: size,
                onChanged: onSizeChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CursorRow extends StatelessWidget {
  const _CursorRow({
    required this.style,
    required this.blink,
    required this.onStyleChanged,
    required this.onBlinkChanged,
  });

  final CursorStyle style;
  final bool blink;
  final ValueChanged<CursorStyle> onStyleChanged;
  final ValueChanged<bool> onBlinkChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('光标'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _CursorStyleSelector(
                value: style,
                onChanged: onStyleChanged,
              ),
            ),
            const SizedBox(width: 8),
            _BlinkCheckbox(value: blink, onChanged: onBlinkChanged),
          ],
        ),
      ],
    );
  }
}

String _cursorStyleLabel(CursorStyle s) {
  return switch (s) {
    CursorStyle.block => '█ block',
    CursorStyle.underline => '_ underline',
    CursorStyle.bar => '▏ bar',
  };
}

class _CursorStyleSelector extends StatefulWidget {
  const _CursorStyleSelector({required this.value, required this.onChanged});

  final CursorStyle value;
  final ValueChanged<CursorStyle> onChanged;

  @override
  State<_CursorStyleSelector> createState() => _CursorStyleSelectorState();
}

class _CursorStyleSelectorState extends State<_CursorStyleSelector> {
  static const Color _amberAccent = Color(0xFFFFB280);
  static const Color _triggerHoverBg = Color(0xFF232528);
  static const Duration _hoverDuration = Duration(milliseconds: 120);

  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _triggerHovered = false;
  double _triggerWidth = 0;

  bool get _isOpen => _overlayEntry != null;

  void _toggleOverlay() {
    if (_isOpen) {
      _hideOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    _triggerWidth = renderBox.size.width;
    final entry = OverlayEntry(builder: _buildOverlay);
    _overlayEntry = entry;
    Overlay.of(context).insert(entry);
    setState(() {});
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  Widget _buildOverlay(BuildContext _) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _hideOverlay,
          ),
        ),
        CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 4),
          child: SizedBox(
            width: _triggerWidth,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.panel,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final s in CursorStyle.values)
                      _CursorStyleItem(
                        label: _cursorStyleLabel(s),
                        selected: s == widget.value,
                        onTap: () {
                          widget.onChanged(s);
                          _hideOverlay();
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final highlight = _isOpen || _triggerHovered;
    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _triggerHovered = true),
        onExit: (_) => setState(() => _triggerHovered = false),
        child: GestureDetector(
          onTap: _toggleOverlay,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: _hoverDuration,
            height: 32,
            decoration: BoxDecoration(
              color: highlight ? _triggerHoverBg : AppColors.background,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: highlight ? _amberAccent : AppColors.border,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _cursorStyleLabel(widget.value),
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AnimatedRotation(
                  turns: _isOpen ? 0.5 : 0,
                  duration: _hoverDuration,
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    size: 16,
                    color: highlight ? _amberAccent : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CursorStyleItem extends StatefulWidget {
  const _CursorStyleItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_CursorStyleItem> createState() => _CursorStyleItemState();
}

class _CursorStyleItemState extends State<_CursorStyleItem> {
  static const Color _amberAccent = Color(0xFFFFB280);
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final highlight = _hovered;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 32,
          color: highlight ? AppColors.tabHover : Colors.transparent,
          child: Row(
            children: [
              Container(
                width: 3,
                height: double.infinity,
                color: highlight ? _amberAccent : Colors.transparent,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: highlight || widget.selected
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlinkCheckbox extends StatefulWidget {
  const _BlinkCheckbox({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  State<_BlinkCheckbox> createState() => _BlinkCheckboxState();
}

class _BlinkCheckboxState extends State<_BlinkCheckbox> {
  bool hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: GestureDetector(
        onTap: () => widget.onChanged(!widget.value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: hovered ? AppColors.accent : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.value ? Icons.check_box : Icons.check_box_outline_blank,
                size: 16,
                color: widget.value ? AppColors.accent : AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                '光标闪烁',
                style: TextStyle(
                  color: widget.value
                      ? AppColors.textPrimary
                      : AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorField extends StatelessWidget {
  const _ColorField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final Color value;
  final ValueChanged<Color> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFFB8ADA6), fontSize: 11),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 120,
          child: ColorPickerField(value: value, onChanged: onChanged),
        ),
      ],
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
  });

  final int index;
  final String pattern;
  final String note;
  final Color color;
  final ValueChanged<String> onPatternChanged;
  final ValueChanged<String> onNoteChanged;
  final ValueChanged<Color> onColorChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Tooltip(
              message: '拖动调整优先级',
              child: Icon(
                Icons.drag_indicator,
                size: 18,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: _TextInput(value: pattern, onChanged: onPatternChanged),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: _TextInput(value: note, onChanged: onNoteChanged),
            ),
          ),
          const SizedBox(width: 8),
          ColorPickerField(
            value: color,
            onChanged: onColorChanged,
            compact: true,
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: '移除正则规则',
            child: IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 16),
              color: AppColors.textMuted,
              hoverColor: AppColors.tabHover,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            ),
          ),
        ],
      ),
    );
  }
}

class _TextInput extends StatefulWidget {
  const _TextInput({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<_TextInput> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _TextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && controller.text != widget.value) {
      controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: TextFormField(
        controller: controller,
        style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.background,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 6,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(4)),
            borderSide: BorderSide(color: AppColors.accent),
          ),
        ),
        onChanged: widget.onChanged,
        onFieldSubmitted: widget.onChanged,
      ),
    );
  }
}

class _NumberInput extends StatefulWidget {
  const _NumberInput({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<_NumberInput> createState() => _NumberInputState();
}

class _NumberInputState extends State<_NumberInput> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.value.toString());
  }

  @override
  void didUpdateWidget(covariant _NumberInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final text = widget.value.toString();
    if (widget.value != oldWidget.value && controller.text != text) {
      controller.text = text;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _handleChanged(String value) {
    final parsed = int.tryParse(value);
    if (parsed != null) widget.onChanged(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label.isNotEmpty) ...[
          Text(
            widget.label,
            style: const TextStyle(color: Color(0xFFA6998C), fontSize: 11),
          ),
          const SizedBox(height: 4),
        ],
        SizedBox(
          height: 32,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(4)),
                borderSide: BorderSide(color: AppColors.accent),
              ),
            ),
            onChanged: _handleChanged,
            onFieldSubmitted: _handleChanged,
          ),
        ),
      ],
    );
  }
}
