import 'package:flutter/material.dart';

/// One part of a [SectionSwitcher]: its tab, and what it shows when chosen.
class SwitcherSection {
  const SwitcherSection({required this.label, required this.builder});

  final String label;
  final WidgetBuilder builder;
}

/// A full-width row of tabs over a screen's sections — "Service | Full-time jobs".
///
/// Drawn exactly like the business's "Active workers | Hire post | Full-time jobs" tabs, so the
/// worker and business panels read alike. Anything a section filters below it uses chips, not a
/// second row of tabs, so the two levels never look the same.
///
/// Changed by tapping only, not by swiping: a section can hold a map or a sideways-scrolling chip
/// row, and a swipe there must move the map or the chips rather than the whole section.
class SectionSwitcher extends StatefulWidget {
  const SectionSwitcher({
    required this.sections,
    this.initialIndex = 0,
    super.key,
  });

  final List<SwitcherSection> sections;
  final int initialIndex;

  @override
  State<SectionSwitcher> createState() => _SectionSwitcherState();
}

class _SectionSwitcherState extends State<SectionSwitcher>
    with SingleTickerProviderStateMixin {
  late final TabController _controller = TabController(
    length: widget.sections.length,
    initialIndex: widget.initialIndex,
    vsync: this,
  )..addListener(() => setState(() {}));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Material(
        color: Theme.of(context).colorScheme.surface,
        child: TabBar(
          controller: _controller,
          tabs: [for (final s in widget.sections) Tab(text: s.label)],
        ),
      ),
      Expanded(child: widget.sections[_controller.index].builder(context)),
    ],
  );
}
