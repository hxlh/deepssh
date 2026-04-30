class SshProfileItem {
  static const defaultTermType = 'xterm-256color';
  static const termTypeOptions = <String>[
    'xterm',
    'xterm-color',
    'xterm-16color',
    'xterm-256color',
    'xterm-truecolor',
  ];

  const SshProfileItem({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    this.termType = defaultTermType,
  });

  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final String password;
  final String termType;
}
