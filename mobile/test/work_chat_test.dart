import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/domain/entities/booking_message.dart';
import 'package:zuno/features/booking/domain/entities/booking_worker_assignment.dart';
import 'package:zuno/features/booking/presentation/providers/booking_message_providers.dart';
import 'package:zuno/features/booking/presentation/providers/business_bookings_notifier.dart';
import 'package:zuno/features/booking/presentation/providers/customer_bookings_notifier.dart';
import 'package:zuno/features/booking/presentation/providers/worker_jobs_notifier.dart';
import 'package:zuno/features/booking/presentation/widgets/booking_crew_list.dart';
import 'package:zuno/features/business_owner/presentation/screens/business_orders_tab.dart';
import 'package:zuno/features/customer/presentation/screens/customer_bookings_tab.dart';
import 'package:zuno/features/hiring_post/data/models/hiring_post_model.dart';
import 'package:zuno/features/hiring_post/domain/entities/hiring_post.dart';
import 'package:zuno/features/hiring_post/presentation/providers/business_hiring_posts_notifier.dart';
import 'package:zuno/features/hiring_post/presentation/providers/worker_job_offers_notifier.dart';
import 'package:zuno/features/hiring_post/presentation/providers/worker_post_jobs_notifier.dart';
import 'package:zuno/features/notifications/domain/entities/app_notification.dart';
import 'package:zuno/features/work_chat/data/models/work_message_model.dart';
import 'package:zuno/features/work_chat/domain/entities/work_thread.dart';
import 'package:zuno/features/work_chat/presentation/providers/work_chat_providers.dart';
import 'package:zuno/features/worker/domain/entities/worker_invitation.dart';
import 'package:zuno/features/worker/presentation/providers/worker_invitations_notifier.dart';
import 'package:zuno/features/worker/presentation/screens/worker_jobs_tab.dart';
import 'package:zuno/features/worker/presentation/widgets/job_details_sheet.dart';

/// Who can message and call whom. The business is the middle man:
///
///   * customer ↔ business, once the business has confirmed the order;
///   * worker ↔ business, once the worker has taken the job on;
///   * worker ↔ customer, never — the worker's card offers the business, not the customer.

// ---- fakes -------------------------------------------------------------------------------------

class _WorkThreads extends WorkThreads {
  _WorkThreads(this._rows);
  final List<WorkThread> _rows;
  @override
  Future<List<WorkThread>> build() async => _rows;
}

class _BookingThreads extends BookingThreads {
  _BookingThreads(this._rows);
  final List<BookingThread> _rows;
  @override
  Future<List<BookingThread>> build() async => _rows;
}

class _WorkerJobs extends WorkerJobsNotifier {
  _WorkerJobs(this._rows);
  final List<Booking> _rows;
  @override
  Future<List<Booking>> build() async => _rows;
}

class _Offers extends WorkerJobOffersNotifier {
  @override
  Future<List<HiringPost>> build() async => const [];
}

class _Teams extends WorkerInvitationsNotifier {
  @override
  Future<List<WorkerInvitation>> build() async => const [];
}

class _CustomerBookings extends CustomerBookingsNotifier {
  _CustomerBookings(this._rows);
  final List<Booking> _rows;
  @override
  Future<List<Booking>> build() async => _rows;
}

class _BusinessBookings extends BusinessBookingsNotifier {
  @override
  Future<List<Booking>> build() async => const [];
}

class _Posts extends BusinessHiringPostsNotifier {
  @override
  Future<List<HiringPost>> build() async => const [];
}

// ---- builders ----------------------------------------------------------------------------------

Booking _booking({
  String status = 'Confirmed',
  String? myAssignment,
  List<BookingWorkerAssignment> crew = const [],
}) => Booking(
  id: 'bk-1',
  businessOwnerProfileId: 'biz-1',
  businessName: 'Demo Painters',
  businessPhone: '9000000001',
  customerProfileId: 'c-1',
  customerName: 'Asha',
  customerPhone: '9000000002',
  businessServiceId: 's-1',
  serviceName: 'Home wall painting',
  serviceCategoryName: 'Painting',
  status: status,
  scheduledDate: DateTime.now().add(const Duration(days: 3)),
  priceQuoted: 5000,
  agreementStatus: 'NotRequired',
  myAssignmentStatus: myAssignment,
  assignedWorkers: crew,
);

HiringPost _postJob({String? businessPhone = '9000000001'}) => HiringPost(
  id: 'p-1',
  businessOwnerProfileId: 'biz-1',
  businessName: 'Demo Painters',
  businessPhone: businessPhone,
  title: 'Catering crew',
  eventDate: DateTime.now().add(const Duration(days: 5)),
  workersNeeded: 2,
  salaryAmount: 800,
  status: 'Open',
  confirmedCount: 1,
  filledCount: 1,
  createdDate: DateTime.now(),
  myApplicationStatus: 'Accepted',
);

WorkThread _thread(String name, int unread) => WorkThread(
  counterpartId: 'id-$name',
  counterpartName: name,
  lastMessage: 'Reached the gate',
  lastMessageAt: DateTime.now(),
  unreadCount: unread,
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(720, 1600); // 360dp
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

Future<void> _pumpWorker(
  WidgetTester tester, {
  List<Booking> jobs = const [],
  List<HiringPost> postJobs = const [],
  List<WorkThread> threads = const [],
}) async {
  _phone(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workerJobsProvider.overrideWith(() => _WorkerJobs(jobs)),
        workerPostJobsProvider.overrideWith((ref) async => postJobs),
        workerJobOffersProvider.overrideWith(_Offers.new),
        workerInvitationsProvider.overrideWith(_Teams.new),
        workThreadsProvider.overrideWith(() => _WorkThreads(threads)),
      ],
      child: const MaterialApp(home: Scaffold(body: WorkerJobsTab())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // ---- the rules ---------------------------------------------------------------------------------

  group('Booking.workerCanContactBusiness', () {
    test('workerCanContactBusiness_JobTakenOn_IsTrue', () {
      expect(
        _booking(myAssignment: 'Accepted').workerCanContactBusiness,
        isTrue,
      );
    });

    test('workerCanContactBusiness_JobFinished_IsTrue', () {
      expect(
        _booking(myAssignment: 'Completed').workerCanContactBusiness,
        isTrue,
      );
    });

    test('workerCanContactBusiness_NotAnsweredYet_IsFalse', () {
      expect(
        _booking(myAssignment: 'Assigned').workerCanContactBusiness,
        isFalse,
      );
    });

    test('workerCanContactBusiness_OrderCancelled_IsFalse', () {
      expect(
        _booking(
          status: 'Cancelled',
          myAssignment: 'Accepted',
        ).workerCanContactBusiness,
        isFalse,
      );
    });
  });

  test('NotificationTarget_WorkChat_OpensAConversationById', () {
    final target = NotificationTarget.fromName('WorkChat');
    expect(target, NotificationTarget.workChat);
    expect(target.needsId, isTrue);
  });

  // The field the worker's "Call business" button reads. A model change without regenerating its
  // JSON reader once left this always empty, and the button quietly never appeared.
  test('HiringPostModel_BusinessPhoneFromServer_ReachesTheJob', () {
    final post = HiringPostModel.fromJson({
      'id': 'p-1',
      'businessOwnerProfileId': 'biz-1',
      'businessName': 'Boss T',
      'businessPhone': '9100023353',
      'title': 'Catering',
      'eventDate': '2026-11-28T09:00:00Z',
      'workersNeeded': 3,
      'salaryAmount': 800,
      'confirmedCount': 1,
      'status': 'Open',
      'createdDate': '2026-10-20T09:00:00Z',
    }).toEntity();

    expect(post.businessPhone, '9100023353');
  });

  test('WorkMessageModel_FromServer_DrawsInTheSharedChat', () {
    final message = WorkMessageModel.fromJson({
      'id': 'm-1',
      'counterpartId': 'biz-1',
      'senderRole': 'Worker',
      'isMine': true,
      'senderName': 'Ravi Kumar',
      'body': 'Reached the gate',
      'sentAt': '2026-10-21T09:00:00Z',
      'readAt': null,
    }).toChatMessage();

    expect(message.isMine, isTrue);
    expect(message.body, 'Reached the gate');
    expect(message.isRead, isFalse);
  });

  // ---- worker -----------------------------------------------------------------------------------

  group('worker job card', () {
    testWidgets(
      'WorkerCard_JobTakenOn_OffersMessageAndCallBusiness_NeverTheCustomer',
      (tester) async {
        await _pumpWorker(tester, jobs: [_booking(myAssignment: 'Accepted')]);

        expect(find.byTooltip('Message business'), findsOneWidget);
        expect(find.byTooltip('Call business'), findsOneWidget);
        expect(find.byTooltip('Call customer'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('WorkerCard_NotAnsweredYet_OffersNoContact', (tester) async {
      await _pumpWorker(tester, jobs: [_booking(myAssignment: 'Assigned')]);

      expect(find.byTooltip('Message business'), findsNothing);
      expect(find.byTooltip('Call business'), findsNothing);
    });

    testWidgets('WorkerPostJob_Accepted_OffersMessageAndCallBusiness', (
      tester,
    ) async {
      await _pumpWorker(tester, postJobs: [_postJob()]);

      expect(find.byTooltip('Message business'), findsOneWidget);
      expect(find.byTooltip('Call business'), findsOneWidget);
    });

    testWidgets('WorkerPostJob_NoBusinessPhone_StillOffersMessage', (
      tester,
    ) async {
      await _pumpWorker(tester, postJobs: [_postJob(businessPhone: null)]);

      expect(find.byTooltip('Message business'), findsOneWidget);
      expect(find.byTooltip('Call business'), findsNothing);
    });

    testWidgets('WorkerTabs_MessagesTabCarriesUnreadCountAndListsBusinesses', (
      tester,
    ) async {
      await _pumpWorker(tester, threads: [_thread('Demo Painters', 2)]);

      expect(find.text('Messages (2)'), findsOneWidget);
      // Four tabs fit a 360dp phone.
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Messages (2)'));
      await tester.pumpAndSettle();
      expect(find.text('Demo Painters'), findsOneWidget);
    });
  });

  group('worker job details sheet', () {
    Future<void> openSheet(WidgetTester tester, HiringPost job) async {
      _phone(tester);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showJobDetailsSheet(context, job: job),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('JobSheet_JobTaken_OffersMessageAndCallBusiness', (
      tester,
    ) async {
      await openSheet(tester, _postJob());

      expect(find.text('Message business'), findsOneWidget);
      expect(find.text('Call business'), findsOneWidget);
      expect(find.text('You took this job'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('JobSheet_OnlyApplied_OffersNoContact', (tester) async {
      final applied = HiringPost(
        id: 'p-2',
        businessOwnerProfileId: 'biz-1',
        businessName: 'Demo Painters',
        businessPhone: '9000000001',
        title: 'Catering crew',
        eventDate: DateTime.now().add(const Duration(days: 5)),
        workersNeeded: 2,
        salaryAmount: 800,
        status: 'Open',
        confirmedCount: 0,
        createdDate: DateTime.now(),
        myApplicationStatus: 'Applied',
      );
      await openSheet(tester, applied);

      expect(find.text('Message business'), findsNothing);
      expect(find.text('Call business'), findsNothing);
      expect(find.text('You have applied'), findsOneWidget);
    });
  });

  // ---- customer ---------------------------------------------------------------------------------

  group('customer booking card', () {
    Future<void> pumpCustomer(WidgetTester tester, Booking booking) async {
      _phone(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerBookingsProvider.overrideWith(
              () => _CustomerBookings([booking]),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: CustomerBookingsTab())),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('CustomerCard_Confirmed_OffersMessageAndCallBusiness', (
      tester,
    ) async {
      await pumpCustomer(tester, _booking());

      expect(find.byTooltip('Message business'), findsOneWidget);
      expect(find.byTooltip('Call business'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CustomerCard_NotConfirmedYet_OffersNoContact', (tester) async {
      await pumpCustomer(tester, _booking(status: 'Pending'));

      expect(find.byTooltip('Message business'), findsNothing);
      expect(find.byTooltip('Call business'), findsNothing);
    });
  });

  // ---- business ---------------------------------------------------------------------------------

  group('business crew row', () {
    BookingWorkerAssignment worker(String status) => BookingWorkerAssignment(
      workerProfileId: 'w-$status',
      workerName: 'Ravi $status',
      workerPhone: '9000000003',
      status: status,
    );

    Future<void> pumpCrew(WidgetTester tester, Booking booking) async {
      _phone(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BookingCrewList(booking: booking, initiallyExpanded: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('CrewRow_WorkerTookTheJob_OffersMessageAndCallWorker', (
      tester,
    ) async {
      await pumpCrew(tester, _booking(crew: [worker('Accepted')]));

      expect(find.byTooltip('Message worker'), findsOneWidget);
      expect(find.byTooltip('Call worker'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CrewRow_WorkerNotAnsweredYet_OffersNoMessage', (tester) async {
      await pumpCrew(tester, _booking(crew: [worker('Assigned')]));

      expect(find.byTooltip('Message worker'), findsNothing);
    });

    testWidgets('CrewRow_OrderCancelled_OffersNoMessage', (tester) async {
      await pumpCrew(
        tester,
        _booking(status: 'Cancelled', crew: [worker('Accepted')]),
      );

      expect(find.byTooltip('Message worker'), findsNothing);
    });
  });

  group('business Messages tab', () {
    testWidgets(
      'BusinessMessages_CountsCustomersAndWorkers_AndSwitchesBetweenThem',
      (tester) async {
        _phone(tester);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              businessBookingsProvider.overrideWith(_BusinessBookings.new),
              businessHiringPostsProvider.overrideWith(_Posts.new),
              bookingThreadsProvider.overrideWith(
                () => _BookingThreads(const []),
              ),
              workThreadsProvider.overrideWith(
                () => _WorkThreads([_thread('Ravi Kumar', 2)]),
              ),
            ],
            child: const MaterialApp(home: Scaffold(body: BusinessOrdersTab())),
          ),
        );
        await tester.pumpAndSettle();

        // The tab's count includes worker messages.
        expect(find.bySemanticsLabel(RegExp('Messages, 2 new')), findsWidgets);

        await tester.tap(find.text('Messages'));
        await tester.pumpAndSettle();

        expect(find.text('Customers'), findsOneWidget);
        expect(find.text('Workers 2'), findsOneWidget);

        await tester.tap(find.text('Workers 2'));
        await tester.pumpAndSettle();
        expect(find.text('Ravi Kumar'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
