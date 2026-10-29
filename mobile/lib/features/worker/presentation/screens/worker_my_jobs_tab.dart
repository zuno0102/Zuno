import 'package:flutter/material.dart';
import 'package:zuno/features/vacancy/presentation/screens/worker_vacancies_tab.dart';
import 'package:zuno/features/worker/presentation/screens/worker_jobs_tab.dart';
import 'package:zuno/shared/widgets/section_switcher.dart';

/// My jobs, in two parts: the service jobs the worker is booked on (unchanged), and the
/// full-time jobs they have applied for.
class WorkerMyJobsTab extends StatelessWidget {
  const WorkerMyJobsTab({
    this.initialSection = serviceSection,
    this.serviceStartTab = WorkerJobsTab.currentTab,
    super.key,
  });

  static const serviceSection = 0;
  static const applicationsSection = 1;

  final int initialSection;

  /// Which of the service jobs' own tabs opens first.
  final int serviceStartTab;

  @override
  Widget build(BuildContext context) => SectionSwitcher(
    initialIndex: initialSection,
    sections: [
      SwitcherSection(
        label: 'Service jobs',
        builder: (_) => WorkerJobsTab(initialTab: serviceStartTab),
      ),
      SwitcherSection(
        label: 'My applications',
        builder: (_) => const MyVacancyApplicationsList(),
      ),
    ],
  );
}
