class MediaAsset {
  MediaAsset({this.url, this.thumbnailUrl, this.smallUrl});

  factory MediaAsset.fromJson(Map<String, dynamic>? json) {
    final attrs = json?['data']?['attributes'] as Map<String, dynamic>?;
    final formats = attrs?['formats'] as Map<String, dynamic>?;
    return MediaAsset(
      url: _absolute(attrs?['url'] as String?),
      thumbnailUrl: _absolute(formats?['thumbnail']?['url'] as String?),
      smallUrl: _absolute(formats?['small']?['url'] as String?),
    );
  }

  final String? url;
  final String? thumbnailUrl;
  final String? smallUrl;

  String? get best => smallUrl ?? thumbnailUrl ?? url;
}

class Author {
  Author({
    required this.id,
    required this.username,
    this.email,
    this.avatarUrl,
  });

  factory Author.fromJson(Map<String, dynamic>? json) {
    final data = json?['data'] as Map<String, dynamic>?;
    final attrs = data?['attributes'] as Map<String, dynamic>?;
    final avatar = MediaAsset.fromJson(
      attrs?['avatar'] as Map<String, dynamic>?,
    );
    final username = attrs?['username'] as String? ?? 'Anonimo';
    return Author(
      id: data?['id']?.toString() ?? '',
      username: username,
      email: attrs?['email'] as String?,
      avatarUrl:
          avatar.best ??
          attrs?['avatarUrl'] as String? ??
          'https://github.com/$username.png?size=96',
    );
  }

  final String id;
  final String username;
  final String? email;
  final String? avatarUrl;
}

class Tag {
  Tag({required this.id, required this.name});

  factory Tag.fromJson(Map<String, dynamic> json) {
    final attrs = json['attributes'] as Map<String, dynamic>? ?? {};
    return Tag(
      id: json['id']?.toString() ?? '',
      name: attrs['name'] as String? ?? '',
    );
  }

  final String id;
  final String name;
}

class Comment {
  Comment({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.author,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    final attrs = json['attributes'] as Map<String, dynamic>? ?? {};
    return Comment(
      id: json['id']?.toString() ?? '',
      body: attrs['body'] as String? ?? '',
      createdAt:
          DateTime.tryParse(attrs['createdAt'] as String? ?? '') ??
          DateTime.now(),
      author: Author.fromJson(
        (attrs['author'] ?? attrs['user']) as Map<String, dynamic>?,
      ),
    );
  }

  final String id;
  final String body;
  final DateTime createdAt;
  final Author author;
}

class Post {
  Post({
    required this.id,
    required this.title,
    required this.name,
    required this.body,
    required this.views,
    required this.likes,
    required this.comments,
    required this.publishedAt,
    required this.author,
    required this.tags,
    this.bannerUrl,
    this.readingTime,
    this.commentsList = const [],
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    final attrs = json['attributes'] as Map<String, dynamic>? ?? {};
    final tagData = attrs['tags']?['data'] as List<dynamic>? ?? const [];
    final commentData =
        attrs['commentsList']?['data'] as List<dynamic>? ?? const [];
    return Post(
      id: json['id']?.toString() ?? '',
      title: attrs['title'] as String? ?? 'Sin titulo',
      name: attrs['name'] as String? ?? '',
      body: attrs['body'] as String? ?? '',
      views: _asInt(attrs['views']),
      likes: _asInt(attrs['likes']),
      comments: _asInt(attrs['comments']),
      readingTime: _asInt(attrs['readingTime']),
      publishedAt:
          DateTime.tryParse(
            (attrs['publishedAt'] ?? attrs['createdAt']) as String? ?? '',
          ) ??
          DateTime.now(),
      bannerUrl: MediaAsset.fromJson(
        attrs['banner'] as Map<String, dynamic>?,
      ).best,
      author: Author.fromJson(attrs['author'] as Map<String, dynamic>?),
      tags: tagData
          .map((item) => Tag.fromJson(item as Map<String, dynamic>))
          .where((tag) => tag.name.isNotEmpty)
          .toList(),
      commentsList: commentData
          .map((item) => Comment.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  final String id;
  final String title;
  final String name;
  final String body;
  final int views;
  final int likes;
  final int comments;
  final int? readingTime;
  final DateTime publishedAt;
  final String? bannerUrl;
  final Author author;
  final List<Tag> tags;
  final List<Comment> commentsList;
}

int _asInt(Object? value) => int.tryParse(value?.toString() ?? '') ?? 0;

String? _absolute(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('http')) return url;
  return 'https://api.binarycoffee.dev$url';
}
