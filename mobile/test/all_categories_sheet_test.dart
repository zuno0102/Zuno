import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/shared/widgets/category_grid.dart';

/// What opens when a customer taps "More" under the category icons.
///
/// It used to open the app's generic multi-select sheet — the same checkbox-and-search sheet the
/// district filter uses — so tapping More on the categories produced something people read as the
/// location picker. It was multi-select over a filter that only ever takes one category, so three
/// ticks went in and only the first came out, and nothing on it looked like a category.
void main() {
  final categories = [
    const CategoryTile(id: 'c-1', label: 'Catering', icon: Icons.restaurant),
    const CategoryTile(id: 'c-2', label: 'Painting', icon: Icons.format_paint),
    const CategoryTile(id: 'c-3', label: 'Plumbing', icon: Icons.plumbing),
    const CategoryTile(id: 'c-4', label: 'Cleaning', icon: Icons.cleaning_services),
  ];

  Future<CategoryPick?> open(WidgetTester tester, {String? selectedId}) async {
    CategoryPick? result;
    var returned = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async {
                  result = await showAllCategoriesSheet(
                    context,
                    categories: categories,
                    selectedId: selectedId,
                  );
                  returned = true;
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
    return returned ? result : null;
  }

  testWidgets('lists every category, by name and by icon', (tester) async {
    await open(tester);

    expect(find.text('All categories'), findsOneWidget);
    for (final category in categories) {
      expect(find.text(category.label), findsOneWidget);
      expect(find.byIcon(category.icon), findsOneWidget);
    }
  });

  testWidgets('is not the location picker in disguise', (tester) async {
    // The three things that made it read as one: checkboxes, a search box and a Done button.
    await open(tester);

    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Done'), findsNothing);
  });

  testWidgets('one tap picks a category and closes', (tester) async {
    CategoryPick? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async {
                  picked = await showAllCategoriesSheet(
                    context,
                    categories: categories,
                  );
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

    await tester.tap(find.text('Plumbing'));
    await tester.pumpAndSettle();

    expect(picked?.id, 'c-3');
    expect(find.text('All categories'), findsNothing);
  });

  testWidgets('marks the category already in force', (tester) async {
    await open(tester, selectedId: 'c-2');

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    final tile = tester.widget<ListTile>(
      find.ancestor(of: find.text('Painting'), matching: find.byType(ListTile)),
    );
    expect(tile.selected, isTrue);
  });

  testWidgets('offers a way back to everything', (tester) async {
    // Without it, a customer who picked a category from this sheet could only clear it by finding
    // the same tile in the grid and tapping it again.
    await open(tester, selectedId: 'c-2');

    expect(find.text('Everything'), findsOneWidget);
    expect(find.text('No category filter'), findsOneWidget);
  });

  group('the More tile', () {
    // Eight categories against a grid that shows seven, so the eighth only exists behind More.
    final many = [
      ...categories,
      const CategoryTile(id: 'c-5', label: 'Carpentry', icon: Icons.carpenter),
      const CategoryTile(id: 'c-6', label: 'Plumbing 2', icon: Icons.plumbing),
      const CategoryTile(id: 'c-7', label: 'Beauty', icon: Icons.spa),
      const CategoryTile(id: 'c-8', label: 'Pest Control', icon: Icons.pest_control),
    ];

    Future<void> pumpGrid(
      WidgetTester tester, {
      String? selectedId,
      void Function(String?)? onSelected,
      VoidCallback? onMore,
    }) async {
      tester.view.physicalSize = const Size(1080, 1800);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryGrid(
              categories: many,
              selectedId: selectedId,
              onSelected: onSelected ?? (_) {},
              onMore: onMore ?? () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('reads "More" when nothing is filtering', (tester) async {
      await pumpGrid(tester);

      expect(find.text('More'), findsOneWidget);
      expect(find.text('Pest Control'), findsNothing);
    });

    testWidgets('takes on the category chosen from behind it', (tester) async {
      // The gap this closes: a category picked from the sheet left every tile unlit and the last one
      // still reading "More", so nothing on screen said the results were being narrowed.
      await pumpGrid(tester, selectedId: 'c-8');

      expect(find.text('Pest Control'), findsOneWidget);
      expect(find.text('More'), findsNothing);
    });

    testWidgets('and shows as lit, the way a chosen tile does', (tester) async {
      await pumpGrid(tester, selectedId: 'c-8');

      // The selected tile is the one drawn with a border; an unselected one has none.
      final box = tester.widget<Container>(
        find
            .ancestor(of: find.byIcon(Icons.pest_control), matching: find.byType(Container))
            .first,
      );
      expect((box.decoration! as BoxDecoration).border, isNotNull);
    });

    testWidgets('opens the list when nothing is filtering', (tester) async {
      var opened = false;
      await pumpGrid(tester, onMore: () => opened = true);

      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();

      expect(opened, isTrue);
    });

    testWidgets('tapping it while lit clears the filter, like any other tile', (
      tester,
    ) async {
      // The same gesture as the rest of the grid: the chosen tile turns itself off. Opening the
      // list here instead would make this the one tile where the obvious tap did something else.
      String? selected = 'c-8';
      var opened = false;

      await pumpGrid(
        tester,
        selectedId: 'c-8',
        onSelected: (id) => selected = id,
        onMore: () => opened = true,
      );

      await tester.tap(find.text('Pest Control'));
      await tester.pumpAndSettle();

      expect(selected, isNull, reason: 'the filter is cleared');
      expect(opened, isFalse, reason: 'and the list is not opened instead');
    });

    testWidgets('and goes back to reading "More" once cleared', (tester) async {
      await pumpGrid(tester, selectedId: 'c-8');
      expect(find.text('Pest Control'), findsOneWidget);

      // What the screen rebuilds as once the filter is gone.
      await pumpGrid(tester);

      expect(find.text('More'), findsOneWidget);
      expect(find.text('Pest Control'), findsNothing);
    });

    testWidgets('stays "More" when the filter is a tile already on screen', (
      tester,
    ) async {
      // Painting is one of the visible seven, so it lights up where it is and More stays itself.
      await pumpGrid(tester, selectedId: 'c-2');

      expect(find.text('More'), findsOneWidget);
    });
  });

  group('an uploaded icon image', () {
    // What this buys: the app can only draw icons compiled into it, so a category wanting artwork
    // outside that set would otherwise wait for a release. With an image on the row, adding a
    // category is entirely self-service.
    testWidgets('is drawn in place of the built-in icon', (tester) async {
      tester.view.physicalSize = const Size(1080, 1800);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryGrid(
              categories: const [
                CategoryTile(
                  id: 'c-1',
                  label: 'Tutoring',
                  icon: Icons.handyman,
                  iconUrl: '/uploads/categories/c-1/icon.png',
                ),
              ],
              onSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Tutoring'), findsOneWidget);
      // The fallback icon is not drawn while there is an image to draw instead.
      expect(find.byIcon(Icons.handyman), findsNothing);
    });

    testWidgets('and the built-in icon is used when there is none', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 1800);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CategoryGrid(
              categories: const [
                CategoryTile(id: 'c-1', label: 'Plumbing', icon: Icons.plumbing),
              ],
              onSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.plumbing), findsOneWidget);
    });
  });

  group('the icon comes from the category row', () {
    test('the key stored against a category decides what is drawn', () {
      // The point of the change: this is data now. An app owner adding "Tutoring" names an icon on
      // the row instead of waiting for somebody to teach the client a new word.
      expect(
        CategoryGrid.iconForCategory(iconName: 'events', name: 'Anything'),
        Icons.celebration,
      );
      expect(
        CategoryGrid.iconForCategory(iconName: 'plumbing', name: 'Anything'),
        Icons.plumbing,
      );
    });

    test('every key the seed writes is one this app can draw', () {
      // The seeded categories carry these, so a missing entry here is a blank square on the phone.
      for (final key in [
        'plumbing',
        'electrical',
        'cleaning',
        'carpentry',
        'painting',
        'appliance',
        'pest-control',
        'beauty',
        'catering',
        'events',
      ]) {
        expect(CategoryGrid.iconsByName[key], isNotNull, reason: key);
      }
    });

    test('a row with no icon chosen falls back to the name', () {
      expect(
        CategoryGrid.iconForCategory(iconName: null, name: 'Painting'),
        Icons.format_paint,
      );
    });

    test('and so does a key this version of the app has never heard of', () {
      // An app owner can name an icon the installed app predates. Better a sensible guess than an
      // empty square, and the next release can add the key.
      expect(
        CategoryGrid.iconForCategory(iconName: 'hot-air-balloon', name: 'Catering'),
        Icons.restaurant,
      );
    });
  });

  group('the fallback guess, for rows with no icon', () {
    test('is recognisable for every main category in the catalogue', () {
      // Named rather than keyed on id, because categories are data a business can extend. The
      // fallback is deliberately dull, so a main category landing on it is a miss.
      final expected = {
        'Plumbing': Icons.plumbing,
        'Electrical': Icons.bolt,
        'Cleaning': Icons.cleaning_services,
        'Carpentry': Icons.carpenter,
        'Painting': Icons.format_paint,
        'Appliance Repair': Icons.kitchen,
        'Pest Control': Icons.pest_control,
        'Beauty & Wellness': Icons.spa,
        'Catering': Icons.restaurant,
        'Events': Icons.celebration,
      };

      expected.forEach((name, icon) {
        expect(CategoryGrid.iconFor(name), icon, reason: name);
      });

      // Nothing in the catalogue should be landing on the fallback.
      for (final name in expected.keys) {
        expect(CategoryGrid.iconFor(name), isNot(Icons.handyman), reason: name);
      }
    });

    test('does not give Carpentry a lorry', () {
      // It did. "car" is a substring of "carpentry", and the transport rule matched first.
      expect(CategoryGrid.iconFor('Carpentry'), isNot(Icons.local_shipping));
      // The rule it was stealing from still works.
      expect(CategoryGrid.iconFor('Transport'), Icons.local_shipping);
    });

    test('still puts a category named for both trades on the food one', () {
      // Historic data: these were one category before they were split.
      expect(CategoryGrid.iconFor('Catering & events'), Icons.restaurant);
    });
  });

  testWidgets('and Everything returns a pick that clears the filter', (
    tester,
  ) async {
    CategoryPick? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async {
                  picked = await showAllCategoriesSheet(
                    context,
                    categories: categories,
                    selectedId: 'c-2',
                  );
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

    await tester.tap(find.text('Everything'));
    await tester.pumpAndSettle();

    // A pick carrying no id, which is different from the sheet being dismissed.
    expect(picked, isNotNull);
    expect(picked?.id, isNull);
  });
}
