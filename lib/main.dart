import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

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
  Timer? _debounce;

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
  }

  @override
  void dispose() {
    _debounce?.cancel();
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
                  'assets/images/app_icon.png',
                  height: 30,
                  width: 30,
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
                SliverToBoxAdapter(
                  child: _Header(
                    controller: controller,
                    searchController: _searchController,
                    onSearch: _onSearchChanged,
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
                    padding: EdgeInsets.fromLTRB(
                      wide ? 24 : 12,
                      12,
                      wide ? 24 : 12,
                      12,
                    ),
                    sliver: SliverList.builder(
                      itemCount: controller.posts.length + 1,
                      itemBuilder: (context, index) {
                        if (index == controller.posts.length) {
                          return _LoadMore(controller: controller);
                        }
                        return _Constrained(
                          child: PostCard(
                            post: controller.posts[index],
                            index: index + 1,
                            signedIn: controller.session != null,
                            onTag: controller.toggleTag,
                            onAuthor: controller.filterByAuthor,
                            onLike: () => _guarded(
                              context,
                              () => controller.like(controller.posts[index]),
                            ),
                            onOpen: () =>
                                _openPost(context, controller.posts[index]),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
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

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 420),
      () => controller.setSearch(value),
    );
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

  void _openDraft(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DraftSheet(controller: controller),
    );
  }

  void _openPost(BuildContext context, Post post) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PostDetailScreen(controller: controller, post: post),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    required this.searchController,
    required this.onSearch,
  });

  final AppController controller;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    return _Constrained(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bienvenido a Binary Coffee',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'un espacio donde puedes compartir tus ideas',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).hintColor,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar articulos',
                suffixIcon: Icon(Icons.tune_outlined),
              ),
              onChanged: onSearch,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: controller.tags.take(18).map((tag) {
                final selected = controller.selectedTag == tag.name;
                return FilterChip(
                  selected: selected,
                  label: Text(tag.name),
                  onSelected: (_) => controller.toggleTag(tag.name),
                );
              }).toList(),
            ),
          ],
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
    required this.onTag,
    required this.onAuthor,
    required this.onLike,
    required this.onOpen,
  });

  final Post post;
  final int index;
  final bool signedIn;
  final ValueChanged<String> onTag;
  final ValueChanged<Author> onAuthor;
  final VoidCallback onLike;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              constraints: const BoxConstraints(minHeight: 170),
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.10),
              alignment: Alignment.topCenter,
              padding: const EdgeInsets.only(top: 14),
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
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (post.bannerUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          post.bannerUrl!,
                          height: 128,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _FallbackBanner(),
                        ),
                      ),
                    if (post.bannerUrl != null) const SizedBox(height: 8),
                    Text(
                      post.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 11,
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
                            style: const TextStyle(fontWeight: FontWeight.w600),
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
                    const SizedBox(height: 8),
                    Text(
                      _excerpt(post.body),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: post.tags
                          .take(4)
                          .map(
                            (tag) => ActionChip(
                              label: Text(tag.name),
                              onPressed: () => onTag(tag.name),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 8),
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
                            icon: Icons.favorite_border,
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
                          tooltip: 'Abrir en binarycoffee.dev',
                          icon: const Icon(Icons.open_in_new, size: 18),
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
  late Future<Post?> _future = widget.controller.api.getPostByName(
    widget.post.name,
  );
  final _commentController = TextEditingController();

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
                    if (post.bannerUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          post.bannerUrl!,
                          height: 190,
                          width: double.infinity,
                          fit: BoxFit.cover,
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
                    const Divider(height: 28),
                    MarkdownBody(data: post.body),
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
                            () => _future = widget.controller.api.getPostByName(
                              widget.post.name,
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

class ProfileSheet extends StatefulWidget {
  const ProfileSheet({super.key, required this.controller});

  final AppController controller;

  @override
  State<ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<ProfileSheet> {
  final _jwtController = TextEditingController();
  final _codeController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _jwtController.dispose();
    _codeController.dispose();
    super.dispose();
  }

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
                subtitle: Text(session.email ?? ''),
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
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () => launchUrl(
                  widget.controller.api.githubAuthorizeUri(),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.code),
                label: const Text('Abrir GitHub'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: 'Code de GitHub'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run(
                        () => widget.controller.loginWithGitHubCode(
                          _codeController.text,
                        ),
                      ),
                child: const Text('Completar login GitHub'),
              ),
              const Divider(height: 28),
              TextField(
                controller: _jwtController,
                decoration: const InputDecoration(labelText: 'JWT existente'),
                obscureText: true,
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _run(
                        () => widget.controller.loginWithJwt(
                          _jwtController.text.trim(),
                        ),
                      ),
                child: const Text('Usar JWT'),
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
          TextField(
            controller: _body,
            minLines: 8,
            maxLines: 14,
            decoration: const InputDecoration(labelText: 'Contenido Markdown'),
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
    height: 128,
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
