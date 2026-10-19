import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/customer/domain/entities/business_summary.dart';
import 'package:zuno/features/customer/domain/entities/customer_service.dart';
import 'package:zuno/features/customer/domain/entities/service_detail.dart';
import 'package:zuno/features/customer/domain/entities/service_district.dart';
import 'package:zuno/features/customer/domain/entities/service_variant.dart';
import 'package:zuno/features/customer/presentation/providers/customer_providers.dart';
import 'package:zuno/features/customer/presentation/screens/service_detail_screen.dart';
import 'package:zuno/features/customer/presentation/screens/service_variant_detail_screen.dart';

/// The customer's view of one service — painting, say — and the kinds of work listed under it.
///
/// Three things were wrong with it. The smaller services offered a **Book** button and nothing else,
/// so a customer was asked to commit to something they were never allowed to read, even though the
/// business had filled in a description, a price, a duration and pictures for each. They sat under
/// the heading **Packages**, which is the business's word for them, not the customer's. And the page
/// printed the districts the business covers — a filter that has already run before this page can
/// open, so it reads as a restriction rather than information.
void main() {
  ServiceVariant variant({
    String id = 'v-1',
    String name = 'Interior wall painting',
    String? subCategory = 'Interior painting',
    String? description = 'Two coats, walls and ceiling, paint included.',
    double price = 4500,
    int? minutes = 480,
  }) => ServiceVariant(
    id: id,
    name: name,
    serviceSubCategoryName: subCategory,
    description: description,
    priceType: 'Fixed',
    price: price,
    estimatedDurationMinutes: minutes,
  );

  ServiceDetail detail({
    List<ServiceVariant> variants = const [],
    double price = 12000,
  }) =>
      ServiceDetail(
        service: CustomerService(
          id: 's-1',
          serviceCategoryName: 'Home improvement',
          name: 'Painting',
          description: 'Painting for homes and offices.',
          priceType: 'Fixed',
          price: price,
          variants: variants,
          // Set on every real service, and the page must not put them on screen.
          targetDistricts: const [
            ServiceDistrict(
              id: 'd-1',
              name: 'Thiruvananthapuram',
              stateId: 'st-1',
              stateName: 'Kerala',
            ),
            ServiceDistrict(
              id: 'd-2',
              name: 'Kollam',
              stateId: 'st-1',
              stateName: 'Kerala',
            ),
          ],
        ),
        business: const BusinessSummary(
          id: 'bo-1',
          businessName: 'Kerala Painters',
          serviceCategoryNames: ['Home improvement'],
          city: 'Thiruvananthapuram',
          state: 'Kerala',
        ),
      );

  Future<void> pump(
    WidgetTester tester,
    ServiceDetail data, {
    bool showRelatedServices = true,
  }) async {
    // Taller than a real phone on purpose: the gallery is sized from the viewport now, so a short
    // surface pushes the related services under the pinned bar and nothing below it can be tapped.
    tester.view.physicalSize = const Size(900, 2800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serviceDetailProvider('s-1').overrideWith((ref) async => data),
        ],
        child: MaterialApp(
          home: ServiceDetailScreen(
            serviceId: 's-1',
            showRelatedServices: showRelatedServices,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('the service itself', () {
    testWidgets('leads with what it is and what it costs', (tester) async {
      await pump(tester, detail());

      expect(tester.takeException(), isNull);
      expect(find.text('Painting'), findsWidgets);
      expect(find.text('Painting for homes and offices.'), findsOneWidget);
    });

    testWidgets('never prints the districts the business covers', (tester) async {
      // Background matching, not information for the reader: this page cannot be reached unless the
      // filter has already passed, so stating it only ever reads as a restriction.
      await pump(tester, detail());

      expect(find.textContaining('Serves'), findsNothing);
      expect(find.textContaining('Thiruvananthapuram · Kollam'), findsNothing);
    });
  });

  group('the services listed inside it', () {
    testWidgets('are called related services, not packages', (tester) async {
      await pump(tester, detail(variants: [variant()]));

      expect(find.text('Related services'), findsOneWidget);
      expect(find.text('Packages'), findsNothing);
    });

    testWidgets('offer a way in as well as a way to book', (tester) async {
      await pump(tester, detail(variants: [variant()]));

      expect(find.text('Book'), findsOneWidget);
      expect(
        find.text('View details'),
        findsOneWidget,
        reason: 'Book alone gave a customer nothing to read before committing',
      );
    });

    testWidgets('open on their own page when tapped', (tester) async {
      await pump(tester, detail(variants: [variant()]));

      await tester.tap(find.text('Interior wall painting'));
      await tester.pumpAndSettle();

      expect(find.byType(ServiceVariantDetailScreen), findsOneWidget);
    });

    testWidgets('and that page carries the detail the card could not', (
      tester,
    ) async {
      await pump(tester, detail(variants: [variant()]));

      await tester.tap(find.text('Interior wall painting'));
      await tester.pumpAndSettle();

      // The full description rather than the two clipped lines on the card.
      expect(
        find.text('Two coats, walls and ceiling, paint included.'),
        findsOneWidget,
      );
      expect(find.text('INTERIOR PAINTING'), findsOneWidget);
      // Which service it belongs to, so somebody two taps deep still knows where they are.
      expect(
        find.text('Part of Painting · Kerala Painters'),
        findsOneWidget,
      );
      expect(find.text('Book Interior wall painting'), findsOneWidget);
    });

    testWidgets('several of them all open their own page', (tester) async {
      await pump(
        tester,
        detail(
          variants: [
            variant(),
            variant(
              id: 'v-2',
              name: 'Exterior painting',
              subCategory: 'Exterior painting',
              price: 9000,
            ),
          ],
        ),
      );

      expect(find.text('Related services'), findsOneWidget);
      expect(find.text('View details'), findsNWidgets(2));

      await tester.tap(find.text('Exterior painting').first);
      await tester.pumpAndSettle();

      expect(find.text('Book Exterior painting'), findsOneWidget);
    });
  });

  group('a service sold on its own', () {
    testWidgets('keeps its single booking button and grows no sections', (
      tester,
    ) async {
      await pump(tester, detail());

      expect(find.text('Book this service'), findsOneWidget);
      expect(find.text('Related services'), findsNothing);
    });
  });

  group('opened from the home banner', () {
    testWidgets('lists no alternatives under it', (tester) async {
      // A banner advertises one service. Following it into a list of other things reads as a change
      // of subject rather than help.
      await pump(
        tester,
        detail(variants: [variant()]),
        showRelatedServices: false,
      );

      expect(find.text('Related services'), findsNothing);
      expect(find.text('Interior wall painting'), findsNothing);
    });

    testWidgets('but still shows the service and books it', (tester) async {
      await pump(
        tester,
        detail(variants: [variant()]),
        showRelatedServices: false,
      );

      expect(find.text('Painting for homes and offices.'), findsOneWidget);
      expect(find.text('Book Painting'), findsOneWidget);
    });

    testWidgets('and keeps them when they are the only way to book', (
      tester,
    ) async {
      // A service priced at nothing is sold only through what is listed under it. Hiding that list
      // here would leave a page with no way to book anything at all.
      await pump(
        tester,
        detail(variants: [variant()], price: 0),
        showRelatedServices: false,
      );

      expect(find.text('Related services'), findsOneWidget);
      expect(find.text('Book'), findsOneWidget);
    });
  });

  group('booking the service itself', () {
    testWidgets('is offered even when smaller services are listed under it', (
      tester,
    ) async {
      // It used to vanish the moment anything was listed inside, leaving a customer who wanted the
      // whole job with nothing to press. The server never required a sub-service.
      await pump(tester, detail(variants: [variant()]));

      expect(find.text('Book Painting'), findsOneWidget);
    });

    testWidgets('carries the service name, and no price', (tester) async {
      // The name is what separates booking the whole service from booking one of the things listed
      // under it. The price stays on the page rather than on the button.
      await pump(tester, detail(variants: [variant()]));

      expect(find.text('Book Painting'), findsOneWidget);
      expect(find.textContaining('From ₹4,500'), findsOneWidget);
      expect(find.text('₹12,000'), findsNothing);
    });

    testWidgets('opens the booking form for the service, with no sub-service', (
      tester,
    ) async {
      await pump(tester, detail(variants: [variant()]));

      await tester.tap(find.text('Book Painting'));
      await tester.pumpAndSettle();

      // The form names the service, not one of the things listed under it.
      expect(find.text('Painting'), findsWidgets);
      expect(find.text('Interior wall painting'), findsNothing);
    });

    testWidgets('is withheld when the service costs nothing on its own', (
      tester,
    ) async {
      // A business that sells only through the items beneath it leaves the parent at zero. Ordering
      // that would place an order for ₹0, so the items are the only thing offered.
      await pump(tester, detail(variants: [variant()], price: 0));

      expect(find.textContaining('Book Painting'), findsNothing);
      expect(find.text('Book this service'), findsNothing);
      expect(find.text('Book'), findsOneWidget, reason: 'the listed service still books');
    });
  });
}
