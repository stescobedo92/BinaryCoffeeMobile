import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'src/api/binary_coffee_api.dart';
import 'src/models/podcast_episode.dart';
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
        unawaited(AppIconSync.setDarkIcon(controller.darkMode));
        return MaterialApp(
          title: 'Binary Coffee',
          debugShowCheckedModeBanner: false,
          themeMode: controller.darkMode ? ThemeMode.dark : ThemeMode.light,
          theme: _theme(lightScheme),
          darkTheme: _theme(darkScheme, dark: true),
          builder: (context, child) => _TextScope(
            text: AppText(controller.languageCode),
            child: child ?? const SizedBox.shrink(),
          ),
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
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          fixedSize: const Size.square(40),
          minimumSize: const Size.square(40),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
      ),
      appBarTheme: AppBarTheme(
        toolbarHeight: 48,
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
        height: 56,
        backgroundColor: dark ? AppColors.darkChrome : Colors.white,
        indicatorColor: scheme.primary.withValues(alpha: .16),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
        ),
        iconTheme: const WidgetStatePropertyAll(IconThemeData(size: 20)),
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

class AppIconSync {
  static const _channel = MethodChannel('binarycoffee/app_icon');
  static bool? _lastDark;

  static Future<void> setDarkIcon(bool dark) async {
    if (_lastDark == dark) return;
    _lastDark = dark;
    try {
      await _channel.invokeMethod<void>('setDarkIcon', {'dark': dark});
    } catch (_) {}
  }
}

class _TextScope extends InheritedWidget {
  const _TextScope({required this.text, required super.child});
  final AppText text;

  @override
  bool updateShouldNotify(_TextScope oldWidget) =>
      text.languageCode != oldWidget.text.languageCode;
}

extension AppTextContext on BuildContext {
  AppText get text =>
      dependOnInheritedWidgetOfExactType<_TextScope>()?.text ?? AppText('en');
}

class AppText {
  AppText(String code) : languageCode = code == 'es' ? 'es' : 'en';
  final String languageCode;
  bool get es => languageCode == 'es';
  String get locale => es ? 'es' : 'en';
  String get lightMode => es ? 'Modo claro' : 'Light mode';
  String get darkMode => es ? 'Modo oscuro' : 'Dark mode';
  String get language => es ? 'Idioma' : 'Language';
  String get profile => es ? 'Perfil' : 'Profile';
  String get home => es ? 'Inicio' : 'Home';
  String get saved => es ? 'Guardados' : 'Saved';
  String get history => es ? 'Historial' : 'History';
  String get offline => 'Offline';
  String get podcasts => 'Podcasts';
  String get espacioBinario => 'Espacio Binario';
  String get podcastCopy => es
      ? 'Episodios del podcast de Binary Coffee publicados en Spotify.'
      : 'Binary Coffee podcast episodes published on Spotify.';
  String get podcastEmpty =>
      es ? 'No hay episodios disponibles.' : 'No episodes available.';
  String get openSpotify => es ? 'Abrir Spotify' : 'Open Spotify';
  String get nowPlaying => es ? 'Reproduciendo' : 'Now playing';
  String get play => es ? 'Reproducir' : 'Play';
  String get pause => es ? 'Pausar' : 'Pause';
  String get backToPodcasts => es ? 'Volver a podcasts' : 'Back to podcasts';
  String get draft => es ? 'Borrador' : 'Draft';
  String get savedEmpty => es
      ? 'Guarda articulos para leerlos despues.'
      : 'Save articles to read later.';
  String get historyEmpty => es
      ? 'Los articulos que abras apareceran aqui.'
      : 'Articles you open will appear here.';
  String get offlineEmpty => es
      ? 'Abre articulos para dejarlos disponibles offline.'
      : 'Open articles to make them available offline.';
  String get newArticles =>
      es ? 'Hay articulos nuevos' : 'New articles available';
  String get clear => es ? 'Limpiar' : 'Clear';
  String get mostViewed => es ? 'Mas vistos' : 'Most viewed';
  String get mostCommented => es ? 'Mas comentados' : 'Most commented';
  String get mostLiked => es ? 'Mas gustados' : 'Most liked';
  String get searchArticles => es ? 'Buscar articulos' : 'Search articles';
  String get filters => es ? 'Filtros' : 'Filters';
  String get filterByTag => es ? 'Filtrar por tag' : 'Filter by tag';
  String get removeSaved => es ? 'Quitar guardado' : 'Remove saved';
  String get save => es ? 'Guardar' : 'Save';
  String get share => es ? 'Compartir' : 'Share';
  String get openSite =>
      es ? 'Abrir en binarycoffee.dev' : 'Open on binarycoffee.dev';
  String get article => es ? 'Articulo' : 'Article';
  String get normalView => es ? 'Vista normal' : 'Normal view';
  String get readingMode => es ? 'Modo lectura' : 'Reading mode';
  String get minRead => es ? 'min lectura' : 'min read';
  String commentsCount(int count) =>
      es ? 'Comentarios ($count)' : 'Comments ($count)';
  String get noComments => es ? 'Sin comentarios aun' : 'No comments yet';
  String get writeComment => es ? 'Escribe un comentario' : 'Write a comment';
  String get comment => es ? 'Comentar' : 'Comment';
  String get myProfile => es ? 'Mi perfil' : 'My profile';
  String get filterPosts => es ? 'Filtrar posts' : 'Filter posts';
  String get confirmed => es ? 'confirmado' : 'confirmed';
  String get localNotifications =>
      es ? 'Notificaciones locales' : 'Local notifications';
  String get myPosts => es ? 'Mis posts' : 'My posts';
  String get stats => es ? 'Estadisticas' : 'Stats';
  String get subscribe => es ? 'Suscribirme' : 'Subscribe';
  String get logout => es ? 'Cerrar sesion' : 'Sign out';
  String get signIn => es ? 'Iniciar sesion' : 'Sign in';
  String get signInCopy => es
      ? 'Continua con tu cuenta para comentar, dar like y crear borradores.'
      : 'Continue with your account to comment, like, and create drafts.';
  String get continueGithub =>
      es ? 'Continuar con GitHub' : 'Continue with GitHub';
  String get done => es ? 'Listo' : 'Done';
  String get githubSignedIn =>
      es ? 'Sesion iniciada con GitHub' : 'Signed in with GitHub';
  String get close => es ? 'Cerrar' : 'Close';
  String get createDraft => es ? 'Crear borrador' : 'Create draft';
  String get title => es ? 'Titulo' : 'Title';
  String get edit => es ? 'Editar' : 'Edit';
  String get preview => 'Preview';
  String get markdownContent => es ? 'Contenido Markdown' : 'Markdown content';
  String get noMore => es ? 'No hay mas articulos' : 'No more articles';
  String get loadMore => es ? 'Cargar mas' : 'Load more';
  String get retry => es ? 'Reintentar' : 'Retry';
  String authorPosts(String name) => es ? 'Posts de $name' : '$name posts';
  String loadedStats(int posts, int views, int likes, int comments) => es
      ? 'Posts cargados: $posts\nViews: $views\nLikes: $likes\nComentarios: $comments'
      : 'Loaded posts: $posts\nViews: $views\nLikes: $likes\nComments: $comments';
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
  final _podcastPlayer = AudioPlayer();
  StreamSubscription<Uri>? _linkSubscription;
  Timer? _debounce;
  PodcastEpisode? _currentEpisode;
  bool _podcastPreparing = false;
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
    _podcastPlayer.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final width = MediaQuery.sizeOf(context).width;
        final wide = width >= 840;
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 8,
            title: Row(
              children: [
                Image.asset(
                  'assets/images/title_icon.png',
                  height: 22,
                  width: 22,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 7),
                Text(
                  'Binary Coffee',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: controller.darkMode ? text.lightMode : text.darkMode,
                onPressed: () => controller.setDarkMode(!controller.darkMode),
                icon: Icon(
                  controller.darkMode
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                ),
              ),
              IconButton(
                tooltip: text.language,
                onPressed: () => controller.setLanguageCode(
                  controller.languageCode == 'en' ? 'es' : 'en',
                ),
                icon: Text(
                  controller.languageCode.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: text.profile,
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
                    title: text.saved,
                    posts: controller.favoritePosts,
                    empty: text.savedEmpty,
                  ),
                if (_tabIndex == 2)
                  _savedSliver(
                    context,
                    title: text.history,
                    posts: controller.readHistoryPosts,
                    empty: text.historyEmpty,
                  ),
                if (_tabIndex == 3)
                  _savedSliver(
                    context,
                    title: text.offline,
                    posts: controller.cachedPosts,
                    empty: text.offlineEmpty,
                  ),
                if (_tabIndex == 4) _podcastSliver(context),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tabIndex,
            onDestinationSelected: _selectTab,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.dynamic_feed_outlined),
                selectedIcon: const Icon(Icons.dynamic_feed),
                label: text.home,
              ),
              NavigationDestination(
                icon: const Icon(Icons.bookmark_border),
                selectedIcon: const Icon(Icons.bookmark),
                label: text.saved,
              ),
              NavigationDestination(
                icon: const Icon(Icons.history_outlined),
                selectedIcon: const Icon(Icons.history),
                label: text.history,
              ),
              NavigationDestination(
                icon: const Icon(Icons.offline_pin_outlined),
                selectedIcon: const Icon(Icons.offline_pin),
                label: text.offline,
              ),
              NavigationDestination(
                icon: const Icon(Icons.podcasts_outlined),
                selectedIcon: const Icon(Icons.podcasts),
                label: text.podcasts,
              ),
            ],
          ),
          floatingActionButton: controller.session == null
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _openDraft(context),
                  icon: const Icon(Icons.edit_note_outlined),
                  label: Text(text.draft),
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
              label: Text(context.text.newArticles),
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
              content: Text(context.text.authorPosts(controller.authorName!)),
              leading: const Icon(Icons.person_search_outlined),
              actions: [
                TextButton(
                  onPressed: controller.clearAuthorFilter,
                  child: Text(context.text.clear),
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
                  title: context.text.mostViewed,
                  posts: controller.topViewedPosts,
                  onOpen: (post) => _openPost(context, post),
                ),
                _HighlightRail(
                  title: context.text.mostCommented,
                  posts: controller.topCommentedPosts,
                  onOpen: (post) => _openPost(context, post),
                ),
                _HighlightRail(
                  title: context.text.mostLiked,
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
        child: _ErrorState(
          message: controller.error!,
          onRetry: controller.refresh,
        ),
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

  void _selectTab(int value) {
    setState(() => _tabIndex = value);
    if (value == 4) unawaited(controller.loadPodcasts());
  }

  Widget _podcastSliver(BuildContext context) {
    final text = context.text;
    if (!controller.loadingPodcasts &&
        controller.podcastEpisodes.isEmpty &&
        controller.podcastError == null) {
      unawaited(controller.loadPodcasts());
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 88),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          _Constrained(
            child: _PodcastHeader(
              onOpenSpotify: () => launchUrl(
                Uri.parse(BinaryCoffeeApi.espacioBinarioSpotifyUrl),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ),
          if (_currentEpisode != null)
            _Constrained(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _PodcastPlayerBanner(
                  episode: _currentEpisode!,
                  player: _podcastPlayer,
                  preparing: _podcastPreparing,
                  onBack: _closePodcastPlayer,
                  onPlayPause: () => _playPauseEpisode(_currentEpisode!),
                ),
              ),
            ),
          const SizedBox(height: 10),
          if (controller.loadingPodcasts)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (controller.podcastError != null)
            _Constrained(
              child: _ErrorState(
                message: controller.podcastError!,
                onRetry: controller.refreshPodcasts,
              ),
            )
          else if (controller.podcastEpisodes.isEmpty)
            _EmptyLibrary(title: text.podcasts, message: text.podcastEmpty)
          else
            for (final episode in controller.podcastEpisodes.where(
              (episode) => episode.id != _currentEpisode?.id,
            ))
              _Constrained(
                child: PodcastEpisodeCard(
                  episode: episode,
                  selected: false,
                  preparing: false,
                  player: _podcastPlayer,
                  onPlayPause: () => _playPauseEpisode(episode),
                ),
              ),
        ]),
      ),
    );
  }

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
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
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
                    onLike: () =>
                        _guarded(context, () => controller.like(post)),
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
      _snack(context, context.text.githubSignedIn);
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
        builder: (_) =>
            AuthorDetailScreen(controller: controller, author: author),
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

  Future<void> _playPauseEpisode(PodcastEpisode episode) async {
    if (_podcastPreparing) return;
    final sameEpisode = _currentEpisode?.id == episode.id;
    if (sameEpisode && _podcastPlayer.playing) {
      await _podcastPlayer.pause();
      if (mounted) setState(() {});
      return;
    }
    try {
      setState(() {
        _currentEpisode = episode;
        _podcastPreparing = !sameEpisode;
      });
      if (!sameEpisode) {
        await _podcastPlayer.setUrl(episode.audioUrl);
      }
      if (mounted) {
        setState(() => _podcastPreparing = false);
      }
      unawaited(_podcastPlayer.play());
    } catch (e) {
      if (mounted) _snack(context, e.toString());
    } finally {
      if (mounted && _podcastPreparing) {
        setState(() => _podcastPreparing = false);
      }
    }
  }

  Future<void> _closePodcastPlayer() async {
    await _podcastPlayer.stop();
    if (mounted) {
      setState(() {
        _currentEpisode = null;
        _podcastPreparing = false;
      });
    }
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
    final text = context.text;
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
                  color:
                      controller.selectedTag.isEmpty &&
                          controller.selectedTags.isEmpty
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
                  hintText: text.searchArticles,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  suffixIcon: IconButton(
                    tooltip: text.filters,
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
            if (controller.recentSearches.isNotEmpty &&
                controller.search.isEmpty)
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
    final text = context.text;
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
                  text.filterByTag,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (controller.selectedTag.isNotEmpty ||
                    controller.selectedTags.isNotEmpty)
                  TextButton(
                    onPressed: controller.clearTags,
                    child: Text(text.clear),
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
                      selected:
                          selected ||
                          controller.selectedTags.contains(tag.name),
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
                        color: Theme.of(
                          context,
                        ).dividerColor.withValues(alpha: .35),
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
                            _Metric(
                              icon: Icons.visibility_outlined,
                              label: '${post.views}',
                            ),
                            const SizedBox(width: 10),
                            _Metric(
                              icon: Icons.chat_bubble_outline,
                              label: '${post.comments}',
                            ),
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

class _PodcastHeader extends StatelessWidget {
  const _PodcastHeader({required this.onOpenSpotify});

  final VoidCallback onOpenSpotify;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: .32),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: const _PodcastArtwork(
              url: BinaryCoffeeApi.espacioBinarioArtworkUrl,
              size: 58,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text.espacioBinario,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text.podcastCopy,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: text.openSpotify,
            onPressed: onOpenSpotify,
            icon: const FaIcon(FontAwesomeIcons.spotify, size: 18),
          ),
        ],
      ),
    );
  }
}

class PodcastEpisodeCard extends StatelessWidget {
  const PodcastEpisodeCard({
    super.key,
    required this.episode,
    required this.selected,
    required this.preparing,
    required this.player,
    required this.onPlayPause,
  });

  final PodcastEpisode episode;
  final bool selected;
  final bool preparing;
  final AudioPlayer player;
  final VoidCallback onPlayPause;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PodcastArtwork(url: episode.imageUrl, size: 58),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          episode.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _PodcastPlayButton(
                        player: player,
                        selected: selected,
                        preparing: preparing,
                        size: 32,
                        iconSize: 16,
                        onPressed: onPlayPause,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      DateFormat.yMMMd(text.locale).format(episode.publishedAt),
                      if (episode.duration != null)
                        _formatDuration(episode.duration!),
                    ].join(' · '),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).textTheme.bodySmall?.color?.withValues(alpha: .7),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    episode.description,
                    maxLines: selected ? 4 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (selected) ...[
                    const SizedBox(height: 8),
                    _PodcastProgress(player: player),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PodcastPlayerBanner extends StatelessWidget {
  const _PodcastPlayerBanner({
    required this.episode,
    required this.player,
    required this.preparing,
    required this.onBack,
    required this.onPlayPause,
  });

  final PodcastEpisode episode;
  final AudioPlayer player;
  final bool preparing;
  final VoidCallback onBack;
  final VoidCallback onPlayPause;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                tooltip: text.backToPodcasts,
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 4),
              _PodcastArtwork(url: episode.imageUrl, size: 78),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text.nowPlaying,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      episode.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      [
                        DateFormat.yMMMd(
                          text.locale,
                        ).format(episode.publishedAt),
                        if (episode.duration != null)
                          _formatDuration(episode.duration!),
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withValues(alpha: .72),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _PodcastPlayButton(
                player: player,
                selected: true,
                preparing: preparing,
                size: 48,
                iconSize: 24,
                onPressed: onPlayPause,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _podcastMainDescription(episode.description),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          const _PodcastSocialLinks(),
          const SizedBox(height: 10),
          _PodcastProgress(player: player),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                label: Text(text.backToPodcasts),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PodcastPlayButton extends StatelessWidget {
  const _PodcastPlayButton({
    required this.player,
    required this.selected,
    required this.preparing,
    required this.onPressed,
    this.size = 48,
    this.iconSize = 24,
  });

  final AudioPlayer player;
  final bool selected;
  final bool preparing;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    return StreamBuilder<PlayerState>(
      stream: player.playerStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final buffering =
            preparing ||
            (selected &&
                !(state?.playing ?? false) &&
                (state?.processingState == ProcessingState.loading ||
                    state?.processingState == ProcessingState.buffering));
        final isPlaying = selected && (state?.playing ?? false);
        return SizedBox.square(
          dimension: size,
          child: IconButton.filled(
            tooltip: isPlaying ? text.pause : text.play,
            iconSize: iconSize,
            style: IconButton.styleFrom(
              fixedSize: Size.square(size),
              minimumSize: Size.square(size),
              maximumSize: Size.square(size),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: buffering ? null : onPressed,
            icon: buffering
                ? SizedBox.square(
                    dimension: iconSize - 3,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(isPlaying ? Icons.pause : Icons.play_arrow_rounded),
          ),
        );
      },
    );
  }
}

class _PodcastSocialLinks extends StatelessWidget {
  const _PodcastSocialLinks();

  static const _telegramUrl = 'https://t.me/binarycoffeedev';
  static const _twitterUrl = 'https://twitter.com/espac10binar10';
  static const _websiteUrl = BinaryCoffeeApi.siteUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PodcastSocialButton(
          tooltip: 'Telegram',
          onPressed: () => launchUrl(
            Uri.parse(_telegramUrl),
            mode: LaunchMode.externalApplication,
          ),
          icon: const FaIcon(FontAwesomeIcons.telegram, size: 18),
        ),
        const SizedBox(width: 8),
        _PodcastSocialButton(
          tooltip: 'Twitter',
          onPressed: () => launchUrl(
            Uri.parse(_twitterUrl),
            mode: LaunchMode.externalApplication,
          ),
          icon: const FaIcon(FontAwesomeIcons.twitter, size: 18),
        ),
        const SizedBox(width: 8),
        _PodcastSocialButton(
          tooltip: BinaryCoffeeApi.siteUrl,
          onPressed: () => launchUrl(
            Uri.parse(_websiteUrl),
            mode: LaunchMode.externalApplication,
          ),
          icon: const Icon(Icons.public_rounded, size: 18),
        ),
      ],
    );
  }
}

class _PodcastSocialButton extends StatelessWidget {
  const _PodcastSocialButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final Widget icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: tooltip,
      iconSize: 18,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(36),
        minimumSize: const Size.square(36),
        maximumSize: const Size.square(36),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      onPressed: onPressed,
      icon: icon,
    );
  }
}

class _PodcastProgress extends StatelessWidget {
  const _PodcastProgress({required this.player});

  final AudioPlayer player;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, positionSnapshot) {
        final position = positionSnapshot.data ?? Duration.zero;
        return StreamBuilder<Duration?>(
          stream: player.durationStream,
          builder: (context, durationSnapshot) {
            final duration = durationSnapshot.data ?? player.duration;
            final max = duration?.inMilliseconds.toDouble() ?? 1;
            final value = position.inMilliseconds.clamp(0, max.toInt());
            return Column(
              children: [
                Slider(
                  value: value.toDouble(),
                  max: max <= 0 ? 1 : max,
                  onChanged: duration == null
                      ? null
                      : (next) =>
                            player.seek(Duration(milliseconds: next.round())),
                ),
                Row(
                  children: [
                    Text(_formatDuration(position)),
                    const Spacer(),
                    Text(
                      duration == null ? '--:--' : _formatDuration(duration),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _PodcastArtwork extends StatelessWidget {
  const _PodcastArtwork({required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: imageUrl == null || imageUrl.isEmpty
          ? Image.asset(
              'assets/images/app_icon.png',
              height: size,
              width: size,
              fit: BoxFit.cover,
            )
          : CachedNetworkImage(
              imageUrl: imageUrl,
              height: size,
              width: size,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(
                height: size,
                width: size,
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              errorWidget: (_, _, _) => Image.asset(
                'assets/images/app_icon.png',
                height: size,
                width: size,
                fit: BoxFit.cover,
              ),
            ),
    );
  }
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) return '$hours:$minutes:$seconds';
  return '${duration.inMinutes}:$seconds';
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
    final text = context.text;
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
                            DateFormat.yMMMd(
                              text.locale,
                            ).format(post.publishedAt),
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
                            icon: liked
                                ? Icons.favorite
                                : Icons.favorite_border,
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
                          tooltip: favorite ? text.removeSaved : text.save,
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            favorite ? Icons.bookmark : Icons.bookmark_border,
                            size: 18,
                          ),
                          onPressed: onFavorite,
                        ),
                        IconButton(
                          tooltip: text.share,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.ios_share_outlined, size: 18),
                          onPressed: onShare,
                        ),
                        IconButton.filledTonal(
                          tooltip: text.openSite,
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
    final text = context.text;
    return Scaffold(
      appBar: AppBar(
        title: Text(text.article),
        actions: [
          IconButton(
            tooltip: _readingMode ? text.normalView : text.readingMode,
            onPressed: () => setState(() => _readingMode = !_readingMode),
            icon: Icon(
              _readingMode ? Icons.view_agenda : Icons.menu_book_outlined,
            ),
          ),
          IconButton(
            tooltip: text.share,
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
                      '${post.author.username} · ${post.readingTime ?? 0} ${text.minRead} · ${DateFormat.yMMMd(text.locale).format(post.publishedAt)}',
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
                      styleSheet:
                          MarkdownStyleSheet.fromTheme(
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
                      text.commentsCount(post.commentsList.length),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (post.commentsList.isEmpty) Text(text.noComments),
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
                        decoration: InputDecoration(
                          hintText: text.writeComment,
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
                        label: Text(text.comment),
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
    final text = context.text;
    final isMe = widget.controller.session?.id == widget.author.id;
    final session = widget.controller.session;
    return Scaffold(
      appBar: AppBar(
        title: Text(isMe ? text.myProfile : widget.author.username),
        actions: [
          IconButton(
            tooltip: text.filterPosts,
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
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                if (isMe && session != null)
                                  Text(
                                    [
                                      if (session.email != null) session.email!,
                                      if (session.roleName != null)
                                        session.roleName!,
                                      if (session.confirmed == true)
                                        text.confirmed,
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
                      liked: widget.controller.likedPostIds.contains(
                        posts[i].id,
                      ),
                      onAuthor: (_) {},
                      onLike: () => widget.controller.like(posts[i]),
                      onFavorite: () =>
                          widget.controller.toggleFavorite(posts[i]),
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
    final text = context.text;
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
                    if (session.confirmed == true) text.confirmed,
                  ].join(' · '),
                ),
              ),
              SwitchListTile(
                value: widget.controller.notificationsEnabled,
                onChanged: widget.controller.setNotifications,
                title: Text(text.localNotifications),
                secondary: const Icon(Icons.notifications_outlined),
              ),
              ListTile(
                leading: const Icon(Icons.article_outlined),
                title: Text(text.myPosts),
                onTap: () => _openMyPosts(context),
              ),
              ListTile(
                leading: const Icon(Icons.query_stats_outlined),
                title: Text(text.stats),
                onTap: () => _openStats(context),
              ),
              ListTile(
                leading: const Icon(Icons.mail_outline),
                title: Text(text.subscribe),
                onTap: () => _run(() => widget.controller.subscribe()),
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: Text(text.logout),
                onTap: () => widget.controller.logout(),
              ),
            ] else ...[
              Text(text.signIn, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                text.signInCopy,
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
                label: Text(text.continueGithub),
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
      if (mounted) _snack(context, context.text.done);
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
        title: Text(context.text.stats),
        content: Text(
          context.text.loadedStats(
            posts.length,
            posts.fold<int>(0, (s, p) => s + p.views),
            posts.fold<int>(0, (s, p) => s + p.likes),
            posts.fold<int>(0, (s, p) => s + p.comments),
          ),
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
    params =
        AndroidWebViewWidgetCreationParams.fromPlatformWebViewWidgetCreationParams(
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
        _snack(context, context.text.githubSignedIn);
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
          tooltip: context.text.close,
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
      ),
      body: Stack(
        children: [_webView, if (_loading) const LinearProgressIndicator()],
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
    final text = context.text;
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
          Text(text.createDraft, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            decoration: InputDecoration(labelText: text.title),
          ),
          const SizedBox(height: 10),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                icon: const Icon(Icons.edit_outlined),
                label: Text(text.edit),
              ),
              ButtonSegment(
                value: true,
                icon: const Icon(Icons.preview_outlined),
                label: Text(text.preview),
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
              decoration: InputDecoration(labelText: text.markdownContent),
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
            label: Text(text.createDraft),
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
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(child: Text(context.text.noMore)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 80),
      child: Center(
        child: FilledButton.tonal(
          onPressed: controller.loadMore,
          child: Text(context.text.loadMore),
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
          FilledButton(onPressed: onRetry, child: Text(context.text.retry)),
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

String _podcastMainDescription(String value) {
  final markerIndex = value.toLowerCase().indexOf('nuestras plataformas:');
  if (markerIndex < 0) return value;
  return value.substring(0, markerIndex).trim();
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
