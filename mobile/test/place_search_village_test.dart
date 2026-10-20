import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/catalog/domain/entities/district.dart';
import 'package:zuno/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:zuno/features/worker/presentation/widgets/place_search_sheet.dart';

/// Searching "auttukonam, manalikarai": the hamlet is not on the free map, the village is. The sheet
/// used to say "Nothing found"; it now shows the village, says the hamlet was not found, and offers
/// to point at the exact spot on the map.
class _Places extends PlaceSearchClient {
  _Places(this._answer) : super(Dio());

  final List<SearchedPlace> _answer;

  @override
  Future<List<SearchedPlace>> search(String query) async => _answer;
}

const _manalikarai = SearchedPlace(
  name: 'Manalikarai',
  fullName: 'Manalikarai, Kalkulam, Kanniyakumari, Tamil Nadu, 629166, India',
  latitude: 8.2652,
  longitude: 77.3108,
  matchedText: 'manalikarai',
);

Future<PlaceChoice?> _openAndType(
  WidgetTester tester,
  List<SearchedPlace> answer,
  String typed,
) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  PlaceChoice? choice;
  var closed = false;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        placeSearchClientProvider.overrideWithValue(_Places(answer)),
        allDistrictsProvider.overrideWith((ref) async => const <District>[]),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                choice = await showPlaceSearchSheet(context);
                closed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), typed);
  // The search waits for typing to pause.
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pumpAndSettle();

  expect(closed, isFalse);
  return choice;
}

void main() {
  testWidgets('a hamlet the map does not know shows its village, and says so', (
    tester,
  ) async {
    await _openAndType(tester, const [_manalikarai], 'auttukonam, manalikarai');

    expect(find.text('Manalikarai'), findsOneWidget);
    expect(find.byKey(const Key('placeSheetPartialNote')), findsOneWidget);
    expect(
      find.textContaining('"auttukonam" is not on the free map'),
      findsOneWidget,
    );
  });

  testWidgets(
    'nothing at all found still leaves a way forward: pick on the map',
    (tester) async {
      await _openAndType(tester, const [], 'auttukonam');

      expect(find.textContaining('is not on the free map yet'), findsOneWidget);
      expect(find.byKey(const Key('placeSheetEmptyPickOnMap')), findsOneWidget);
    },
  );

  testWidgets('the sheet always offers "Pick on the map"', (tester) async {
    await _openAndType(tester, const [_manalikarai], 'manalikarai');

    expect(find.byKey(const Key('placeSheetPickOnMap')), findsOneWidget);
  });
}
