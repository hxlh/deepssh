import '../../core/models/host_item.dart';

class HostTreeState {
  HostTreeState() : hosts = const [], expandedHostIds = const {};

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
