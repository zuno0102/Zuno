class Rating {
  const Rating({required this.score, required this.createdDate, this.comment});

  final int score;
  final String? comment;
  final DateTime createdDate;
}
