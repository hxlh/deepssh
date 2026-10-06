import 'package:deepssh/core/models/ssh_profile_item.dart';
import 'package:deepssh/features/hosts/host_tree.dart';
import 'package:deepssh/features/hosts/session_reorder.dart';
import 'package:deepssh/features/local_terminal/local_terminal_bridge.dart';
import 'package:deepssh/features/ssh/ssh_bridge.dart';
import 'package:deepssh/features/theme/theme_bridge.dart';
import 'package:deepssh/workbench/widgets/add_connection_button.dart';
import 'package:deepssh/workbench/workbench_page.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSshBridge extends InMemorySshBridgeClient {
  @override
  Future<List<SshProfileItem>> listProfiles() async => [
    SshProfileItem(
      id: 'p1',
      name: 'Server A',
      host: 'a.example.com',
      port: 22,
      username: 'user',
      password: '',
    ),
    SshProfileItem(
      id: 'p2',
      name: 'Server B',
      host: 'b.example.com',
      port: 22,
      username: 'user',
      password: '',
    ),
  ];
}

class _FakeThemeBridge extends InMemoryThemeBridgeClient {}

Future<void> _pumpWithLocalTerminals(WidgetTester tester, int count) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: WorkbenchPage(
        sshBridge: _FakeSshBridge(),
        themeBridge: _FakeThemeBridge(),
        localTerminalBridge: InMemoryLocalTerminalBridgeClient(),
      ),
    ),
  );
  await tester.pumpAndSettle();

  for (var i = 0; i < count; i++) {
    await tester.tap(find.text('新增连接'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(addConnectionMenuKey(AddConnectionAction.localTerminal)),
    );
    await tester.pumpAndSettle();
  }
}

Future<void> _pumpWithTwoLocalTerminals(WidgetTester tester) =>
    _pumpWithLocalTerminals(tester, 2);

void main() {
  testWidgets('profiles display after loading', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: WorkbenchPage(
          sshBridge: _FakeSshBridge(),
          themeBridge: _FakeThemeBridge(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Server A'), findsOneWidget);
    expect(find.text('Server B'), findsOneWidget);
  });

  testWidgets('local terminal rows reorder by dragging the grip', (
    tester,
  ) async {
    await _pumpWithTwoLocalTerminals(tester);

    final firstRow = find.byKey(const ValueKey('local-local-terminal-1'));
    final secondRow = find.byKey(const ValueKey('local-local-terminal-2'));
    expect(firstRow, findsOneWidget);
    expect(secondRow, findsOneWidget);
    expect(
      tester.getTopLeft(secondRow).dy,
      greaterThan(tester.getTopLeft(firstRow).dy),
    );

    // The grip must be draggable: it used to be parked at a negative offset
    // inside the inset row stack, which paints through Clip.none but never
    // hit-tests, so the drag never started and rows could not be reordered.
    final grips = find.byIcon(Icons.drag_indicator);
    expect(grips, findsNWidgets(2));
    final gesture = await tester.startGesture(
      tester.getCenter(grips.at(1)),
      kind: PointerDeviceKind.mouse,
    );
    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(const Offset(0, -12));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(secondRow).dy,
      lessThan(tester.getTopLeft(firstRow).dy),
    );
  });

  testWidgets('a press anywhere on the row starts the reorder', (
    tester,
  ) async {
    await _pumpWithTwoLocalTerminals(tester);

    final firstRow = find.byKey(const ValueKey('local-local-terminal-1'));
    final secondRow = find.byKey(const ValueKey('local-local-terminal-2'));
    expect(
      tester.getTopLeft(secondRow).dy,
      greaterThan(tester.getTopLeft(firstRow).dy),
    );

    // The prototype lifts the row from a press anywhere on it; only the
    // grip used to be a drag surface. Press on the row body, right of the
    // grip and clear of the close button.
    final start = tester.getTopLeft(secondRow) + const Offset(70, 18);
    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
    );
    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(const Offset(0, -12));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(secondRow).dy,
      lessThan(tester.getTopLeft(firstRow).dy),
    );
  });

  testWidgets('a drag from the close button neither reorders nor closes', (
    tester,
  ) async {
    await _pumpWithTwoLocalTerminals(tester);

    final firstRow = find.byKey(const ValueKey('local-local-terminal-1'));
    final secondRow = find.byKey(const ValueKey('local-local-terminal-2'));
    final close = find.descendant(
      of: secondRow,
      matching: find.byIcon(Icons.close),
    );
    expect(close, findsOneWidget);

    final gesture = await tester.startGesture(
      tester.getCenter(close),
      kind: PointerDeviceKind.mouse,
    );
    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(const Offset(0, -12));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();

    // The button must stay outside the row's drag surface: a press that
    // starts on it is not a reorder, and a drag is not a close either.
    expect(firstRow, findsOneWidget);
    expect(secondRow, findsOneWidget);
    expect(
      tester.getTopLeft(secondRow).dy,
      greaterThan(tester.getTopLeft(firstRow).dy),
    );
  });

  testWidgets('a tap on the row still activates the terminal', (tester) async {
    await _pumpWithTwoLocalTerminals(tester);

    String selected() =>
        tester.widget<HostTree>(find.byType(HostTree)).selectedTerminalId!;
    expect(selected(), 'local-terminal-2');

    await tester.tap(find.byKey(const ValueKey('local-local-terminal-1')));
    await tester.pumpAndSettle();
    expect(selected(), 'local-terminal-1');
  });

  testWidgets('the drop slot follows the pointer, not the drag start', (
    tester,
  ) async {
    await _pumpWithLocalTerminals(tester, 3);

    final firstRow = find.byKey(const ValueKey('local-local-terminal-1'));
    final double top = tester.getTopLeft(firstRow).dy;
    const double slot = 36;

    // Press the top row and glide it one slot down: the moment the pointer
    // passes the next row's middle the dashed slot has to be there, not left
    // behind at the drag's origin.
    final gesture = await tester.startGesture(
      Offset(120, top + 18),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await gesture.moveTo(Offset(120, top + slot + 20));
    await tester.pump();
    expect(
      tester.getTopLeft(find.byKey(sessionDropShadeKey)).dy,
      closeTo(top + slot, 1),
    );

    // Above the next row's middle the slot comes back home.
    await gesture.moveTo(Offset(120, top + 2));
    await tester.pump();
    expect(
      tester.getTopLeft(find.byKey(sessionDropShadeKey)).dy,
      closeTo(top, 1),
    );

    // And it reaches the bottom slot without extra travel.
    await gesture.moveTo(Offset(120, top + slot * 2 + 20));
    await tester.pump();
    expect(
      tester.getTopLeft(find.byKey(sessionDropShadeKey)).dy,
      closeTo(top + slot * 2, 1),
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(firstRow).dy, closeTo(top + slot * 2, 1));
  });
}
