import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The back-to-top button's behaviour, built the same way the home screen builds it.
///
/// The home tab itself needs the whole customer stack — auth, categories, sections, search — to pump,
/// so the rule worth pinning is tested on its own: a button that appears past a threshold, animates,
/// takes no taps while hidden, and returns a long page to the top.
void main() {
  const showAfter = 900.0;

  Widget harness(ScrollController controller, ValueNotifier<bool> visible) =>
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              ListView.builder(
                controller: controller,
                itemCount: 60,
                itemBuilder: (_, i) => SizedBox(height: 80, child: Text('row $i')),
              ),
              Positioned(
                right: 16,
                bottom: 20,
                child: ValueListenableBuilder<bool>(
                  valueListenable: visible,
                  builder: (context, show, _) => IgnorePointer(
                    ignoring: !show,
                    child: AnimatedOpacity(
                      opacity: show ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: AnimatedScale(
                        scale: show ? 1 : 0.7,
                        duration: const Duration(milliseconds: 180),
                        child: Material(
                          color: Colors.blue,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => controller.animateTo(
                              0,
                              duration: const Duration(milliseconds: 420),
                              curve: Curves.easeOutCubic,
                            ),
                            child: const Padding(
                              padding: EdgeInsets.all(11),
                              child: Icon(Icons.keyboard_arrow_up_rounded),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  testWidgets('is hidden at the top of the page', (tester) async {
    // Nothing to return from, and a control that can never do anything is worse than none.
    final controller = ScrollController();
    final visible = ValueNotifier(false);
    addTearDown(controller.dispose);
    addTearDown(visible.dispose);

    await tester.pumpWidget(harness(controller, visible));

    final opacity = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
    expect(opacity.opacity, 0);
  });

  testWidgets('appears once the page has been scrolled past the threshold', (
    tester,
  ) async {
    final controller = ScrollController();
    final visible = ValueNotifier(false);
    addTearDown(controller.dispose);
    addTearDown(visible.dispose);

    await tester.pumpWidget(harness(controller, visible));

    controller.jumpTo(showAfter + 50);
    visible.value = controller.offset > showAfter;
    await tester.pumpAndSettle();

    final opacity = tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity));
    expect(opacity.opacity, 1);
  });

  testWidgets('takes no taps while it is hidden', (tester) async {
    // A faded-out button still catches taps unless it is told not to, and an invisible thing
    // swallowing a tap meant for a card underneath is the worst kind of bug to report.
    final controller = ScrollController();
    final visible = ValueNotifier(false);
    addTearDown(controller.dispose);
    addTearDown(visible.dispose);

    await tester.pumpWidget(harness(controller, visible));

    final ignorePointer = tester.widget<IgnorePointer>(
      find.byType(IgnorePointer).last,
    );
    expect(ignorePointer.ignoring, isTrue);
  });

  testWidgets('returns a long page to the top when tapped', (tester) async {
    final controller = ScrollController();
    final visible = ValueNotifier(false);
    addTearDown(controller.dispose);
    addTearDown(visible.dispose);

    await tester.pumpWidget(harness(controller, visible));

    controller.jumpTo(2400);
    visible.value = true;
    await tester.pumpAndSettle();
    expect(controller.offset, 2400);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
    await tester.pumpAndSettle();

    expect(controller.offset, 0);
  });
}
