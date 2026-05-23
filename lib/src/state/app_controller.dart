import 'package:flutter/material.dart';

import '../api/binary_coffee_api.dart';
import '../models/podcast_episode.dart';
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
  final List<Post> topViewedPosts = [];
  final List<Post> topCommentedPosts = [];
  final List<Post> topLikedPosts = [];
  final List<PodcastEpisode> podcastEpisodes = [];
  final List<Post> cachedPosts = [];
  final List<String> recentSearches = [];
  final List<String> readHistoryPostIds = [];
  final Set<String> favoritePostIds = {};
  final Set<String> likedPostIds = {};
  UserSession? session;
  bool initialized = false;
  bool loading = false;
  bool loadingMore = false;
  bool loadingPodcasts = false;
  bool hasMore = true;
  bool darkMode = true;
  bool notificationsEnabled = true;
  String languageCode = 'en';
  String search = '';
  String selectedTag = '';
  final Set<String> selectedTags = {};
  String? authorId;
  String? authorName;
  String? error;
  String? podcastError;
  String? newPostName;

  Future<void> init() async {
    darkMode = await store.loadDarkMode();
    notificationsEnabled = await store.loadNotifications();
    languageCode = await store.loadLanguageCode();
    session = await store.load();
    favoritePostIds
      ..clear()
      ..addAll(await store.loadFavoritePostIds());
    likedPostIds
      ..clear()
      ..addAll(await store.loadLikedPostIds());
    readHistoryPostIds
      ..clear()
      ..addAll(await store.loadReadHistoryPostIds());
    recentSearches
      ..clear()
      ..addAll(await store.loadRecentSearches());
    cachedPosts
      ..clear()
      ..addAll(await store.loadCachedPosts());
    initialized = true;
    notifyListeners();
    await Future.wait([loadTags(), refresh(), loadHighlights()]);
  }

  Future<void> loadPodcasts() async {
    if (podcastEpisodes.isNotEmpty || loadingPodcasts) return;
    loadingPodcasts = true;
    podcastError = null;
    notifyListeners();
    try {
      podcastEpisodes
        ..clear()
        ..addAll(await api.getEspacioBinarioEpisodes());
    } catch (e) {
      podcastError = e.toString();
    } finally {
      loadingPodcasts = false;
      notifyListeners();
    }
  }

  Future<void> refreshPodcasts() async {
    podcastEpisodes.clear();
    await loadPodcasts();
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
    await _detectNewPost();
  }

  Future<void> loadHighlights() async {
    try {
      final results = await Future.wait([
        api.getTopPosts(metric: 'views'),
        api.getTopPosts(metric: 'comments'),
        api.getTopPosts(metric: 'likes'),
      ]);
      topViewedPosts
        ..clear()
        ..addAll(results[0]);
      topCommentedPosts
        ..clear()
        ..addAll(results[1]);
      topLikedPosts
        ..clear()
        ..addAll(results[2]);
      notifyListeners();
    } catch (_) {}
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
        tags: selectedTags.toList(),
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

  Future<void> setSearch(String value) async {
    search = value;
    if (value.trim().isNotEmpty) {
      recentSearches
        ..clear()
        ..addAll(await store.addRecentSearch(value.trim()));
    }
    await refresh();
  }

  void toggleTag(String tag) {
    selectedTag = selectedTag == tag ? '' : tag;
    selectedTags
      ..clear()
      ..addAll(selectedTag.isEmpty ? const [] : [selectedTag]);
    authorId = null;
    authorName = null;
    refresh();
  }

  void toggleAdvancedTag(String tag) {
    selectedTag = '';
    if (selectedTags.contains(tag)) {
      selectedTags.remove(tag);
    } else {
      selectedTags.add(tag);
    }
    authorId = null;
    authorName = null;
    refresh();
  }

  void clearTags() {
    selectedTag = '';
    selectedTags.clear();
    refresh();
  }

  void filterByAuthor(Author author) {
    authorId = author.id;
    authorName = author.username;
    search = '';
    selectedTag = '';
    selectedTags.clear();
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

  Future<void> setLanguageCode(String value) async {
    languageCode = value == 'es' ? 'es' : 'en';
    notifyListeners();
    await store.saveLanguageCode(languageCode);
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
    if (likedPostIds.contains(post.id)) {
      await api.unlikePost(post.id, jwt);
      likedPostIds.remove(post.id);
    } else {
      await api.likePost(post.id, jwt);
      likedPostIds.add(post.id);
    }
    await store.saveLikedPostIds(likedPostIds);
    await refresh();
  }

  Future<void> toggleFavorite(Post post) async {
    await store.cacheOpenedPost(post);
    favoritePostIds
      ..clear()
      ..addAll(await store.toggleFavoritePostId(post.id));
    cachedPosts
      ..clear()
      ..addAll(await store.loadCachedPosts());
    notifyListeners();
  }

  Future<void> markOpened(Post post) async {
    readHistoryPostIds
      ..clear()
      ..addAll(await store.markPostRead(post.id));
    await store.cacheOpenedPost(post);
    cachedPosts
      ..clear()
      ..addAll(await store.loadCachedPosts());
    notifyListeners();
  }

  Future<Post?> getPostDetail(Post post) async {
    final cached = await store.loadCachedPost(post.id);
    try {
      final detail = await api.getPostByName(post.name);
      if (detail != null) {
        await store.cacheOpenedPost(detail);
        cachedPosts
          ..clear()
          ..addAll(await store.loadCachedPosts());
        notifyListeners();
      }
      return detail ?? cached ?? post;
    } catch (_) {
      return cached ?? post;
    }
  }

  List<Post> get favoritePosts => [
    for (final post in [...posts, ...cachedPosts])
      if (favoritePostIds.contains(post.id)) post,
  ];

  List<Post> get readHistoryPosts => [
    for (final id in readHistoryPostIds)
      for (final post in [...posts, ...cachedPosts])
        if (post.id == id) post,
  ];

  Future<void> _detectNewPost() async {
    if (posts.isEmpty) return;
    final latest = posts.first.name;
    final lastSeen = await store.loadLastSeenLatestPostName();
    if (lastSeen != null && lastSeen != latest) {
      newPostName = latest;
    } else {
      newPostName = null;
    }
    await store.saveLastSeenLatestPostName(latest);
    notifyListeners();
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
