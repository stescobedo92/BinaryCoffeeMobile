class PodcastEpisode {
  const PodcastEpisode({
    required this.id,
    required this.title,
    required this.description,
    required this.audioUrl,
    required this.publishedAt,
    this.duration,
    this.imageUrl,
    this.episodeNumber,
  });

  final String id;
  final String title;
  final String description;
  final String audioUrl;
  final DateTime publishedAt;
  final Duration? duration;
  final String? imageUrl;
  final int? episodeNumber;
}
