import '../../core/models/host_item.dart';
import '../../core/models/terminal_item.dart';

class HostTreeState {
  HostTreeState()
      : hosts = const [
          HostItem(
            id: 'machine1',
            name: 'machine1',
            terminals: [
              TerminalItem(id: 'm1-t1', hostId: 'machine1', title: 'terminal1'),
              TerminalItem(id: 'm1-t2', hostId: 'machine1', title: 'terminal2'),
            ],
          ),
          HostItem(
            id: 'machine2',
            name: 'machine2',
            terminals: [
              TerminalItem(id: 'm2-t1', hostId: 'machine2', title: 'terminal1'),
            ],
          ),
        ],
        expandedHostIds = {'machine1', 'machine2'};

  HostTreeState._({required this.hosts, required this.expandedHostIds});

  final List<HostItem> hosts;
  final Set<String> expandedHostIds;

  bool isExpanded(String hostId) => expandedHostIds.contains(hostId);

  HostTreeState toggleHost(String hostId) {
    final next = Set<String>.from(expandedHostIds);
    if (next.contains(hostId)) {
      next.remove(hostId);
    } else {
      next.add(hostId);
    }
    return HostTreeState._(hosts: hosts, expandedHostIds: next);
  }
}
