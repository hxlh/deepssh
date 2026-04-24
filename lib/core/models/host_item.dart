import 'terminal_item.dart';

class HostItem {
  const HostItem({
    required this.id,
    required this.name,
    required this.terminals,
  });

  final String id;
  final String name;
  final List<TerminalItem> terminals;
}
