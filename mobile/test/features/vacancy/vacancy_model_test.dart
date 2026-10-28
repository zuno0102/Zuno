import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/notifications/domain/entities/app_notification.dart';
import 'package:zuno/features/vacancy/data/models/vacancy_application_model.dart';
import 'package:zuno/features/vacancy/data/models/vacancy_model.dart';
import 'package:zuno/features/vacancy/data/models/vacancy_options_model.dart';
import 'package:zuno/features/vacancy/domain/entities/vacancy.dart';
import 'package:zuno/features/vacancy/presentation/providers/paged_list.dart';
import 'package:zuno/features/vacancy/presentation/widgets/vacancy_labels.dart';

import 'vacancy_fixtures.dart';

void main() {
  group('parsing what the server sends', () {
    test('a vacancy with its requirements', () {
      final v = VacancyModel.fromJson(vacancyJson()).toEntity();

      expect(v.title, 'Office receptionist');
      expect(v.salaryMin, 15000);
      expect(v.isLive, isTrue);
      expect(v.requirements, hasLength(4));
      expect(v.requirements.map((r) => r.kind), [
        VacancyRequirementKind.file,
        VacancyRequirementKind.text,
        VacancyRequirementKind.yesNo,
        VacancyRequirementKind.number,
      ]);
      expect(v.requirements.first.isFile, isTrue);
      expect(v.requirements.last.isFile, isFalse);
    });

    test('a whole-number amount still reads as money', () {
      final json = vacancyJson()..['salaryMin'] = 15000;

      expect(VacancyModel.fromJson(json).toEntity().salaryMin, 15000.0);
    });

    test('an applicant, with a document that carries no URL', () {
      final a = VacancyApplicationModel.fromJson({
        'id': 'a-1',
        'vacancyId': 'v-1',
        'workerProfileId': 'w-1',
        'workerName': 'Ravi K',
        'workerPhone': '9876543210',
        'status': 'Shortlisted',
        'appliedAt': '2026-10-27T11:00:00+00:00',
        'businessNote': 'Call Monday',
        'answers': [
          {
            'id': 'x-1',
            'kind': 'Document',
            'prompt': 'Aadhaar card',
            'hasFile': true,
            'fileName': 'Aadhaar card.jpg',
            'contentType': 'image/jpeg',
          },
          {
            'id': 'x-2',
            'kind': 'Question',
            'prompt': 'Do you know Tally?',
            'answerText': 'Yes',
            'hasFile': false,
          },
        ],
      }).toEntity();

      expect(a.answers.first.isImage, isTrue);
      expect(a.answers.last.isImage, isFalse);
      expect(a.businessNote, 'Call Monday');
    });

    test('options from the tables and the upload rules', () {
      final o = VacancyOptionsModel.fromJson({
        'jobTypes': [
          {'id': 't-3', 'name': 'Contract', 'hasFixedLength': true},
        ],
        'allowedFileExtensions': ['pdf', 'png'],
        'maxFileSizeBytes': 5242880,
        'feePlans': [
          {
            'id': 'p-1',
            'name': 'Standard listing',
            'amount': 49,
            'listingDays': 30,
          },
        ],
      }).toEntity();

      expect(o.jobTypes.single.hasFixedLength, isTrue);
      expect(o.feePlans.single.amount, 49.0);
      expect(o.allowedFileExtensions, ['pdf', 'png']);
      expect(o.maxFileSizeBytes, 5242880);
    });
  });

  group('rules mirrored from the server', () {
    test('only an open, live vacancy can be stopped', () {
      expect(vacancy().canStop, isTrue);
      expect(
        vacancy(status: VacancyStatus.stopped, isLive: false).canStop,
        isFalse,
      );
      expect(
        vacancy(status: VacancyStatus.awaitingPayment, isLive: false).canStop,
        isFalse,
      );
    });

    test('a hired worker cannot withdraw; anyone else who applied can', () {
      expect(vacancy().canWithdraw, isFalse);
      expect(
        vacancy(
          myApplicationId: 'a',
          myApplicationStatus: 'Applied',
        ).canWithdraw,
        isTrue,
      );
      expect(
        vacancy(myApplicationId: 'a', myApplicationStatus: 'Hired').canWithdraw,
        isFalse,
      );
    });
  });

  group('labels', () {
    test('salary as a range, or a single figure', () {
      expect(vacancySalaryLabel(vacancy()), '₹15,000 – ₹20,000 / month');
      final single = VacancyModel.fromJson(
        vacancyJson(salaryMax: null),
      ).toEntity();
      expect(vacancySalaryLabel(single), '₹15,000 / month');
    });

    test('schedule names the days and the shift', () {
      expect(vacancyScheduleLabel(vacancy()), '6 days a week · 09:30–18:00');
    });

    test('a contract says how long', () {
      final json = vacancyJson()
        ..['contractMonths'] = 1
        ..['shiftStart'] = null
        ..['shiftEnd'] = null
        ..['workingDaysPerWeek'] = 1;
      expect(
        vacancyScheduleLabel(VacancyModel.fromJson(json).toEntity()),
        '1 day a week · 1 month',
      );
    });

    test('every field type has a name on the form', () {
      for (final k in VacancyRequirementKind.all) {
        expect(fieldKindLabel(k), isNotEmpty);
      }
      expect(fieldKindLabel(VacancyRequirementKind.yesNo), 'Yes / No');
    });

    test('every pay period has words', () {
      for (final p in VacancyPayPeriod.all) {
        expect(payPeriodWords(p), isNotEmpty);
      }
      expect(payPeriodSuffix(VacancyPayPeriod.perDay), '/ day');
    });

    test('the worker reads each stage in plain words', () {
      expect(
        applicationStatusLabel(VacancyApplicationStatus.applied),
        'Application sent',
      );
      expect(
        applicationStatusLabel(VacancyApplicationStatus.viewed),
        'Application viewed',
      );
      expect(
        applicationStatusLabel(VacancyApplicationStatus.shortlisted),
        'Shortlisted',
      );
      expect(
        applicationStatusLabel(VacancyApplicationStatus.rejected),
        'Rejected',
      );
      expect(applicationStatusLabel('SomethingNew'), 'Application sent');
    });

    test('the business reads the same stages as its lists', () {
      expect(VacancyApplicationStatus.businessLists.map(businessListLabel), [
        'New',
        'Waiting',
        'Shortlisted',
        'Hired',
      ]);
      expect(
        VacancyApplicationStatus.businessLists,
        isNot(contains(VacancyApplicationStatus.rejected)),
        reason: 'a rejected applicant is gone from the business side',
      );
    });
  });

  group('paged list', () {
    test('upsert replaces in place, or adds new at the top', () {
      final list = PagedList(
        items: [
          vacancy(id: 'a'),
          vacancy(id: 'b'),
        ],
      );

      final replaced = list.upsert(
        vacancy(id: 'b', applicantCount: 3),
        (v) => v.id,
      );
      expect(replaced.items.map((v) => v.id), ['a', 'b']);
      expect(replaced.items.last.applicantCount, 3);

      final added = list.upsert(vacancy(id: 'c'), (v) => v.id);
      expect(added.items.map((v) => v.id), ['c', 'a', 'b']);
    });

    test('has more only while there is a cursor', () {
      expect(
        PagedList<int>(items: const [], nextBefore: DateTime(2026)).hasMore,
        isTrue,
      );
      expect(const PagedList<int>(items: []).hasMore, isFalse);
    });
  });

  test(
    'the new notification targets are recognised, with ids where needed',
    () {
      expect(
        NotificationTarget.fromName('VacancyApplicants'),
        NotificationTarget.vacancyApplicants,
      );
      expect(NotificationTarget.vacancyApplicants.needsId, isTrue);
      expect(
        NotificationTarget.fromName('MyVacancyApplications'),
        NotificationTarget.myVacancyApplications,
      );
      expect(NotificationTarget.myVacancyApplications.needsId, isFalse);
    },
  );
}
