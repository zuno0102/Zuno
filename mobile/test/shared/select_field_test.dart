import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/core/theme/app_theme.dart';
import 'package:zuno/features/business_owner/presentation/widgets/salary_unit_dropdown.dart';
import 'package:zuno/shared/widgets/select_field.dart';

/// The picker field that replaced drop-downs in forms opened as a bottom sheet, where a drop-down's
/// menu spread edge to edge over the form.
void main() {
  const options = [
    SelectOption('m', 'Per month'),
    SelectOption('w', 'Per week'),
    SelectOption('d', 'Per day'),
  ];

  Future<List<String>> pump(
    WidgetTester tester, {
    String? initial,
    FormFieldValidator<String>? validator,
    GlobalKey<FormState>? formKey,
  }) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final picked = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: formKey,
              child: SelectField<String>(
                label: 'Salary is paid',
                initialValue: initial,
                options: options,
                validator: validator,
                onChanged: picked.add,
              ),
            ),
          ),
        ),
      ),
    );
    return picked;
  }

  // The report: an empty "Job type" printed its label and a "Choose" placeholder over each other.
  testWidgets('nothing chosen: only the label, nothing drawn over it', (
    tester,
  ) async {
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text('Choose'), findsNothing);
    final texts = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(SelectField<String>),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data ?? '')
        .where((t) => t.isNotEmpty)
        .toList();
    expect(texts, [
      'Salary is paid',
    ], reason: 'the label is the only words in the box');
  });

  testWidgets('once chosen, the label moves up and the choice sits below it', (
    tester,
  ) async {
    await pump(tester, initial: 'w');
    await tester.pumpAndSettle();

    final label = tester.getRect(find.text('Salary is paid'));
    final value = tester.getRect(find.text('Per week'));
    expect(
      label.bottom,
      lessThanOrEqualTo(value.top + 1),
      reason: 'no overlap',
    );
  });

  testWidgets('shows the label and the chosen option, like a text box', (
    tester,
  ) async {
    await pump(tester, initial: 'm');

    expect(find.text('Salary is paid'), findsOneWidget);
    expect(find.text('Per month'), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
  });

  testWidgets('opens its options as a bottom sheet, the chosen one ticked', (
    tester,
  ) async {
    await pump(tester, initial: 'm');
    await tester.tap(find.text('Per month'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(DropdownButton<String>), findsNothing);
    // The sheet sits at the foot of the screen, not as a menu over the field.
    final sheet = tester.getRect(find.byType(BottomSheet));
    expect(sheet.bottom, 780);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('select-option-m')),
        matching: find.byIcon(Icons.check_circle_rounded),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.circle_outlined), findsNWidgets(2));
  });

  testWidgets('picking one closes the sheet and shows it', (tester) async {
    final picked = await pump(tester, initial: 'm');
    await tester.tap(find.text('Per month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Per day'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(picked, ['d']);
    expect(find.text('Per day'), findsOneWidget);
    expect(find.text('Per month'), findsNothing);
  });

  testWidgets('closing the sheet changes nothing', (tester) async {
    final picked = await pump(tester, initial: 'w');
    await tester.tap(find.text('Per week'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(180, 20));
    await tester.pumpAndSettle();

    expect(picked, isEmpty);
    expect(find.text('Per week'), findsOneWidget);
  });

  testWidgets('validates like any form field', (tester) async {
    final form = GlobalKey<FormState>();
    await pump(
      tester,
      formKey: form,
      validator: (v) => v == null ? 'Choose how often' : null,
    );

    expect(find.text('Per week'), findsNothing, reason: 'nothing chosen yet');
    expect(form.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Choose how often'), findsOneWidget);

    await tester.tap(find.byType(SelectField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Per week'));
    await tester.pumpAndSettle();
    expect(form.currentState!.validate(), isTrue);
    await tester.pump();
    expect(find.text('Choose how often'), findsNothing);
  });

  testWidgets('a long list scrolls inside the sheet', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SelectField<int>(
            label: 'Pick',
            options: [for (var i = 0; i < 40; i++) SelectOption(i, 'Item $i')],
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.tap(find.byType(SelectField<int>));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.byType(BottomSheet)).height,
      lessThanOrEqualTo(640 * 0.7 + 60),
    );
  });

  Future<void> pumpAlone(WidgetTester tester, Widget field) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Padding(padding: const EdgeInsets.all(16), child: field),
        ),
      ),
    );
  }

  testWidgets('shows a helper line under the field', (tester) async {
    await pumpAlone(
      tester,
      SelectField<String>(
        label: 'Service',
        helperText: 'Picks the title and fills in the description',
        options: options,
        onChanged: (_) {},
      ),
    );
    expect(
      find.text('Picks the title and fills in the description'),
      findsOneWidget,
    );
  });

  testWidgets('locked: tapping opens nothing', (tester) async {
    await pumpAlone(
      tester,
      SelectField<String>(
        label: 'Per',
        initialValue: 'd',
        options: options,
        onChanged: null,
      ),
    );
    await tester.tap(find.byType(SelectField<String>));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Per day'), findsOneWidget);
  });

  testWidgets('follows a value the screen changes', (tester) async {
    var value = 'm';
    late StateSetter set;
    await pumpAlone(
      tester,
      StatefulBuilder(
        builder: (context, setState) {
          set = setState;
          return SelectField<String>(
            label: 'Salary is paid',
            initialValue: value,
            options: options,
            onChanged: (v) => setState(() => value = v),
          );
        },
      ),
    );
    expect(find.text('Per month'), findsOneWidget);

    set(() => value = 'w');
    await tester.pumpAndSettle();
    expect(find.text('Per week'), findsOneWidget);
    expect(find.text('Per month'), findsNothing);
  });

  testWidgets('a "nothing" option can be chosen and is shown', (tester) async {
    String? picked = 'x';
    await pumpAlone(
      tester,
      SelectField<String?>(
        label: 'Kind of work',
        initialValue: 'm',
        options: const [
          SelectOption<String?>(null, 'Not saying'),
          SelectOption<String?>('m', 'Plumbing'),
        ],
        onChanged: (v) => picked = v,
      ),
    );
    await tester.tap(find.byType(SelectField<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not saying'));
    await tester.pumpAndSettle();

    expect(picked, isNull);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Not saying'), findsOneWidget);
  });

  // The hire post's "Per": Event, Day, Hour — the menu that spilled over the form in the report.
  testWidgets('the salary "Per" opens as a bottom sheet with the three units', (
    tester,
  ) async {
    final picked = <String>[];
    await pumpAlone(
      tester,
      SalaryUnitDropdown(value: 'PerEvent', onChanged: picked.add),
    );
    await tester.tap(find.byType(SalaryUnitDropdown));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Event'), findsNWidgets(2), reason: 'field and sheet');
    expect(find.text('Day'), findsOneWidget);
    expect(find.text('Hour'), findsOneWidget);

    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle();
    expect(picked, ['PerDay']);
    expect(find.text('Day'), findsOneWidget);
  });
}
