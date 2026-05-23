class UserSession {
  UserSession({
    required this.id,
    required this.username,
    this.email,
    this.avatarUrl,
    required this.jwt,
    this.confirmed,
    this.blocked,
    this.roleName,
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
      confirmed: json['confirmed'] as bool?,
      blocked: json['blocked'] as bool?,
      roleName: json['role']?['name'] as String?,
    );
  }

  factory UserSession.fromPrefs(Map<String, String> json) => UserSession(
    id: json['id'] ?? '',
    username: json['username'] ?? '',
    email: json['email'],
    avatarUrl: json['avatarUrl'],
    jwt: json['jwt'] ?? '',
    confirmed: json['confirmed'] == null ? null : json['confirmed'] == 'true',
    blocked: json['blocked'] == null ? null : json['blocked'] == 'true',
    roleName: json['roleName'],
  );

  final String id;
  final String username;
  final String? email;
  final String? avatarUrl;
  final String jwt;
  final bool? confirmed;
  final bool? blocked;
  final String? roleName;

  Map<String, String> toPrefs() {
    final values = {'id': id, 'username': username, 'jwt': jwt};
    if (email != null) values['email'] = email!;
    if (avatarUrl != null) values['avatarUrl'] = avatarUrl!;
    if (confirmed != null) values['confirmed'] = confirmed.toString();
    if (blocked != null) values['blocked'] = blocked.toString();
    if (roleName != null) values['roleName'] = roleName!;
    return values;
  }
}
