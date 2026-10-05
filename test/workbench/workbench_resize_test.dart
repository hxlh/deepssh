import 'package:deepssh/features/hosts/host_tree.dart';
import 'package:deepssh/features/ssh/ssh_bridge.dart';
import 'package:deepssh/features/theme/theme_bridge.dart';
import 'package:deepssh/workbench/widgets/resize_handle.dart';
import 'package:deepssh/workbench/widgets/sidebar.dart';
import 'package:deepssh/workbench/widgets/workbench_dock.dart';
import 'package:deepssh/workbench/workbench_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpWorkbench(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: WorkbenchPage(
          sshBridge: InMemorySshBridgeClient(),
          themeBridge: InMemoryThemeBridgeClient(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('dock splitter drags below the fold and back out', (
    tester,
  ) async {
    await pumpWorkbench(tester);

    final dock = find.byType(WorkbenchDock);
    final initial = tester.getSize(dock).height;

    // Pointer-anchored: moving the splitter up by 80 grows the dock by 80.
    var rect = tester.getRect(dock);
    await tester.dragFrom(
      Offset(rect.center.dx, rect.top + 5),
      const Offset(0, -80),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(dock).height, closeTo(initial + 80, 12));

    // Dragging past the 96px threshold folds the dock to its 37px title bar
    // (plus the splitter that stays in the layout).
    rect = tester.getRect(dock);
    await tester.dragFrom(
      Offset(rect.center.dx, rect.top + 5),
      const Offset(0, 420),
    );
    await tester.pumpAndSettle();
    // 37px title bar + the 20px splitter rail that stays in the layout.
    expect(tester.getSize(dock).height, closeTo(57, 2));

    // Dragging the folded splitter down re-opens it in place.
    rect = tester.getRect(dock);
    await tester.dragFrom(
      Offset(rect.center.dx, rect.top + 5),
      const Offset(0, -160),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(dock).height, greaterThan(120));

    // End expands to the 420px maximum, Home folds again.
    rect = tester.getRect(dock);
    await tester.tapAt(Offset(rect.center.dx, rect.top + 5));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();
    expect(tester.getSize(dock).height, closeTo(430, 12));

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pumpAndSettle();
    // 37px title bar + the 20px splitter rail that stays in the layout.
    expect(tester.getSize(dock).height, closeTo(57, 2));
  });

  testWidgets('sidebar clamps to the 56px icon rail and back to 560px', (
    tester,
  ) async {
    await pumpWorkbench(tester);

    final sidebar = find.byType(Sidebar);
    expect(tester.getSize(sidebar).width, 280);

    final handle = find.byType(ResizeHandle);
    await tester.drag(handle, const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(tester.getSize(sidebar).width, 56);
    expect(tester.widget<HostTree>(find.byType(HostTree)).compact, isTrue);
    // The footer tools shed their labels in rail mode (the dock panel header
    // outside the sidebar still carries the same words).
    final sidebarMemory = find.descendant(
      of: sidebar,
      matching: find.text('内存监控'),
    );
    expect(sidebarMemory, findsNothing);

    await tester.drag(handle, const Offset(900, 0));
    await tester.pumpAndSettle();
    expect(tester.getSize(sidebar).width, 560);
    expect(tester.widget<HostTree>(find.byType(HostTree)).compact, isFalse);
    expect(sidebarMemory, findsOneWidget);
  });
}
