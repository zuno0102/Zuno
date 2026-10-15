class ServiceMedia {
  const ServiceMedia({
    required this.id,
    required this.mediaType,
    required this.url,
    required this.sortOrder,
  });

  final String id;
  final String mediaType;
  final String url;
  final int sortOrder;

  bool get isImage => mediaType == 'Image';
  bool get isVideo => mediaType == 'Video';
}
