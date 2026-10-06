import 'package:deepssh/core/models/theme_settings.dart';
import 'package:deepssh/core/storage/theme_preset_store.dart';
import 'package:deepssh/core/theme/app_colors.dart';
import 'package:deepssh/core/theme/app_theme.dart';
import 'package:deepssh/features/theme_config/theme_config_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('command deck ships the shipped regex set', () {
    final notes = TerminalThemeSettings.commandDeck().regexHighlights
        .map((highlight) => highlight.note)
        .toList();

    // The full set is pinned in test/core/default_regex_highlights_test.dart.
    expect(notes.first, 'Linux权限与用户');
    expect(notes, contains('Shell关键字与流程控制'));
    expect(notes, contains('网络与IP地址'));
  });

  test('regex highlight copyWith preserves and updates note', () {
    const highlight = RegexHighlight(
      pattern: 'ERROR',
      color: Color(0xFFF14C4C),
      note: '错误日志',
    );

    expect(highlight.copyWith(pattern: 'WARN').note, '错误日志');
    expect(highlight.copyWith(note: '警告日志').note, '警告日志');
  });

  test('theme presets include normal and bold font weights', () {
    final ui = UiThemeSettings.commandDeck();
    final terminal = TerminalThemeSettings.commandDeck();

    expect(ui.normalFontWeight, 500);
    expect(ui.boldFontWeight, 700);
    expect(terminal.normalFontWeight, 400);
    expect(terminal.boldFontWeight, 700);
  });

  test('theme copyWith preserves and updates font weights', () {
    final ui = UiThemeSettings.commandDeck().copyWith(normalFontWeight: 300);
    final terminal = TerminalThemeSettings.commandDeck().copyWith(
      boldFontWeight: 800,
    );

    expect(ui.normalFontWeight, 300);
    expect(ui.boldFontWeight, 700);
    expect(terminal.normalFontWeight, 400);
    expect(terminal.boldFontWeight, 800);
  });

  test('app theme applies configured normal and bold UI font weights', () {
    AppColors.applyUi(
      UiThemeSettings.commandDeck().copyWith(
        normalFontWeight: 300,
        boldFontWeight: 800,
      ),
    );

    final theme = AppTheme.deck();

    expect(theme.textTheme.bodyMedium?.fontWeight, FontWeight.w300);
    expect(theme.textTheme.titleLarge?.fontWeight, FontWeight.w800);
  });

  testWidgets('matches the prototype sections and head actions', (
    tester,
  ) async {
    await _pumpPage(tester);

    expect(find.text('APPEARANCE'), findsOneWidget);
    expect(find.text('主题配置'), findsOneWidget);
    expect(find.text('分别设置界面外观与终端渲染，并配置基于正则的输出高亮规则。'), findsOneWidget);
    expect(find.text('恢复默认'), findsOneWidget);
    expect(find.text('保存主题'), findsOneWidget);

    for (final label in [
      '预设方案',
      '字体',
      '配色',
      '实时预览',
      '光标',
      '终端配色',
      '正则高亮',
      '回滚缓冲行数',
    ]) {
      expect(find.text(label), findsWidgets, reason: 'missing section $label');
    }

    expect(find.byKey(const ValueKey('preset-trigger-ui')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('preset-trigger-terminal')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('swatch-ui-background')), findsOneWidget);
    expect(find.byKey(const ValueKey('swatch-term-cursor')), findsOneWidget);
  });

  testWidgets('buffers edits until 保存主题 is pressed', (tester) async {
    UiThemeSettings? savedUi;
    TerminalThemeSettings? savedTerminal;

    await _pumpPage(
      tester,
      onUiSaved: (settings) => savedUi = settings,
      onTerminalSaved: (settings) => savedTerminal = settings,
    );

    await tester.enterText(find.byKey(const ValueKey('ui-size-select')), '15');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(savedUi, isNull, reason: 'editing must not persist immediately');

    await tester.tap(find.byKey(const ValueKey('theme-save')));
    await tester.pump();

    expect(savedUi?.fontSize, 15);
    expect(savedTerminal, isNotNull);
  });

  testWidgets('恢复默认 swaps the draft back to Command Deck', (tester) async {
    UiThemeSettings? savedUi;

    await _pumpPage(tester, onUiSaved: (settings) => savedUi = settings);

    await tester.enterText(find.byKey(const ValueKey('ui-size-select')), '15');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('theme-reset')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('theme-save')));
    await tester.pump();

    expect(savedUi?.fontSize, 13);
  });

  testWidgets('the preset picker only ships the prototype Command Deck', (
    tester,
  ) async {
    await _pumpPage(tester);

    await tester.tap(find.byKey(const ValueKey('preset-trigger-ui')));
    await tester.pumpAndSettle();
    expect(find.text('Command Deck'), findsWidgets);
    expect(find.text('VS Code Dark'), findsNothing);

    // Close the UI menu before opening the terminal one.
    await tester.tap(find.byKey(const ValueKey('preset-trigger-ui')));
    await tester.pumpAndSettle();

    final terminalTrigger = find.byKey(
      const ValueKey('preset-trigger-terminal'),
    );
    await tester.ensureVisible(terminalTrigger);
    await tester.pumpAndSettle();
    await tester.tap(terminalTrigger);
    await tester.pumpAndSettle();
    expect(find.text('Command Deck'), findsWidgets);
    expect(find.text('One Dark'), findsNothing);
    expect(find.text('Solarized'), findsNothing);
  });

  testWidgets('creates and deletes a custom preset', (tester) async {
    final store = InMemoryThemePresetStore();
    await _pumpPage(tester, presetStore: store);

    final trigger = find.byKey(const ValueKey('preset-trigger-terminal'));
    await tester.ensureVisible(trigger);
    await tester.pumpAndSettle();
    await tester.tap(trigger);
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建自定义方案'));
    await tester.pumpAndSettle();

    // Both the trigger and the open menu row carry the name.
    expect(find.text('自定义方案 1'), findsWidgets);
    expect(find.text('自定义'), findsWidgets);

    final saved = await store.load();
    expect(saved.terminalCustom, hasLength(1));

    // The create action keeps the menu open, so the delete affordance is
    // already on screen.
    final deleteButton = find.byTooltip('删除此自定义方案');
    expect(deleteButton, findsOneWidget);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect((await store.load()).terminalCustom, isEmpty);
    expect(find.text('自定义方案 1'), findsNothing);
  });

  testWidgets('empty regex list shows the guidance', (tester) async {
    final terminalSettings = TerminalThemeSettings.commandDeck().copyWith(
      regexHighlights: const [],
    );

    await _pumpPage(tester, terminalSettings: terminalSettings);

    expect(find.text('当前预设没有高亮规则'), findsOneWidget);
  });

  testWidgets('removes regex highlight rules from terminal settings', (
    tester,
  ) async {
    TerminalThemeSettings? savedTerminal;
    final terminalSettings = TerminalThemeSettings.commandDeck().copyWith(
      regexHighlights: const [
        RegexHighlight(
          pattern: 'ERROR',
          color: Color(0xFFF14C4C),
          note: '错误日志',
        ),
        RegexHighlight(pattern: 'WARN', color: Color(0xFFF5F543), note: '警告日志'),
      ],
    );

    await _pumpPage(
      tester,
      terminalSettings: terminalSettings,
      onTerminalSaved: (settings) => savedTerminal = settings,
    );

    await tester.ensureVisible(find.byTooltip('移除正则规则').first);
    await tester.tap(find.byTooltip('移除正则规则').first);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('theme-save')));
    await tester.pump();

    expect(savedTerminal?.regexHighlights, hasLength(1));
    expect(savedTerminal?.regexHighlights.single.pattern, 'WARN');
  });

  testWidgets('updates regex highlight notes from terminal settings', (
    tester,
  ) async {
    TerminalThemeSettings? savedTerminal;
    final terminalSettings = TerminalThemeSettings.commandDeck().copyWith(
      regexHighlights: const [
        RegexHighlight(
          pattern: 'ERROR',
          color: Color(0xFFF14C4C),
          note: '错误日志',
        ),
      ],
    );

    await _pumpPage(
      tester,
      terminalSettings: terminalSettings,
      onTerminalSaved: (settings) => savedTerminal = settings,
    );

    final noteField = find.descendant(
      of: find.byKey(const ValueKey('regex-note-0')),
      matching: find.byType(TextField),
    );
    expect(noteField, findsOneWidget);
    await tester.enterText(noteField, '异常');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('theme-save')));
    await tester.pump();

    expect(savedTerminal?.regexHighlights, hasLength(1));
    expect(savedTerminal?.regexHighlights.single.pattern, 'ERROR');
    expect(
      savedTerminal?.regexHighlights.single.color,
      const Color(0xFFF14C4C),
    );
    expect(savedTerminal?.regexHighlights.single.note, '异常');
  });

  testWidgets('reorders regex highlight rules from terminal settings', (
    tester,
  ) async {
    TerminalThemeSettings? savedTerminal;
    final terminalSettings = TerminalThemeSettings.commandDeck().copyWith(
      regexHighlights: const [
        RegexHighlight(
          pattern: 'ERROR',
          color: Color(0xFFF14C4C),
          note: '错误日志',
        ),
        RegexHighlight(pattern: 'WARN', color: Color(0xFFF5F543), note: '警告日志'),
        RegexHighlight(pattern: 'INFO', color: Color(0xFF23D18B), note: '普通日志'),
      ],
    );

    await _pumpPage(
      tester,
      terminalSettings: terminalSettings,
      onTerminalSaved: (settings) => savedTerminal = settings,
    );

    final reorderable = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    reorderable.onReorder?.call(0, 3);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('theme-save')));
    await tester.pump();

    expect(
      savedTerminal?.regexHighlights.map((highlight) => highlight.pattern),
      ['WARN', 'INFO', 'ERROR'],
    );
  });

  testWidgets('keeps regex highlight input focused while settings rebuild', (
    tester,
  ) async {
    final terminalSettings = TerminalThemeSettings.commandDeck().copyWith(
      regexHighlights: const [
        RegexHighlight(pattern: '', color: Color(0xFFF14C4C), note: ''),
      ],
    );

    await _pumpPage(tester, terminalSettings: terminalSettings);

    final regexField = find
        .descendant(
          of: find.byKey(const ValueKey('regex-pattern-0')).first,
          matching: find.byType(TextField),
        )
        .first;
    await tester.ensureVisible(regexField);
    await tester.tap(regexField);
    await tester.enterText(regexField, 'E');
    await tester.pump();

    expect(tester.testTextInput.isVisible, isTrue);
    expect(find.text('E'), findsOneWidget);
  });

  testWidgets('adds regex highlight rule with empty note', (tester) async {
    TerminalThemeSettings? savedTerminal;
    final terminalSettings = TerminalThemeSettings.commandDeck().copyWith(
      regexHighlights: const [],
    );

    await _pumpPage(
      tester,
      terminalSettings: terminalSettings,
      onTerminalSaved: (settings) => savedTerminal = settings,
    );

    await tester.ensureVisible(find.text('添加规则'));
    await tester.tap(find.text('添加规则'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('theme-save')));
    await tester.pump();

    expect(savedTerminal?.regexHighlights, hasLength(1));
    expect(savedTerminal?.regexHighlights.single.pattern, '');
    expect(savedTerminal?.regexHighlights.single.note, '');
    expect(
      savedTerminal?.regexHighlights.single.color,
      const Color(0xFFFFFFFF),
    );
  });

  test('patternError accepts valid patterns and empty rules', () {
    expect(RegexHighlight.patternError(''), isNull);
    expect(RegexHighlight.patternError(r'\broot\b'), isNull);
    // Every rule the app ships must itself compile.
    for (final rule in TerminalThemeSettings.commandDeck().regexHighlights) {
      expect(
        RegexHighlight.patternError(rule.pattern),
        isNull,
        reason: 'shipped rule does not compile: ${rule.pattern}',
      );
    }
  });

  test('patternError reports the Dart message for a broken pattern', () {
    final error = RegexHighlight.patternError('(unclosed');
    expect(error, isNotNull);
    expect(error, isNotEmpty);
    // An empty pattern is "no rule", never an error.
    expect(RegexHighlight.patternError(''), isNull);
  });

  testWidgets('an invalid regex pattern is reported under its row', (
    tester,
  ) async {
    await _pumpPage(tester);

    expect(find.textContaining('正则无效'), findsNothing);

    final patternField = find.byKey(const ValueKey('regex-pattern-0'));
    await tester.ensureVisible(patternField);
    await tester.pump();
    await tester.enterText(
      find.descendant(of: patternField, matching: find.byType(TextField)),
      '(unclosed',
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('正则无效'), findsOneWidget);
    // The rule keeps its slot — the point is to tell the user, not to discard
    // their edit behind their back.
    final field = tester.widget<TextField>(
      find.descendant(of: patternField, matching: find.byType(TextField)),
    );
    expect(field.controller?.text, '(unclosed');
  });

  testWidgets('live preview follows the terminal font stack and size', (
    tester,
  ) async {
    await _pumpPage(tester);

    TextSpan previewSpan() {
      final rich = tester.widget<RichText>(
        find.byKey(const ValueKey('term-preview')),
      );
      return rich.text as TextSpan;
    }

    expect(previewSpan().style?.fontSize, 14);

    await tester.enterText(
      find.byKey(const ValueKey('term-font-input')),
      'Fira Code, monospace',
    );
    await tester.pump();
    expect(
      (previewSpan().children!.first as TextSpan).style?.fontFamily,
      'Fira Code',
    );

    await tester.enterText(find.byKey(const ValueKey('term-size-input')), '20');
    await tester.pump();
    expect(previewSpan().style?.fontSize, 20);
  });

  testWidgets('size fields take decimals, clamp the band and round to 2dp', (
    tester,
  ) async {
    UiThemeSettings? savedUi;
    TerminalThemeSettings? savedTerminal;

    await _pumpPage(
      tester,
      onUiSaved: (settings) => savedUi = settings,
      onTerminalSaved: (settings) => savedTerminal = settings,
    );

    // The prototype's inputs are decimal fields (`step="0.5"`), so a
    // fractional size is kept as typed.
    await tester.enterText(
      find.byKey(const ValueKey('ui-size-select')),
      '13.5',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('theme-save')));
    await tester.pump();
    expect(savedUi?.fontSize, 13.5);

    // Over-precise input rounds to two decimals, like the prototype's
    // `sizeClamp` does on every pass.
    await tester.enterText(
      find.byKey(const ValueKey('ui-size-select')),
      '13.456',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('theme-save')));
    await tester.pump();
    expect(savedUi?.fontSize, 13.46);

    // Out-of-band input clamps to the field's own band, and the live
    // terminal preview follows the fractional size.
    await tester.enterText(
      find.byKey(const ValueKey('term-size-input')),
      '12.5',
    );
    await tester.pump();
    final rich = tester.widget<RichText>(
      find.byKey(const ValueKey('term-preview')),
    );
    expect((rich.text as TextSpan).style?.fontSize, 12.5);

    await tester.enterText(
      find.byKey(const ValueKey('term-size-input')),
      '40.777',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('theme-save')));
    await tester.pump();
    expect(savedTerminal?.fontSize, 32);
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  UiThemeSettings? uiSettings,
  TerminalThemeSettings? terminalSettings,
  ValueChanged<UiThemeSettings>? onUiSaved,
  ValueChanged<TerminalThemeSettings>? onTerminalSaved,
  ThemePresetStore? presetStore,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ThemeConfigPage(
          uiSettings: uiSettings ?? UiThemeSettings.commandDeck(),
          terminalSettings:
              terminalSettings ?? TerminalThemeSettings.commandDeck(),
          onUiSettingsChanged: onUiSaved ?? (_) {},
          onTerminalSettingsChanged: onTerminalSaved ?? (_) {},
          onBack: () {},
          presetStore: presetStore ?? InMemoryThemePresetStore(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
