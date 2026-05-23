import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'src/api/binary_coffee_api.dart';
import 'src/models/post.dart';
import 'src/state/app_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  runApp(BinaryCoffeeApp(controller: AppController()..init()));
}

class BinaryCoffeeApp extends StatelessWidget {
  const BinaryCoffeeApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final lightScheme = ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        );
        final darkScheme = ColorScheme.fromSeed(
          seedColor: AppColors.primaryDark,
          brightness: Brightness.dark,
        );
        return MaterialApp(
          title: 'Binary Coffee',
          debugShowCheckedModeBanner: false,
          themeMode: controller.darkMode ? ThemeMode.dark : ThemeMode.light,
          theme: _theme(lightScheme),
          darkTheme: _theme(darkScheme, dark: true),
          home: HomeScreen(controller: controller),
        );
      },
    );
  }

  ThemeData _theme(ColorScheme scheme, {bool dark = false}) {
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: 'FiraCode',
      scaffoldBackgroundColor: dark ? AppColors.darkBg : AppColors.lightBg,
      cardTheme: CardThemeData(
        elevation: 0,
        color: dark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: dark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        side: BorderSide.none,
        labelStyle: TextStyle(
          color: dark ? AppColors.primaryDark : AppColors.primary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
        isDense: true,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: dark ? AppColors.darkChrome : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: Border(
          bottom: BorderSide(
            color: dark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? AppColors.darkChrome : Colors.white,
        indicatorColor: scheme.primary.withValues(alpha: .16),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: dark ? AppColors.darkChrome : Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  StreamSubscription<Uri>? _linkSubscription;
  Timer? _debounce;
  int _tabIndex = 0;

  AppController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >
          _scrollController.position.maxScrollExtent - 320) {
        controller.loadMore();
      }
    });
    _listenForAuthLinks();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _linkSubscription?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final width = MediaQuery.sizeOf(context).width;
        final wide = width >= 840;
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 12,
            title: Row(
              children: [
                Image.asset(
                  'assets/images/title_icon.png',
                  height: 28,
                  width: 28,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 8),
                Text(
                  'Binary Coffee',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: controller.darkMode ? 'Modo claro' : 'Modo oscuro',
                onPressed: () => controller.setDarkMode(!controller.darkMode),
                icon: Icon(
                  controller.darkMode
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                ),
              ),
              IconButton(
                tooltip: 'Perfil',
                onPressed: () => _openProfile(context),
                icon: controller.session?.avatarUrl == null
                    ? const Icon(Icons.person_outline)
                    : CircleAvatar(
                        radius: 13,
                        backgroundImage: NetworkImage(
                          controller.session!.avatarUrl!,
                        ),
                      ),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: controller.refresh,
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                if (_tabIndex == 0) ..._homeSlivers(context, wide),
                if (_tabIndex == 1)
                  _savedSliver(
                    context,
                    title: 'Guardados',
                    posts: controller.favoritePosts,
                    empty: 'Guarda articulos para leerlos despues.',
                  ),
                if (_tabIndex == 2)
                  _savedSliver(
                    context,
                    title: 'Historial',
                    posts: controller.readHistoryPosts,
                    empty: 'Los articulos que abras apareceran aqui.',
                  ),
                if (_tabIndex == 3)
                  _savedSliver(
                    context,
                    title: 'Offline',
                    posts: controller.cachedPosts,
                    empty: 'Abre articulos para dejarlos disponibles offline.',
                  ),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tabIndex,
            onDestinationSelected: (value) => setState(() => _tabIndex = value),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dynamic_feed_outlined),
                selectedIcon: Icon(Icons.dynamic_feed),
                label: 'Inicio',
              ),
              NavigationDestination(
                icon: Icon(Icons.bookmark_border),
                selectedIcon: Icon(Icons.bookmark),
                label: 'Guardados',
              ),
              NavigationDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: 'Historial',
              ),
              NavigationDestination(
                icon: Icon(Icons.offline_pin_outlined),
                selectedIcon: Icon(Icons.offline_pin),
                label: 'Offline',
              ),
            ],
          ),
          floatingActionButton: controller.session == null
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _openDraft(context),
                  icon: const Icon(Icons.edit_note_outlined),
                  label: const Text('Borrador'),
                ),
        );
      },
    );
  }

  List<Widget> _homeSlivers(BuildContext context, bool wide) => [
    SliverToBoxAdapter(
      child: _Header(
        controller: controller,
        searchController: _searchController,
        onSearch: _onSearchChanged,
        onFilters: () => _openFilters(context),
      ),
    ),
    if (controller.newPostName != null)
      SliverToBoxAdapter(
        child: _Constrained(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: FilledButton.tonalIcon(
              onPressed: controller.refresh,
              icon: const Icon(Icons.fiber_new_outlined),
              label: const Text('Hay articulos nuevos'),
            ),
          ),
        ),
      ),
    if (controller.authorName != null)
      SliverToBoxAdapter(
        child: _Constrained(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: MaterialBanner(
              content: Text('Posts de ${controller.authorName}'),
              leading: const Icon(Icons.person_search_outlined),
              actions: [
                TextButton(
                  onPressed: controller.clearAuthorFilter,
                  child: const Text('Limpiar'),
                ),
              ],
            ),
          ),
        ),
      ),
    if (controller.search.isEmpty &&
        controller.selectedTags.isEmpty &&
        controller.authorName == null)
      SliverToBoxAdapter(
        child: _Constrained(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Column(
              children: [
                _HighlightRail(
                  title: 'Mas vistos',
                  posts: controller.topViewedPosts,
                  onOpen: (post) => _openPost(context, post),
                ),
                _HighlightRail(
                  title: 'Mas comentados',
                  posts: controller.topCommentedPosts,
                  onOpen: (post) => _openPost(context, post),
                ),
                _HighlightRail(
                  title: 'Mas gustados',
                  posts: controller.topLikedPosts,
                  onOpen: (post) => _openPost(context, post),
                ),
              ],
            ),
          ),
        ),
      ),
    if (controller.loading && controller.posts.isEmpty)
      const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      ),
    if (controller.error != null && controller.posts.isEmpty)
      SliverFillRemaining(
        child: _ErrorState(message: controller.error!, onRetry: controller.refresh),
      ),
    if (!controller.loading || controller.posts.isNotEmpty)
      SliverPadding(
        padding: EdgeInsets.fromLTRB(wide ? 24 : 12, 12, wide ? 24 : 12, 12),
        sliver: SliverList.builder(
          itemCount: controller.posts.length + 1,
          itemBuilder: (context, index) {
            if (index == controller.posts.length) {
              return _LoadMore(controller: controller);
            }
            final post = controller.posts[index];
            return _Constrained(
              child: PostCard(
                post: post,
                index: index + 1,
                signedIn: controller.session != null,
                favorite: controller.favoritePostIds.contains(post.id),
                liked: controller.likedPostIds.contains(post.id),
                onAuthor: (author) => _openAuthor(context, author),
                onLike: () => _guarded(context, () => controller.like(post)),
                onFavorite: () => controller.toggleFavorite(post),
                onShare: () => _share(post),
                onOpen: () => _openPost(context, post),
              ),
            );
          },
        ),
      ),
  ];

  Widget _savedSliver(
    BuildContext context, {
    required String title,
    required List<Post> posts,
    required String empty,
  }) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 88),
      sliver: posts.isEmpty
          ? SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyLibrary(title: title, message: empty),
            )
          : SliverList.builder(
              itemCount: posts.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _Constrained(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  );
                }
                final post = posts[index - 1];
                return _Constrained(
                  child: PostCard(
                    post: post,
                    index: index,
                    signedIn: controller.session != null,
                    favorite: controller.favoritePostIds.contains(post.id),
                    liked: controller.likedPostIds.contains(post.id),
                    onAuthor: (author) => _openAuthor(context, author),
                    onLike: () => _guarded(context, () => controller.like(post)),
                    onFavorite: () => controller.toggleFavorite(post),
                    onShare: () => _share(post),
                    onOpen: () => _openPost(context, post),
                  ),
                );
              },
            ),
    );
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 420),
      () => controller.setSearch(value),
    );
  }

  void _listenForAuthLinks() {
    final appLinks = AppLinks();
    appLinks.getInitialLink().then(_handleAuthLink);
    _linkSubscription = appLinks.uriLinkStream.listen(_handleAuthLink);
  }

  Future<void> _handleAuthLink(Uri? uri) async {
    if (uri == null) return;
    final handled = await controller.handleAuthRedirect(uri);
    if (handled && mounted) {
      Navigator.of(context).maybePop();
      _snack(context, 'Sesion iniciada con GitHub');
      return;
    }
    final name = _postNameFromUri(uri);
    if (name == null || !mounted) return;
    try {
      final post = await controller.api.getPostByName(name);
      if (post != null && mounted) _openPost(context, post);
    } catch (_) {}
  }

  String? _postNameFromUri(Uri uri) {
    if (uri.scheme == 'binarycoffee' && uri.host == 'post') {
      return uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
    }
    if (uri.host == 'binarycoffee.dev' &&
        uri.pathSegments.length >= 2 &&
        uri.pathSegments.first == 'post') {
      return uri.pathSegments[1];
    }
    return null;
  }

  Future<void> _guarded(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    if (controller.session == null) {
      _openProfile(context);
      return;
    }
    try {
      await action();
    } catch (e) {
      if (context.mounted) _snack(context, e.toString());
    }
  }

  void _openProfile(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ProfileSheet(controller: controller),
    );
  }

  void _openFilters(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => FilterSheet(controller: controller),
    );
  }

  void _openDraft(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DraftSheet(controller: controller),
    );
  }

  void _openPost(BuildContext context, Post post) {
    controller.markOpened(post);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(controller: controller, post: post),
      ),
    );
  }

  void _openAuthor(BuildContext context, Author author) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AuthorDetailScreen(controller: controller, author: author),
      ),
    );
  }

  Future<void> _share(Post post) async {
    await SharePlus.instance.share(
      ShareParams(
        text: '${post.title}\n${BinaryCoffeeApi.siteUrl}/post/${post.name}',
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    required this.searchController,
    required this.onSearch,
    required this.onFilters,
  });

  final AppController controller;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;
  final VoidCallback onFilters;

  @override
  Widget build(BuildContext context) {
    return _Constrained(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                color: controller.selectedTag.isEmpty
                        && controller.selectedTags.isEmpty
                    ? Theme.of(context).dividerColor.withValues(alpha: .35)
                    : Theme.of(context).colorScheme.primary,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .08),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Buscar articulos',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  suffixIcon: IconButton(
                    tooltip: 'Filtros',
                    onPressed: onFilters,
                    icon: Badge(
                      isLabelVisible: controller.selectedTag.isNotEmpty,
                      smallSize: 8,
                      child: const Icon(Icons.tune_rounded),
                    ),
                  ),
                ),
                onChanged: onSearch,
              ),
            ),
            if (controller.selectedTag.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: InputChip(
                  label: Text(controller.selectedTag),
                  avatar: const Icon(Icons.sell_outlined, size: 16),
                  onDeleted: () => controller.toggleTag(controller.selectedTag),
                ),
              ),
            if (controller.selectedTags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final tag in controller.selectedTags)
                      InputChip(
                        label: Text(tag),
                        avatar: const Icon(Icons.sell_outlined, size: 16),
                        onDeleted: () => controller.toggleAdvancedTag(tag),
                      ),
                  ],
                ),
              ),
            if (controller.recentSearches.isNotEmpty && controller.search.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: controller.recentSearches.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final search = controller.recentSearches[index];
                      return ActionChip(
                        avatar: const Icon(Icons.history, size: 15),
                        label: Text(search),
                        onPressed: () {
                          searchController.text = search;
                          onSearch(search);
                        },
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class FilterSheet extends StatelessWidget {
  const FilterSheet({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Filtrar por tag',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (controller.selectedTag.isNotEmpty ||
                    controller.selectedTags.isNotEmpty)
                  TextButton(
                    onPressed: controller.clearTags,
                    child: const Text('Limpiar'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Flexible(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: controller.tags.map((tag) {
                    final selected = controller.selectedTag == tag.name;
                    return FilterChip(
                      selected: selected || controller.selectedTags.contains(tag.name),
                      label: Text(tag.name),
                      onSelected: (_) {
                        controller.toggleAdvancedTag(tag.name);
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightRail extends StatelessWidget {
  const _HighlightRail({
    required this.title,
    required this.posts,
    required this.onOpen,
  });

  final String title;
  final List<Post> posts;
  final ValueChanged<Post> onOpen;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: posts.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final post = posts[index];
              return SizedBox(
                width: 250,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onOpen(post),
                  child: Ink(
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).dividerColor.withValues(alpha: .35),
                      ),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '#${index + 1}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          post.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            _Metric(icon: Icons.visibility_outlined, label: '${post.views}'),
                            const SizedBox(width: 10),
                            _Metric(icon: Icons.chat_bubble_outline, label: '${post.comments}'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.title, required this.message});
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _Constrained(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_library_outlined,
                size: 42,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.index,
    required this.signedIn,
    required this.favorite,
    required this.liked,
    required this.onAuthor,
    required this.onLike,
    required this.onFavorite,
    required this.onShare,
    required this.onOpen,
  });

  final Post post;
  final int index;
  final bool signedIn;
  final bool favorite;
  final bool liked;
  final ValueChanged<Author> onAuthor;
  final VoidCallback onLike;
  final VoidCallback onFavorite;
  final VoidCallback onShare;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              constraints: const BoxConstraints(minHeight: 120),
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.10),
              alignment: Alignment.topCenter,
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                '$index',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (post.bannerUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: CachedNetworkImage(
                          imageUrl: post.bannerUrl!,
                          height: 82,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, _) => _FallbackBanner(),
                          errorWidget: (_, _, _) => _FallbackBanner(),
                        ),
                      ),
                    if (post.bannerUrl != null) const SizedBox(height: 8),
                    Text(
                      post.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 9,
                          backgroundImage: NetworkImage(
                            post.author.avatarUrl ??
                                'https://github.com/${post.author.username}.png?size=64',
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => onAuthor(post.author),
                          child: Text(
                            post.author.username,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            DateFormat.yMMMd('es').format(post.publishedAt),
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _excerpt(post.body),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _Metric(
                          icon: Icons.visibility_outlined,
                          label: '${post.views}',
                        ),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: signedIn ? onLike : null,
                          child: _Metric(
                            icon: liked ? Icons.favorite : Icons.favorite_border,
                            label: '${post.likes}',
                            faded: !signedIn,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _Metric(
                          icon: Icons.chat_bubble_outline,
                          label: '${post.comments}',
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: favorite ? 'Quitar guardado' : 'Guardar',
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            favorite ? Icons.bookmark : Icons.bookmark_border,
                            size: 18,
                          ),
                          onPressed: onFavorite,
                        ),
                        IconButton(
                          tooltip: 'Compartir',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.ios_share_outlined, size: 18),
                          onPressed: onShare,
                        ),
                        IconButton.filledTonal(
                          tooltip: 'Abrir en binarycoffee.dev',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.open_in_new, size: 16),
                          onPressed: () => launchUrl(
                            Uri.parse(
                              '${BinaryCoffeeApi.siteUrl}/post/${post.name}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({
    super.key,
    required this.controller,
    required this.post,
  });

  final AppController controller;
  final Post post;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late Future<Post?> _future = widget.controller.getPostDetail(widget.post);
  final _commentController = TextEditingController();
  bool _readingMode = false;
  double _fontSize = 15;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Articulo'),
        actions: [
          IconButton(
            tooltip: _readingMode ? 'Vista normal' : 'Modo lectura',
            onPressed: () => setState(() => _readingMode = !_readingMode),
            icon: Icon(_readingMode ? Icons.view_agenda : Icons.menu_book_outlined),
          ),
          IconButton(
            tooltip: 'Compartir',
            onPressed: () => SharePlus.instance.share(
              ShareParams(
                text:
                    '${widget.post.title}\n${BinaryCoffeeApi.siteUrl}/post/${widget.post.name}',
              ),
            ),
            icon: const Icon(Icons.ios_share_outlined),
          ),
          IconButton(
            onPressed: () => launchUrl(
              Uri.parse('${BinaryCoffeeApi.siteUrl}/post/${widget.post.name}'),
            ),
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
      body: FutureBuilder<Post?>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            if (snapshot.hasError) {
              return _ErrorState(
                message: snapshot.error.toString(),
                onRetry: () => setState(() {
                  _future = widget.controller.api.getPostByName(
                    widget.post.name,
                  );
                }),
              );
            }
            return const Center(child: CircularProgressIndicator());
          }
          final post = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Constrained(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_readingMode && post.bannerUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: CachedNetworkImage(
                          imageUrl: post.bannerUrl!,
                          height: 190,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => _FallbackBanner(),
                        ),
                      ),
                    const SizedBox(height: 14),
                    Text(
                      post.title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${post.author.username} · ${post.readingTime ?? 0} min lectura · ${DateFormat.yMMMd('es').format(post.publishedAt)}',
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      children: [
                        _Metric(
                          icon: Icons.visibility_outlined,
                          label: '${post.views}',
                        ),
                        _Metric(
                          icon: Icons.favorite_border,
                          label: '${post.likes}',
                        ),
                        _Metric(
                          icon: Icons.chat_bubble_outline,
                          label: '${post.comments}',
                        ),
                      ],
                    ),
                    if (_readingMode) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.format_size, size: 18),
                          Expanded(
                            child: Slider(
                              min: 13,
                              max: 21,
                              divisions: 8,
                              value: _fontSize,
                              onChanged: (value) =>
                                  setState(() => _fontSize = value),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Divider(height: 28),
                    MarkdownBody(
                      data: post.body,
                      styleSheet: MarkdownStyleSheet.fromTheme(
                        Theme.of(context),
                      ).copyWith(
                        p: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: _fontSize,
                          height: _readingMode ? 1.62 : 1.42,
                        ),
                      ),
                    ),
                    const Divider(height: 32),
                    Text(
                      'Comentarios (${post.commentsList.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (post.commentsList.isEmpty)
                      const Text('Sin comentarios aun'),
                    ...post.commentsList.map(
                      (comment) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(
                            comment.author.avatarUrl ??
                                'https://github.com/${comment.author.username}.png?size=64',
                          ),
                        ),
                        title: Text(comment.author.username),
                        subtitle: Text(comment.body),
                      ),
                    ),
                    if (widget.controller.session != null) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _commentController,
                        minLines: 2,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          hintText: 'Escribe un comentario',
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () async {
                          final body = _commentController.text.trim();
                          if (body.isEmpty) return;
                          await widget.controller.comment(post, body);
                          _commentController.clear();
                          setState(
                            () => _future = widget.controller.getPostDetail(
                              widget.post,
                            ),
                          );
                        },
                        icon: const Icon(Icons.send_outlined),
                        label: const Text('Comentar'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class AuthorDetailScreen extends StatefulWidget {
  const AuthorDetailScreen({
    super.key,
    required this.controller,
    required this.author,
  });

  final AppController controller;
  final Author author;

  @override
  State<AuthorDetailScreen> createState() => _AuthorDetailScreenState();
}

class _AuthorDetailScreenState extends State<AuthorDetailScreen> {
  late Future<List<Post>> _future = widget.controller.api.getAuthorPosts(
    widget.author.id,
  );

  @override
  Widget build(BuildContext context) {
    final isMe = widget.controller.session?.id == widget.author.id;
    final session = widget.controller.session;
    return Scaffold(
      appBar: AppBar(
        title: Text(isMe ? 'Mi perfil' : widget.author.username),
        actions: [
          IconButton(
            tooltip: 'Filtrar posts',
            icon: const Icon(Icons.filter_alt_outlined),
            onPressed: () {
              widget.controller.filterByAuthor(widget.author);
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Post>>(
        future: _future,
        builder: (context, snapshot) {
          final posts = snapshot.data ?? const <Post>[];
          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _future = widget.controller.api.getAuthorPosts(
                  widget.author.id,
                );
              });
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                _Constrained(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 34,
                            backgroundImage: NetworkImage(
                              widget.author.avatarUrl ??
                                  'https://github.com/${widget.author.username}.png?size=128',
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.author.username,
                                  style: Theme.of(context).textTheme.headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                if (isMe && session != null)
                                  Text(
                                    [
                                      if (session.email != null) session.email!,
                                      if (session.roleName != null) session.roleName!,
                                      if (session.confirmed == true) 'confirmado',
                                    ].join(' · '),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          _StatPill(label: 'Posts', value: '${posts.length}'),
                          const SizedBox(width: 8),
                          _StatPill(
                            label: 'Views',
                            value:
                                '${posts.fold<int>(0, (sum, post) => sum + post.views)}',
                          ),
                          const SizedBox(width: 8),
                          _StatPill(
                            label: 'Likes',
                            value:
                                '${posts.fold<int>(0, (sum, post) => sum + post.likes)}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (snapshot.hasError)
                  _ErrorState(
                    message: snapshot.error.toString(),
                    onRetry: () => setState(() {
                      _future = widget.controller.api.getAuthorPosts(
                        widget.author.id,
                      );
                    }),
                  ),
                for (var i = 0; i < posts.length; i++)
                  _Constrained(
                    child: PostCard(
                      post: posts[i],
                      index: i + 1,
                      signedIn: widget.controller.session != null,
                      favorite: widget.controller.favoritePostIds.contains(
                        posts[i].id,
                      ),
                      liked: widget.controller.likedPostIds.contains(posts[i].id),
                      onAuthor: (_) {},
                      onLike: () => widget.controller.like(posts[i]),
                      onFavorite: () => widget.controller.toggleFavorite(posts[i]),
                      onShare: () => SharePlus.instance.share(
                        ShareParams(
                          text:
                              '${posts[i].title}\n${BinaryCoffeeApi.siteUrl}/post/${posts[i].name}',
                        ),
                      ),
                      onOpen: () {
                        widget.controller.markOpened(posts[i]);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PostDetailScreen(
                              controller: widget.controller,
                              post: posts[i],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileSheet extends StatefulWidget {
  const ProfileSheet({super.key, required this.controller});

  final AppController controller;

  @override
  State<ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<ProfileSheet> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final session = widget.controller.session;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) => ListView(
          shrinkWrap: true,
          children: [
            if (session != null) ...[
              ListTile(
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(
                    session.avatarUrl ??
                        'https://github.com/${session.username}.png?size=96',
                  ),
                ),
                title: Text(session.username),
                subtitle: Text(
                  [
                    if (session.email != null) session.email!,
                    if (session.roleName != null) session.roleName!,
                    if (session.confirmed == true) 'confirmado',
                  ].join(' · '),
                ),
              ),
              SwitchListTile(
                value: widget.controller.notificationsEnabled,
                onChanged: widget.controller.setNotifications,
                title: const Text('Notificaciones locales'),
                secondary: const Icon(Icons.notifications_outlined),
              ),
              ListTile(
                leading: const Icon(Icons.article_outlined),
                title: const Text('Mis posts'),
                onTap: () => _openMyPosts(context),
              ),
              ListTile(
                leading: const Icon(Icons.query_stats_outlined),
                title: const Text('Estadisticas'),
                onTap: () => _openStats(context),
              ),
              ListTile(
                leading: const Icon(Icons.mail_outline),
                title: const Text('Suscribirme'),
                onTap: () => _run(() => widget.controller.subscribe()),
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Cerrar sesion'),
                onTap: () => widget.controller.logout(),
              ),
            ] else ...[
              Text(
                'Iniciar sesion',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'Continua con tu cuenta para comentar, dar like y crear borradores.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _busy
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        try {
                          if (!mounted) return;
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              fullscreenDialog: true,
                              builder: (_) => GitHubAuthScreen(
                                controller: widget.controller,
                              ),
                            ),
                          );
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                icon: const FaIcon(FontAwesomeIcons.github),
                label: const Text('Continuar con GitHub'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) _snack(context, 'Listo');
    } catch (e) {
      if (mounted) _snack(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openMyPosts(BuildContext context) {
    Navigator.pop(context);
    widget.controller.filterByAuthor(
      Author(
        id: widget.controller.session!.id,
        username: widget.controller.session!.username,
      ),
    );
  }

  void _openStats(BuildContext context) {
    final posts = widget.controller.posts
        .where((post) => post.author.id == widget.controller.session?.id)
        .toList();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Estadisticas'),
        content: Text(
          'Posts cargados: ${posts.length}\nViews: ${posts.fold<int>(0, (s, p) => s + p.views)}\nLikes: ${posts.fold<int>(0, (s, p) => s + p.likes)}\nComentarios: ${posts.fold<int>(0, (s, p) => s + p.comments)}',
        ),
      ),
    );
  }
}

class GitHubAuthScreen extends StatefulWidget {
  const GitHubAuthScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<GitHubAuthScreen> createState() => _GitHubAuthScreenState();
}

class _GitHubAuthScreenState extends State<GitHubAuthScreen> {
  late final WebViewController _webViewController;
  late final WebViewWidget _webView;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
          onNavigationRequest: (request) {
            final uri = Uri.parse(request.url);
            if (uri.scheme == 'binarycoffee' && uri.host == 'auth') {
              _finish(uri);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(widget.controller.api.githubAuthorizeUri());
    _webView = _buildWebView();
  }

  WebViewWidget _buildWebView() {
    var params = PlatformWebViewWidgetCreationParams(
      controller: _webViewController.platform,
    );
    params = AndroidWebViewWidgetCreationParams
        .fromPlatformWebViewWidgetCreationParams(
      params,
      displayWithHybridComposition: true,
    );
    return WebViewWidget.fromPlatformCreationParams(params: params);
  }

  Future<void> _finish(Uri uri) async {
    try {
      final handled = await widget.controller.handleAuthRedirect(uri);
      if (!mounted) return;
      if (handled) {
        Navigator.of(context).pop();
        Navigator.of(context).maybePop();
        _snack(context, 'Sesion iniciada con GitHub');
      }
    } catch (e) {
      if (mounted) _snack(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GitHub'),
        leading: IconButton(
          tooltip: 'Cerrar',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
      ),
      body: Stack(
        children: [
          _webView,
          if (_loading) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}

class DraftSheet extends StatefulWidget {
  const DraftSheet({super.key, required this.controller});
  final AppController controller;
  @override
  State<DraftSheet> createState() => _DraftSheetState();
}

class _DraftSheetState extends State<DraftSheet> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  bool _busy = false;
  bool _preview = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text('Crear borrador', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Titulo'),
          ),
          const SizedBox(height: 10),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                icon: Icon(Icons.edit_outlined),
                label: Text('Editar'),
              ),
              ButtonSegment(
                value: true,
                icon: Icon(Icons.preview_outlined),
                label: Text('Preview'),
              ),
            ],
            selected: {_preview},
            onSelectionChanged: (value) =>
                setState(() => _preview = value.first),
          ),
          const SizedBox(height: 10),
          if (_preview)
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: MarkdownBody(data: _body.text),
              ),
            )
          else
            TextField(
              controller: _body,
              minLines: 8,
              maxLines: 14,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Contenido Markdown',
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      await widget.controller.createDraft(
                        _title.text.trim(),
                        _body.text.trim(),
                      );
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) _snack(context, e.toString());
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            icon: const Icon(Icons.save_outlined),
            label: const Text('Crear borrador'),
          ),
        ],
      ),
    );
  }
}

class _LoadMore extends StatelessWidget {
  const _LoadMore({required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    if (controller.loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!controller.hasMore) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: Text('No hay mas articulos')),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 80),
      child: Center(
        child: FilledButton.tonal(
          onPressed: controller.loadMore,
          child: const Text('Cargar mas'),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label, this.faded = false});
  final IconData icon;
  final String label;
  final bool faded;
  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: faded ? .45 : 1,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 16), const SizedBox(width: 4), Text(label)],
      ),
    );
  }
}

class _FallbackBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/images/banner_default.jpg',
    height: 82,
    width: double.infinity,
    fit: BoxFit.cover,
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    ),
  );
}

class _Constrained extends StatelessWidget {
  const _Constrained({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 920),
      child: child,
    ),
  );
}

class AppColors {
  static const primary = Color(0xFF19C65E);
  static const primaryDark = Color(0xFF42D99A);
  static const lightBg = Color(0xFFFAFFFE);
  static const lightBorder = Color(0xFFEDF5F1);
  static const darkBg = Color(0xFF111B21);
  static const darkChrome = Color(0xFF121A17);
  static const darkCard = Color(0xFF1A2730);
  static const darkBorder = Color(0xFF2A3942);
}

String _excerpt(String markdown) {
  final clean = markdown
      .replaceAll(RegExp(r'[#*_`>\[\]()!]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return clean.length > 180 ? '${clean.substring(0, 180)}...' : clean;
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
