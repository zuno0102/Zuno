/// One thing the customer told the business when placing the order.
///
/// Carries the question's wording as it stood at the time, not as it reads today. A business is
/// free to reword or retire a question, and none of that changes what an old order says it was
/// told — so nothing here looks the question up.
class BookingServiceAnswer {
  const BookingServiceAnswer({
    required this.id,
    required this.questionPrompt,
    required this.answerText,
    required this.sortOrder,
  });

  final String id;

  /// The question as it was worded when this was answered.
  final String questionPrompt;

  final String answerText;
  final int sortOrder;
}
