import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/post.dart';
import '../models/user_session.dart';

class SessionStore {
  static const _keys = ['id', 'username', 'email', 'avatarUrl', 'jwt'];
  static const _favoritePostIdsKey = 'blog.favoritePostIds';
  static const _readHistoryPostIdsKey = 'blog.readHistoryPostIds';
  static const _recentSearchesKey = 'blog.recentSearches';
  static const _cachedPostIdsKey = 'blog.cachedPostIds';
  static const _likedPostIdsKey = 'blog.likedPostIds';
  static const _lastSeenLatestPostNameKey = 'blog.lastSeenLatestPostName';
  static const _maxRecentSearches = 8;

  Future<UserSession?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jwt = prefs.getString('session.jwt');
    final username = prefs.getString('session.username');
    if (jwt == null || username == null) return null;
    return UserSession.fromPrefs({
      for (final key in _keys)
        if (prefs.getString('session.$key') != null)
          key: prefs.getString('session.$key')!,
    });
  }

  Future<void> save(UserSession session) async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in session.toPrefs().entries) {
      await prefs.setString('session.${entry.key}', entry.value);
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in _keys) {
      await prefs.remove('session.$key');
    }
  }

  Future<bool> loadDarkMode() async =>
      (await SharedPreferences.getInstance()).getBool('darkMode') ?? true;

  Future<void> saveDarkMode(bool value) async =>
      (await SharedPreferences.getInstance()).setBool('darkMode', value);

  Future<bool> loadNotifications() async =>
      (await SharedPreferences.getInstance()).getBool('notificationsEnabled') ??
      true;

  Future<void> saveNotifications(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(
        'notificationsEnabled',
        value,
      );

  Future<Set<String>> loadFavoritePostIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_favoritePostIdsKey)?.toSet() ?? <String>{};
  }

  Future<void> saveFavoritePostIds(Set<String> postIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritePostIdsKey, _cleanIds(postIds));
  }

  Future<Set<String>> toggleFavoritePostId(String postId) async {
    final postIds = await loadFavoritePostIds();
    if (postIds.contains(postId)) {
      postIds.remove(postId);
    } else if (postId.trim().isNotEmpty) {
      postIds.add(postId.trim());
    }
    await saveFavoritePostIds(postIds);
    return postIds;
  }

  Future<List<String>> loadReadHistoryPostIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_readHistoryPostIdsKey) ?? const [];
  }

  Future<void> saveReadHistoryPostIds(List<String> postIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_readHistoryPostIdsKey, _cleanIds(postIds));
  }

  Future<List<String>> markPostRead(String postId) async {
    final history = await loadReadHistoryPostIds();
    final updated = _moveToFront(history, postId);
    await saveReadHistoryPostIds(updated);
    return updated;
  }

  Future<List<String>> loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_recentSearchesKey) ?? const [];
  }

  Future<void> saveRecentSearches(List<String> searches) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _recentSearchesKey,
      _cleanStrings(searches).take(_maxRecentSearches).toList(),
    );
  }

  Future<List<String>> addRecentSearch(String search) async {
    final searches = await loadRecentSearches();
    final updated = _moveToFront(
      searches,
      search,
      caseInsensitive: true,
    ).take(_maxRecentSearches).toList();
    await saveRecentSearches(updated);
    return updated;
  }

  Future<List<Post>> loadCachedPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final postIds = prefs.getStringList(_cachedPostIdsKey) ?? const [];
    final posts = <Post>[];

    for (final postId in postIds) {
      final post = _decodePost(prefs.getString(_cachedPostKey(postId)));
      if (post != null) posts.add(post);
    }

    return posts;
  }

  Future<Post?> loadCachedPost(String postId) async {
    final prefs = await SharedPreferences.getInstance();
    return _decodePost(prefs.getString(_cachedPostKey(postId)));
  }

  Future<void> cacheOpenedPost(Post post) async {
    final prefs = await SharedPreferences.getInstance();
    final postIds = prefs.getStringList(_cachedPostIdsKey) ?? const [];
    await prefs.setString(_cachedPostKey(post.id), jsonEncode(post.toJson()));
    await prefs.setStringList(
      _cachedPostIdsKey,
      _moveToFront(postIds, post.id),
    );
  }

  Future<void> removeCachedPost(String postId) async {
    final prefs = await SharedPreferences.getInstance();
    final postIds = prefs.getStringList(_cachedPostIdsKey) ?? const [];
    await prefs.remove(_cachedPostKey(postId));
    await prefs.setStringList(
      _cachedPostIdsKey,
      postIds.where((id) => id != postId).toList(),
    );
  }

  Future<void> clearCachedPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final postIds = prefs.getStringList(_cachedPostIdsKey) ?? const [];
    for (final postId in postIds) {
      await prefs.remove(_cachedPostKey(postId));
    }
    await prefs.remove(_cachedPostIdsKey);
  }

  Future<Set<String>> loadLikedPostIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_likedPostIdsKey)?.toSet() ?? <String>{};
  }

  Future<void> saveLikedPostIds(Set<String> postIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_likedPostIdsKey, _cleanIds(postIds));
  }

  Future<Set<String>> toggleLikedPostId(String postId) async {
    final postIds = await loadLikedPostIds();
    if (postIds.contains(postId)) {
      postIds.remove(postId);
    } else if (postId.trim().isNotEmpty) {
      postIds.add(postId.trim());
    }
    await saveLikedPostIds(postIds);
    return postIds;
  }

  Future<String?> loadLastSeenLatestPostName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastSeenLatestPostNameKey);
  }

  Future<void> saveLastSeenLatestPostName(String? postName) async {
    final prefs = await SharedPreferences.getInstance();
    final value = postName?.trim();
    if (value == null || value.isEmpty) {
      await prefs.remove(_lastSeenLatestPostNameKey);
      return;
    }
    await prefs.setString(_lastSeenLatestPostNameKey, value);
  }
}

String _cachedPostKey(String postId) => 'blog.cachedPost.$postId';

List<String> _cleanIds(Iterable<String> values) => _cleanStrings(values);

List<String> _cleanStrings(Iterable<String> values) {
  final seen = <String>{};
  final clean = <String>[];

  for (final value in values) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || seen.contains(trimmed)) continue;
    seen.add(trimmed);
    clean.add(trimmed);
  }

  return clean;
}

List<String> _moveToFront(
  Iterable<String> values,
  String value, {
  bool caseInsensitive = false,
}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return _cleanStrings(values);
  final normalized = caseInsensitive ? trimmed.toLowerCase() : trimmed;
  return [
    trimmed,
    ...values.where((item) {
      final compare = caseInsensitive ? item.trim().toLowerCase() : item.trim();
      return compare.isNotEmpty && compare != normalized;
    }),
  ];
}

Post? _decodePost(String? value) {
  if (value == null || value.isEmpty) return null;
  try {
    final json = jsonDecode(value);
    if (json is! Map<String, dynamic>) return null;
    return Post.fromJson(json);
  } catch (_) {
    return null;
  }
}
