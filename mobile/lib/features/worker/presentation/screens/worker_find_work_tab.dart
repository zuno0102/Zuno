import 'package:flutter/material.dart';
import 'package:zuno/features/vacancy/presentation/screens/worker_vacancies_tab.dart';
import 'package:zuno/features/worker/presentation/screens/worker_hiring_posts_tab.dart';
import 'package:zuno/shared/widgets/section_switcher.dart';

/// Find work: one-day service jobs, and full-time jobs from shops and offices. The same switch as
/// My jobs, so the two tabs read alike.
class WorkerFindWorkTab extends StatelessWidget {
  const WorkerFindWorkTab({super.key});

  @override
  Widget build(BuildContext context) => SectionSwitcher(
    sections: [
      SwitcherSection(
        label: 'Service',
        builder: (_) => const WorkerHiringPostsTab(),
      ),
      SwitcherSection(
        label: 'Full-time jobs',
        builder: (_) => const WorkerVacanciesTab(),
      ),
    ],
  );
}
