import 'package:flutter/material.dart';

/// One half of a [SectionSwitcher]: its button, and what it shows when chosen.
class SwitcherSection {
  const SwitcherSection({
    required this.icon,
    required this.label,
    required this.builder,
  });

  final IconData icon;
  final String label;
  final WidgetBuilder builder;
}

/// A full-width two-or-more-way switch over a screen's sections — "Service | Full-time jobs".
///
/// Used where a screen already has its own tabs underneath, so the choice above them reads as a
/// different level rather than as a second row of tabs. One widget for every such screen, so they
/// all look and behave the same.
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

class _SectionSwitcherState extends State<SectionSwitcher> {
  late int _index = widget.initialIndex;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              for (final (i, s) in widget.sections.indexed)
                ButtonSegment(
                  value: i,
                  icon: Icon(s.icon),
                  label: Text(s.label),
                ),
            ],
            selected: {_index},
            onSelectionChanged: (s) => setState(() => _index = s.first),
          ),
        ),
      ),
      Expanded(child: widget.sections[_index].builder(context)),
    ],
  );
}
