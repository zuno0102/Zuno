/// One offer on an order: how many people, for how much.
///
/// Every round is kept, so both sides can read how a number was arrived at rather than just what
/// it ended up as. The rounds are these in the order they were made.
class BookingTermsProposal {
  const BookingTermsProposal({
    required this.id,
    required this.proposedByRole,
    required this.workerCount,
    required this.price,
    required this.proposalStatus,
    required this.createdDate,
    this.message,
    this.respondedAt,
  });

  final String id;

  /// `Customer` or `Business` — which side made this offer.
  final String proposedByRole;

  final int workerCount;
  final double price;

  /// Why, in the proposer's own words.
  final String? message;

  /// `Open`, `Accepted` or `Superseded`.
  final String proposalStatus;

  final DateTime createdDate;
  final DateTime? respondedAt;

  bool get isOpen => proposalStatus == 'Open';
  bool get isAccepted => proposalStatus == 'Accepted';
  bool get isFromBusiness => proposedByRole == 'Business';

  /// Whether the side currently looking at this may accept or counter it.
  ///
  /// You can never take up your own offer — that would let one side settle the price alone.
  bool canBeAnsweredBy({required bool viewerIsBusiness}) =>
      isOpen && isFromBusiness != viewerIsBusiness;
}
