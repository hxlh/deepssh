import 'package:deepssh/core/models/theme_presets.dart';
import 'package:deepssh/core/models/theme_settings.dart';
import 'package:deepssh/core/storage/theme_preset_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rust preset bridge preserves both arrays and hidden ids', () {
    final ui = UiThemeSettings.commandDeck().copyWith(
      fontFamily: 'Fira Sans',
      fontSize: 16,
    );
    final terminal = TerminalThemeSettings.commandDeck().copyWith(
      fontFamily: 'JetBrains Mono, JetBrainsMono Nerd Font',
      cursorStyle: CursorStyle.underline,
      cursorBlink: false,
    );
    final original = ThemePresetLibrary(
      uiCustom: [
        ThemePreset(
          id: 'ui-custom',
          name: '界面方案',
          swatch: ui.background,
          ui: ui,
          custom: true,
        ),
      ],
      terminalCustom: [
        ThemePreset(
          id: 'term-custom',
          name: '终端方案',
          swatch: terminal.terminalBackground,
          terminal: terminal,
          custom: true,
        ),
      ],
      hiddenUiIds: const {'deck'},
      hiddenTerminalIds: const {'term-hidden'},
    );

    final restored = presetLibraryFromRust(presetLibraryToRust(original));

    expect(restored.uiCustom.single.id, 'ui-custom');
    expect(restored.uiCustom.single.ui?.fontFamily, 'Fira Sans');
    expect(restored.terminalCustom.single.id, 'term-custom');
    expect(
      restored.terminalCustom.single.terminal?.fontFamily,
      'JetBrains Mono, JetBrainsMono Nerd Font',
    );
    expect(
      restored.terminalCustom.single.terminal?.cursorStyle,
      CursorStyle.underline,
    );
    expect(restored.terminalCustom.single.terminal?.cursorBlink, isFalse);
    expect(restored.hiddenUiIds, {'deck'});
    expect(restored.hiddenTerminalIds, {'term-hidden'});
  });
}
