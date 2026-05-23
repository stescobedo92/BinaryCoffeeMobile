import 'package:flutter/material.dart';

import '../api/binary_coffee_api.dart';
import '../models/post.dart';
import '../models/user_session.dart';
import 'session_store.dart';

class AppController extends ChangeNotifier {
  AppController({BinaryCoffeeApi? api, SessionStore? store})
    : api = api ?? BinaryCoffeeApi(),
      store = store ?? SessionStore();

  final BinaryCoffeeApi api;
  final SessionStore store;

  final int pageSize = 10;
  final List<Post> posts = [];
  final List<Tag> tags = [];
  UserSession? session;
  bool initialized = false;
  bool loading = false;
  bool loadingMore = false;
  bool hasMore = true;
  bool darkMode = false;
  bool notificationsEnabled = true;
  String search = '';
  String selectedTag = '';
  String? authorId;
  String? authorName;
  String? error;

  Future<void> init() async {
    darkMode = await store.loadDarkMode();
    notificationsEnabled = await store.loadNotifications();
    session = await store.load();
    initialized = true;
    notifyListeners();
    await Future.wait([loadTags(), refresh()]);
  }

  Future<void> loadTags() async {
    try {
      tags
        ..clear()
        ..addAll(await api.getTags());
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refresh() async {
    posts.clear();
    hasMore = true;
    error = null;
    await _load(start: 0);
  }

  Future<void> loadMore() async {
    if (!hasMore || loading || loadingMore) return;
    await _load(start: posts.length, more: true);
  }

  Future<void> _load({required int start, bool more = false}) async {
    loading = !more;
    loadingMore = more;
    notifyListeners();
    try {
      final next = await api.getPosts(
        limit: pageSize,
        start: start,
        search: search,
        tag: selectedTag,
        authorId: authorId ?? '',
      );
      posts.addAll(next);
      hasMore = next.length >= pageSize;
      error = null;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      loadingMore = false;
      notifyListeners();
    }
  }

  void setSearch(String value) {
    search = value;
    refresh();
  }

  void toggleTag(String tag) {
    selectedTag = selectedTag == tag ? '' : tag;
    authorId = null;
    authorName = null;
    refresh();
  }

  void filterByAuthor(Author author) {
    authorId = author.id;
    authorName = author.username;
    search = '';
    selectedTag = '';
    refresh();
  }

  void clearAuthorFilter() {
    authorId = null;
    authorName = null;
    refresh();
  }

  Future<void> setDarkMode(bool value) async {
    darkMode = value;
    notifyListeners();
    await store.saveDarkMode(value);
  }

  Future<void> setNotifications(bool value) async {
    notificationsEnabled = value;
    notifyListeners();
    await store.saveNotifications(value);
  }

  Future<void> loginWithJwt(String jwt) async {
    session = await api.getMe(jwt);
    await store.save(session!);
    notifyListeners();
  }

  Future<bool> handleAuthRedirect(Uri uri) async {
    if (uri.scheme != 'binarycoffee' || uri.host != 'auth') return false;
    final fragmentParams = Uri.splitQueryString(uri.fragment);
    final token = uri.queryParameters['token'] ?? fragmentParams['token'];
    if (token == null || token.isEmpty) return false;
    await loginWithJwt(token);
    return true;
  }

  Future<void> logout() async {
    session = null;
    await store.clear();
    notifyListeners();
  }

  Future<void> like(Post post) async {
    final jwt = session?.jwt;
    if (jwt == null) return;
    await api.likePost(post.id, jwt);
    await refresh();
  }

  Future<void> comment(Post post, String body) async {
    final jwt = session?.jwt;
    if (jwt == null) return;
    await api.createComment(post.id, body, jwt);
  }

  Future<void> createDraft(String title, String body) async {
    final jwt = session?.jwt;
    if (jwt == null) return;
    await api.createDraft(title, body, jwt);
  }

  Future<void> subscribe() async {
    final user = session;
    if (user?.jwt == null || user?.email == null) return;
    await api.subscribe(user!.email!, user.jwt);
  }
}
