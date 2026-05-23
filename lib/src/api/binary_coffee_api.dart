import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/post.dart';
import '../models/user_session.dart';

class BinaryCoffeeApi {
  BinaryCoffeeApi({http.Client? client}) : _client = client ?? http.Client();

  static const graphqlUrl = 'https://api.binarycoffee.dev/graphql';
  static const siteUrl = 'https://binarycoffee.dev';
  static const dashboardUrl = 'https://binarycoffee.dev/dashboard';
  static const githubClientId = 'c37fad75ee13b3261065';
  static const appAuthCallback = 'binarycoffee://auth';

  final http.Client _client;

  Future<List<Post>> getPosts({
    int limit = 12,
    int start = 0,
    String search = '',
    String tag = '',
    String authorId = '',
  }) async {
    final filters = <String, dynamic>{
      'enable': {'eq': true},
      if (search.trim().isNotEmpty) 'title': {'containsi': search.trim()},
      if (tag.isNotEmpty)
        'tags': {
          'name': {'eq': tag},
        },
      if (authorId.isNotEmpty)
        'author': {
          'id': {'eq': authorId},
        },
    };
    final data = await _graphql(_postsQuery, {
      'limit': limit,
      'start': start,
      'sort': ['publishedAt:desc'],
      'filters': filters,
    });
    return ((data['posts']?['data'] as List<dynamic>?) ?? const [])
        .map((item) => Post.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Tag>> getTags() async {
    final data = await _graphql(
      'query { tags(pagination: { limit: 100 }) { data { id, attributes { name } } } }',
    );
    return ((data['tags']?['data'] as List<dynamic>?) ?? const [])
        .map((item) => Tag.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Post?> getPostByName(String name) async {
    final data = await _graphql(_postDetailQuery, {'name': name});
    final posts = (data['posts']?['data'] as List<dynamic>?) ?? const [];
    return posts.isEmpty
        ? null
        : Post.fromJson(posts.first as Map<String, dynamic>);
  }

  Future<List<Post>> getSimilarPosts(String postId) async {
    final data = await _graphql(_similarQuery, {'id': postId, 'limit': 3});
    return ((data['postsSimilar']?['data'] as List<dynamic>?) ?? const [])
        .map((item) => Post.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<UserSession> getMe(String jwt) async {
    final data = await _graphql(
      'query { me { id, username, email, avatar { url } } }',
      const {},
      jwt,
    );
    return UserSession.fromMe(data['me'] as Map<String, dynamic>, jwt);
  }

  Future<void> likePost(String postId, String jwt) async {
    await _graphql(
      r'mutation($post: ID!) { createLikePost(post: $post) { data { id } } }',
      {'post': postId},
      jwt,
    );
  }

  Future<void> unlikePost(String postId, String jwt) async {
    await _graphql(
      r'mutation($post: ID!) { removeLikePost(post: $post) { data { id } } }',
      {'post': postId},
      jwt,
    );
  }

  Future<void> createComment(String postId, String body, String jwt) async {
    await _graphql(
      r'mutation($data: CommentInput!) { createComment(data: $data) { data { id } } }',
      {
        'data': {'body': body, 'post': postId},
      },
      jwt,
    );
  }

  Future<void> createDraft(String title, String body, String jwt) async {
    await _graphql(
      r'mutation($data: PostInput!) { createPost(data: $data) { data { id } } }',
      {
        'data': {
          'title': title,
          'body': body,
          'name': _slugify(title),
          'enable': false,
        },
      },
      jwt,
    );
  }

  Future<void> subscribe(String email, String jwt) async {
    await _graphql('mutation($email: String!) { subscribe(email: $email) }', {
      'email': email,
    }, jwt);
  }

  Uri githubAuthorizeUri() {
    final redirect = Uri.parse(
      '$dashboardUrl/provider/github',
    ).replace(queryParameters: {'tokenOn': 'true', 'redir': appAuthCallback});
    return Uri.https('github.com', '/login/oauth/authorize', {
      'client_id': githubClientId,
      'scope': 'read:user read:email read:follow',
      'redirect_uri': redirect.toString(),
    });
  }

  Future<Map<String, dynamic>> _graphql(
    String query, [
    Map<String, dynamic> variables = const {},
    String? jwt,
  ]) async {
    final response = await _client.post(
      Uri.parse(graphqlUrl),
      headers: {
        'Content-Type': 'application/json',
        if (jwt != null && jwt.isNotEmpty) 'Authorization': 'Bearer $jwt',
      },
      body: jsonEncode({'query': query, 'variables': variables}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw BinaryCoffeeApiException('HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final errors = decoded['errors'] as List<dynamic>?;
    if (errors != null && errors.isNotEmpty) {
      throw BinaryCoffeeApiException(
        errors.first['message']?.toString() ?? 'GraphQL error',
      );
    }
    return decoded['data'] as Map<String, dynamic>;
  }

  String _slugify(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'(^-|-$)'), '');
}

class BinaryCoffeeApiException implements Exception {
  BinaryCoffeeApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

const _postsQuery = r'''
query($limit: Int, $start: Int, $sort: [String], $filters: PostFiltersInput) {
  posts(pagination: { limit: $limit, start: $start }, sort: $sort, filters: $filters) {
    data {
      id
      attributes {
        title name body views likes comments createdAt publishedAt
        banner { data { attributes { url, formats } } }
        author { data { id, attributes { username, email, avatarUrl, avatar { data { attributes { url, formats } } } } } }
        tags { data { id, attributes { name } } }
      }
    }
  }
}
''';

const _postDetailQuery = r'''
query($name: String!) {
  posts(filters: { name: { eq: $name } }) {
    data {
      id
      attributes {
        title name body views likes comments readingTime createdAt publishedAt
        banner { data { attributes { url, formats } } }
        author { data { id, attributes { username, email, avatarUrl, avatar { data { attributes { url, formats } } } } } }
        tags { data { id, attributes { name } } }
        commentsList {
          data {
            id
            attributes {
              body
              createdAt
              user {
                data {
                  attributes {
                    username
                    avatarUrl
                    avatar { data { attributes { url, formats } } }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
''';

const _similarQuery = r'''
query($id: ID!, $limit: Int) {
  postsSimilar(id: $id, limit: $limit) {
    data { id, attributes { title name body views likes comments publishedAt } }
  }
}
''';
