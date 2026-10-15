import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/customer/presentation/screens/customer_search_tab.dart';

/// The line under the customer's greeting, saying where results come from.
///
/// It used to read "4 district(s)" — a tally of what somebody had just picked themselves, naming
/// none of the places they picked. A customer wants to see where they are searching, so the line
/// now leads with their first choice and keeps the rest to a count.
void main() {
  group('with nothing chosen', () {
    test('says nothing, and the header falls back to everywhere', () {
      expect(
        locationSummary(primaryName: null, districtCount: 0),
        isNull,
      );
      // Defensive: a negative can only come from a bug, and must not print "-1 districts".
      expect(locationSummary(primaryName: 'Kollam', districtCount: -1), isNull);
    });
  });

  group('with one district', () {
    test('names it, with nothing trailing', () {
      expect(
        locationSummary(primaryName: 'Thiruvananthapuram', districtCount: 1),
        'Thiruvananthapuram',
      );
    });
  });

  group('with several', () {
    test('names the first and counts the others', () {
      expect(
        locationSummary(primaryName: 'Thiruvananthapuram', districtCount: 4),
        'Thiruvananthapuram +3',
      );
    });

    test('and two reads as one extra, not a plural count', () {
      expect(
        locationSummary(primaryName: 'Kollam', districtCount: 2),
        'Kollam +1',
      );
    });

    test('the count covers every district the search actually runs on', () {
      // The point of the "+n": the hidden ones are still filtering, and a customer who saw only a
      // single name would reasonably think the others had been dropped.
      expect(
        locationSummary(primaryName: 'Ernakulam', districtCount: 14),
        'Ernakulam +13',
      );
    });
  });

  group('when the name could not be resolved', () {
    test('falls back to the count rather than an empty line', () {
      expect(
        locationSummary(primaryName: null, districtCount: 3),
        '3 districts +2',
      );
    });

    test('and a single unresolved district still says something', () {
      expect(locationSummary(primaryName: null, districtCount: 1), '1 district');
    });
  });
}
