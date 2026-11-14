class EmailConfig {
  final String host;
  final int port;
  final String email;
  final String password;
  final bool useSsl;

  EmailConfig({
    required this.host,
    required this.port,
    required this.email,
    required this.password,
    this.useSsl = true,
  });

  Map<String, dynamic> toMap() => {
    'host': host,
    'port': port,
    'email': email,
    'password': password,
    'useSsl': useSsl ? 1 : 0,
  };

  factory EmailConfig.fromMap(Map<String, dynamic> map) {
    return EmailConfig(
      host: map['host'] ?? 'imap.gmail.com',
      port: map['port'] ?? 993,
      email: map['email'] ?? '',
      password: map['password'] ?? '',
      useSsl: map['useSsl'] == 1,
    );
  }
}