import 'package:deepssh/core/models/theme_settings.dart';
import 'package:flutter_test/flutter_test.dart';

/// The regex set ships as part of the build, so a typo would fail silently —
/// `TerminalView` swallows `FormatException` and drops the rule. This pins the
/// shipped list: same length, same order, same colours, and every pattern
/// actually compiles and matches something.
void main() {
  final rules = TerminalThemeSettings.commandDeck().regexHighlights;

  test('ships the ten expected rules in order', () {
    expect(rules.map((r) => r.note).toList(), <String>[
      'Linux权限与用户',
      'Linux文件路径',
      'Shell关键字与流程控制',
      '成功/错误状态',
      '网址链接',
      '字符串与引号',
      '环境变量与参数',
      '网络与IP地址',
      '时间与日期',
      '数字与计数',
    ]);
  });

  test('every rule compiles', () {
    for (final rule in rules) {
      expect(
        () => RegExp(rule.pattern),
        returnsNormally,
        reason: '${rule.note}: ${rule.pattern}',
      );
    }
  });

  test('every rule matches a representative sample', () {
    const samples = <String, String>{
      'Linux权限与用户': 'drwxr-xr-x 4 root root 4096 Aug 4 10:00 src',
      'Linux文件路径': 'cat /etc/nginx/nginx.conf',
      'Shell关键字与流程控制': r'''if [ -f "$f" ]; then exit 0; fi''',
      '成功/错误状态': 'build SUCCESS in 4s ✅',
      '网址链接': 'GET https://api.example.com/v1/orders returned 200',
      '字符串与引号': 'echo "hello world"',
      '环境变量与参数': r'''export PATH=/usr/bin:$HOME --verbose''',
      '网络与IP地址': 'curl 10.24.8.11:8080 localhost',
      '时间与日期': '2026-10-04T14:32:01Z request finished',
      '数字与计数': 'loaded 184213 rows in 128MB',
    };

    for (final rule in rules) {
      final sample = samples[rule.note];
      expect(sample, isNotNull, reason: 'no sample for ${rule.note}');
      expect(
        RegExp(rule.pattern).hasMatch(sample!),
        isTrue,
        reason: '${rule.note} does not match: $sample',
      );
    }
  });

  test('rule colours match the shipped palette', () {
    expect(rules.map((r) => r.color.toARGB32()).toList(), <int>[
      0xFFC1794F,
      0xFFE0C828,
      0xFFFF1495,
      0xFF1EBF19,
      0xFF3F8EE8,
      0xFF5E923D,
      0xFFCC703A,
      0xFF459BFF,
      0xFF7960FF,
      0xFF1AA416,
    ]);
  });
}
