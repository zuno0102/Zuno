import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/customer/presentation/screens/customer_search_tab.dart';

/// The heading over the band of matching services at the top of the home screen.
///
/// It says what the band *is*, and never repeats the customer's own choices back at them: no
/// district name, no category name. Those are already on screen — the district under the greeting
/// with a pin beside it, the category lit in the grid — and a heading reading "Painting services in
/// Kanyakumari" is the app reciting what was just tapped.
void main() {
  test('a district alone reads as nearby, without naming the place', () {
    expect(
      matchingSectionTitle(hasLocation: true, hasSearchTerms: false),
      'Services near you',
    );
  });

  test('a category or typed words alone reads as matching', () {
    expect(
      matchingSectionTitle(hasLocation: false, hasSearchTerms: true),
      'Matching services',
    );
  });

  test('both say both, still without naming either', () {
    expect(
      matchingSectionTitle(hasLocation: true, hasSearchTerms: true),
      'Matching services near you',
    );
  });

  test('neither leaves a plain heading rather than an empty one', () {
    // Not reachable from the screen — the band only appears under a filter — but a heading that
    // could come back empty is a heading waiting to render as a blank row.
    expect(
      matchingSectionTitle(hasLocation: false, hasSearchTerms: false),
      'Services',
    );
  });
}
