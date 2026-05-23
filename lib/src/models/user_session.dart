class UserSession {
  UserSession({
    required this.id,
    required this.username,
    this.email,
    this.avatarUrl,
    required this.jwt,
  });

  factory UserSession.fromMe(Map<String, dynamic> json, String jwt) {
    final username = json['username'] as String? ?? 'binarycoffee';
    final avatar = json['avatar']?['url'] as String?;
    return UserSession(
      id: json['id']?.toString() ?? '',
      username: username,
      email: json['email'] as String?,
      avatarUrl: avatar?.startsWith('http') == true
          ? avatar
          : (avatar == null
                ? 'https://github.com/$username.png?size=96'
                : 'https://api.binarycoffee.dev$avatar'),
      jwt: jwt,
    );
  }

  factory UserSession.fromPrefs(Map<String, String> json) => UserSession(
    id: json['id'] ?? '',
    username: json['username'] ?? '',
    email: json['email'],
    avatarUrl: json['avatarUrl'],
    jwt: json['jwt'] ?? '',
  );

  final String id;
  final String username;
  final String? email;
  final String? avatarUrl;
  final String jwt;

  Map<String, String> toPrefs() {
    final values = {'id': id, 'username': username, 'jwt': jwt};
    if (email != null) values['email'] = email!;
    if (avatarUrl != null) values['avatarUrl'] = avatarUrl!;
    return values;
  }
}
