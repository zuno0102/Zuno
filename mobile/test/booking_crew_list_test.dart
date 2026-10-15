import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/booking/domain/entities/booking.dart';
import 'package:zuno/features/booking/domain/entities/booking_worker_assignment.dart';
import 'package:zuno/features/booking/presentation/widgets/booking_crew_list.dart';

/// Who is on the job, as the business reads it.
///
/// This exists because the business could not see its own crew at all: add three workers and the
/// screen looked exactly as it had before. The only confirmation was reopening the picker and
/// finding them greyed out.
void main() {
  BookingWorkerAssignment worker({
    required String name,
    required String displayStatus,
    String status = 'Accepted',
    String? role,
    double? salary,
    String paymentStatus = 'Unpaid',
    bool hasPayoutDetails = true,
  }) => BookingWorkerAssignment(
    workerProfileId: name,
    workerName: name,
    workerPhone: '9000000000',
    role: role,
    status: status,
    displayStatus: displayStatus,
    agreedSalaryAmount: salary,
    agreedSalaryUnit: salary == null ? null : 'PerEvent',
    paymentStatus: paymentStatus,
    hasPayoutDetails: hasPayoutDetails,
  );

  Booking order({
    required List<BookingWorkerAssignment> crew,
    int requiredWorkerCount = 5,
    String status = 'Confirmed',
    DateTime? workStartedAt,
  }) => Booking(
    id: '',
    businessOwnerProfileId: '',
    businessName: '',
    customerProfileId: '',
    customerName: '',
    businessServiceId: '',
    serviceName: '',
    serviceCategoryName: '',
    status: status,
    scheduledDate: DateTime(2026, 1, 1),
    priceQuoted: 0,
    requiredWorkerCount: requiredWorkerCount,
    assignedWorkers: crew,
    workStartedAt: workStartedAt,
  );

  Future<void> pump(WidgetTester tester, Booking booking) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          // Opened, because everything below is about what a crew ROW says. The list itself now
          // starts shut — a card in a list of orders that unfurls its crew turns a scannable
          // column of jobs into a wall — and that default has its own test at the bottom.
          body: SingleChildScrollView(
            child: BookingCrewList(booking: booking, initiallyExpanded: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists every worker with their own state', (tester) async {
    await pump(
      tester,
      order(
        crew: [
          worker(name: 'Ravi', displayStatus: 'Active', role: 'Server', salary: 800),
          worker(name: 'Anita', displayStatus: 'Awaiting', status: 'Assigned'),
          worker(name: 'Suresh', displayStatus: 'Completed', salary: 900),
        ],
      ),
    );

    expect(find.text('Ravi'), findsOneWidget);
    expect(find.text('Anita'), findsOneWidget);
    expect(find.text('Suresh'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a worker who refused is still shown', (tester) async {
    // A business that cannot see the refusal believes the job is staffed.
    await pump(
      tester,
      order(
        crew: [
          worker(name: 'Ravi', displayStatus: 'Active', salary: 800),
          worker(name: 'Anita', displayStatus: 'Declined', status: 'Rejected', salary: 800),
        ],
      ),
    );

    expect(find.text('Anita'), findsOneWidget);
  });

  testWidgets('says plainly when someone is paid outside Zuno', (tester) async {
    // "No wage" and "wage not yet entered" look identical if the line is simply left blank, and
    // only one of them is a mistake.
    await pump(tester, order(crew: [worker(name: 'Ravi', displayStatus: 'Active')]));

    expect(find.textContaining('Paid outside Zuno'), findsOneWidget);
  });

  testWidgets('warns when an owed worker has nowhere to be paid', (tester) async {
    // Worth saying before a pay run. Razorpay refuses a payout with no destination, and by then
    // the business has already authorised the money.
    await pump(
      tester,
      order(
        crew: [
          worker(
            name: 'Ravi',
            displayStatus: 'Active',
            salary: 800,
            hasPayoutDetails: false,
          ),
        ],
      ),
    );

    expect(find.text('No payout details on file'), findsOneWidget);
  });

  group('the count in the heading', () {
    testWidgets('reads "2 of 5" against a real target', (tester) async {
      await pump(
        tester,
        order(
          requiredWorkerCount: 5,
          crew: [
            worker(name: 'Ravi', displayStatus: 'Active'),
            worker(name: 'Anita', displayStatus: 'Active'),
          ],
        ),
      );

      expect(find.text('2 of 5'), findsOneWidget);
    });

    testWidgets('never reads "2 of 0" when the crew is agreed per order', (tester) async {
      // 0 means "not fixed — agreed with the customer", not "nobody needed".
      await pump(
        tester,
        order(
          requiredWorkerCount: 0,
          crew: [
            worker(name: 'Ravi', displayStatus: 'Active'),
            worker(name: 'Anita', displayStatus: 'Active'),
          ],
        ),
      );

      expect(find.text('2 assigned'), findsOneWidget);
      expect(find.text('2 of 0'), findsNothing);
    });

    testWidgets('once the work has run, the target is history', (tester) async {
      await pump(
        tester,
        order(
          requiredWorkerCount: 5,
          workStartedAt: DateTime(2026, 1, 1),
          crew: [worker(name: 'Ravi', displayStatus: 'InProgress')],
        ),
      );

      expect(find.text('1 worked this job'), findsOneWidget);
    });

    testWidgets('a refusal is not counted as being on the job', (tester) async {
      await pump(
        tester,
        order(
          requiredWorkerCount: 5,
          crew: [
            worker(name: 'Ravi', displayStatus: 'Active'),
            worker(name: 'Anita', displayStatus: 'Declined', status: 'Rejected'),
          ],
        ),
      );

      expect(find.text('1 of 5'), findsOneWidget);
    });

    testWidgets('totals what is still owed', (tester) async {
      await pump(
        tester,
        order(
          crew: [
            worker(name: 'Ravi', displayStatus: 'Active', salary: 800),
            worker(name: 'Anita', displayStatus: 'Active', salary: 900),
            // Already paid, so not part of what is outstanding.
            worker(
              name: 'Suresh',
              displayStatus: 'Completed',
              salary: 700,
              paymentStatus: 'Paid',
            ),
          ],
        ),
      );

      expect(find.text('₹1,700 owed'), findsOneWidget);
    });
  });

  testWidgets('shows nothing at all when nobody is assigned', (tester) async {
    // No empty heading left behind — the Add worker button already says what to do next.
    await pump(tester, order(crew: const []));

    expect(find.text('Crew'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('the call button', () {
    // The business needs to reach its crew while the job is on, and stops needing to once it is
    // over — except while somebody is still owed money, which is the one thing worth a call
    // after the work is done.
    testWidgets('is there while the order is running', (tester) async {
      await pump(
        tester,
        order(crew: [worker(name: 'Ravi', displayStatus: 'Active', salary: 800)]),
      );

      expect(find.byIcon(Icons.call), findsOneWidget);
    });

    testWidgets('is gone once the order is done and paid', (tester) async {
      await pump(
        tester,
        order(
          status: 'Completed',
          crew: [
            worker(
              name: 'Ravi',
              displayStatus: 'Completed',
              salary: 800,
              paymentStatus: 'Paid',
            ),
          ],
        ),
      );

      expect(find.byIcon(Icons.call), findsNothing);
    });

    testWidgets('stays while a finished order still owes them', (tester) async {
      await pump(
        tester,
        order(
          status: 'Completed',
          crew: [
            worker(
              name: 'Ravi',
              displayStatus: 'Completed',
              salary: 800,
              paymentStatus: 'Disputed',
            ),
          ],
        ),
      );

      expect(find.byIcon(Icons.call), findsOneWidget);
    });

    testWidgets('is gone for a worker paid outside Zuno', (tester) async {
      // No wage recorded, so nothing outlives the job.
      await pump(
        tester,
        order(
          status: 'Completed',
          crew: [worker(name: 'Ravi', displayStatus: 'Completed')],
        ),
      );

      expect(find.byIcon(Icons.call), findsNothing);
    });
  });

  group('whether it starts open', () {
    /// A card in a list of orders that unfurls its crew turns a scannable column of jobs into a
    /// wall of names. The count in the heading answers what most of them are opened for, and the
    /// rest is one tap away.
    testWidgets('a crew list is shut by default', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BookingCrewList(
                booking: order(
                  crew: [worker(name: 'Ravi', displayStatus: 'Active')],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The heading is there, with its count; the names are not.
      expect(find.text('Crew'), findsOneWidget);
      expect(find.text('Ravi'), findsNothing);
    });

    testWidgets('and opens when it is asked to', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BookingCrewList(
                booking: order(
                  crew: [worker(name: 'Ravi', displayStatus: 'Active')],
                ),
                initiallyExpanded: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ravi'), findsOneWidget);
    });
  });
}
