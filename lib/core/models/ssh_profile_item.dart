class SshProfileItem {
  const SshProfileItem({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    required this.password,
  });

  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final String password;
}
