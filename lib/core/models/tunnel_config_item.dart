enum TunnelForwardType { local, remote }

enum TunnelRuntimeStatus { stopped, waiting, forwarding }

class TunnelConfigItem {
  const TunnelConfigItem({
    required this.id,
    required this.name,
    required this.type,
    required this.sshProfileId,
    required this.listenHost,
    required this.listenPort,
    required this.targetHost,
    required this.targetPort,
    this.status = TunnelRuntimeStatus.stopped,
  });

  final String id;
  final String name;
  final TunnelForwardType type;
  final String sshProfileId;
  final String listenHost;
  final int listenPort;
  final String targetHost;
  final int targetPort;
  final TunnelRuntimeStatus status;

  String get directionLabel {
    switch (type) {
      case TunnelForwardType.local:
        return 'LOCAL';
      case TunnelForwardType.remote:
        return 'REMOTE';
    }
  }

  String get forwardingSummary =>
      '$directionLabel $listenHost:$listenPort → $targetHost:$targetPort';

  bool get isForwarding => status == TunnelRuntimeStatus.forwarding;

  bool get isRunning => status != TunnelRuntimeStatus.stopped;

  TunnelConfigItem copyWith({
    String? id,
    String? name,
    TunnelForwardType? type,
    String? sshProfileId,
    String? listenHost,
    int? listenPort,
    String? targetHost,
    int? targetPort,
    TunnelRuntimeStatus? status,
  }) {
    return TunnelConfigItem(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      sshProfileId: sshProfileId ?? this.sshProfileId,
      listenHost: listenHost ?? this.listenHost,
      listenPort: listenPort ?? this.listenPort,
      targetHost: targetHost ?? this.targetHost,
      targetPort: targetPort ?? this.targetPort,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TunnelConfigItem &&
        other.id == id &&
        other.name == name &&
        other.type == type &&
        other.sshProfileId == sshProfileId &&
        other.listenHost == listenHost &&
        other.listenPort == listenPort &&
        other.targetHost == targetHost &&
        other.targetPort == targetPort &&
        other.status == status;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    type,
    sshProfileId,
    listenHost,
    listenPort,
    targetHost,
    targetPort,
    status,
  );
}
