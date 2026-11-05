import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/business_owner/data/models/business_profile_model.dart';
import 'package:zuno/features/business_owner/domain/entities/business_profile.dart';
import 'package:zuno/features/business_owner/presentation/providers/business_profile_notifier.dart';
import 'package:zuno/features/business_owner/presentation/screens/business_profile_tab.dart';
import 'package:zuno/features/customer/data/models/business_detail_model.dart';
import 'package:zuno/features/customer/data/models/service_detail_model.dart';
import 'package:zuno/features/customer/data/models/service_listing_model.dart';
import 'package:zuno/features/customer/domain/entities/business_detail.dart';
import 'package:zuno/features/customer/domain/entities/business_summary.dart';
import 'package:zuno/features/customer/domain/entities/customer_service.dart';
import 'package:zuno/features/customer/domain/entities/service_detail.dart';
import 'package:zuno/features/customer/domain/entities/service_listing.dart';
import 'package:zuno/features/customer/presentation/providers/customer_providers.dart';
import 'package:zuno/features/customer/presentation/screens/business_detail_screen.dart';
import 'package:zuno/features/customer/presentation/screens/service_detail_screen.dart';
import 'package:zuno/features/customer/presentation/widgets/service_card.dart';
import 'package:zuno/shared/domain/business_trust.dart';
import 'package:zuno/shared/domain/star_rating.dart';
import 'package:zuno/shared/widgets/rating_line.dart';
import 'package:zuno/shared/widgets/trust_cards.dart';

/// Fair star ratings: one line for every star figure in the app. Under the server's minimum the
/// average is held back, and the app must say "New" — never "0.0", never a count posing as a score.
void main() {
  Future<void> pumpWidget(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: child)),
      ),
    );
  }

  group('RatingLine', () {
    testWidgets('no average reads New, with no star', (tester) async {
      await pumpWidget(tester, const RatingLine(average: null, count: 0));

      expect(find.text('New'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(find.textContaining('0.0'), findsNothing);
    });

    testWidgets('a few ratings, still too few, say how many', (tester) async {
      await pumpWidget(tester, const RatingLine(average: null, count: 2));
      expect(find.text('New · 2 ratings'), findsOneWidget);

      await pumpWidget(tester, const RatingLine(average: null, count: 1));
      expect(find.text('New · 1 rating'), findsOneWidget);
    });

    testWidgets('an average shows one decimal, the count and a star', (
      tester,
    ) async {
      await pumpWidget(tester, const RatingLine(average: 4.56, count: 12));

      expect(find.text('4.6 (12)'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    });

    testWidgets('a label goes in front', (tester) async {
      await pumpWidget(
        tester,
        const RatingLine(average: 4.5, count: 3, label: 'Rent'),
      );
      expect(find.text('Rent '), findsOneWidget);
      expect(find.text('4.5 (3)'), findsOneWidget);
    });

    test('text covers every case', () {
      expect(RatingLine.text(null, 0), 'New');
      expect(RatingLine.text(null, 2), 'New · 2 ratings');
      expect(RatingLine.text(5, 3), '5.0 (3)');
      expect(RatingLine.text(3.04, 40), '3.0 (40)');
    });
  });

  group('LineRatings', () {
    testWidgets('shows each rated line when more than one is rated', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        LineRatingsRow(
          lines: LineRatings.fromFields(
            serviceAverage: 4.5,
            serviceCount: 12,
            rentAverage: 4.8,
            rentCount: 6,
          ),
        ),
      );

      expect(find.text('Service '), findsOneWidget);
      expect(find.text('4.5 (12)'), findsOneWidget);
      expect(find.text('Rent '), findsOneWidget);
      expect(find.text('4.8 (6)'), findsOneWidget);
    });

    testWidgets('a line with too few ratings still reads New', (tester) async {
      await pumpWidget(
        tester,
        LineRatingsRow(
          lines: LineRatings.fromFields(
            serviceAverage: 4.5,
            serviceCount: 12,
            rentCount: 2,
          ),
        ),
      );
      expect(find.text('New · 2 ratings'), findsOneWidget);
    });

    testWidgets('one rated line shows nothing — the overall says it', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        LineRatingsRow(
          lines: LineRatings.fromFields(serviceAverage: 4.5, serviceCount: 12),
        ),
      );
      expect(find.text('Service '), findsNothing);
      expect(find.text('Rent '), findsNothing);
    });

    test('only lines with ratings count', () {
      expect(const LineRatings().isSplit, isFalse);
      expect(LineRatings.fromFields(serviceCount: 1, rentCount: 0).rated.keys, [
        'Service',
      ]);
      expect(
        LineRatings.fromFields(serviceCount: 1, rentCount: 1).isSplit,
        isTrue,
      );
    });
  });

  group('Service card', () {
    ServiceListing listing({
      StarRating serviceRating = const StarRating(),
    }) => ServiceListing(
      id: 's-1',
      name: 'Painting',
      serviceCategoryName: 'Home improvement',
      serviceCategoryId: 'c-1',
      price: 1200,
      priceType: 'Fixed',
      businessOwnerProfileId: 'b-1',
      businessName: 'Kerala Painters',
      // The business overall; the card is the service and shows the service's own.
      ratingAverage: 4.9,
      reviewCount: 80,
      serviceRating: serviceRating,
    );

    testWidgets('shows the service own stars', (tester) async {
      await pumpWidget(
        tester,
        SizedBox(
          width: 220,
          child: ServiceCard(
            service: listing(
              serviceRating: const StarRating(average: 4.2, count: 5),
            ),
            onTap: () {},
          ),
        ),
      );
      expect(find.text('4.2 (5)'), findsOneWidget);
      expect(find.text('4.9 (80)'), findsNothing);
    });

    testWidgets('a service too new to rate says New', (tester) async {
      await pumpWidget(
        tester,
        SizedBox(
          width: 220,
          child: ServiceCard(service: listing(), onTap: () {}),
        ),
      );
      expect(find.text('New'), findsOneWidget);
    });
  });

  group('Trust card', () {
    testWidgets('reviews go through the same rating line', (tester) async {
      await pumpWidget(
        tester,
        const SizedBox(
          width: 360,
          child: CustomerTrustCard(
            trust: CustomerFacingTrust(ratingAverage: 4.56, reviewCount: 12),
          ),
        ),
      );
      expect(find.text('4.6 (12)'), findsOneWidget);
    });

    testWidgets('no reviews yet reads New', (tester) async {
      await pumpWidget(
        tester,
        const SizedBox(
          width: 360,
          child: CustomerTrustCard(trust: CustomerFacingTrust()),
        ),
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('trust-rating')),
          matching: find.text('New'),
        ),
        findsOneWidget,
      );
    });
  });

  group('Service detail', () {
    ServiceDetail detail({
      StarRating serviceRating = const StarRating(),
      double? businessAverage,
      int businessCount = 0,
      LineRatings lines = const LineRatings(),
    }) => ServiceDetail(
      service: CustomerService(
        id: 's-1',
        serviceCategoryName: 'Home improvement',
        name: 'Painting',
        priceType: 'Fixed',
        price: 12000,
        rating: serviceRating,
      ),
      business: BusinessSummary(
        id: 'bo-1',
        businessName: 'Kerala Painters',
        serviceCategoryNames: const ['Home improvement'],
        ratingAverage: businessAverage,
        reviewCount: businessCount,
        lineRatings: lines,
      ),
    );

    Future<void> pump(WidgetTester tester, ServiceDetail data) async {
      tester.view.physicalSize = const Size(900, 2800);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            serviceDetailProvider('s-1').overrideWith((ref) async => data),
          ],
          child: const MaterialApp(home: ServiceDetailScreen(serviceId: 's-1')),
        ),
      );
      await tester.pumpAndSettle();
    }

    Finder within(String key, String text) => find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.text(text),
    );

    testWidgets('the service stars and the business overall both show', (
      tester,
    ) async {
      await pump(
        tester,
        detail(
          serviceRating: const StarRating(average: 4.2, count: 5),
          businessAverage: 4.7,
          businessCount: 18,
        ),
      );

      expect(within('service-rating', '4.2 (5)'), findsOneWidget);
      expect(within('business-rating', '4.7 (18)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a new service and business say New, not 0.0', (tester) async {
      await pump(tester, detail());

      expect(within('service-rating', 'New'), findsOneWidget);
      expect(within('business-rating', 'New'), findsOneWidget);
      expect(find.textContaining('0.0'), findsNothing);
    });

    testWidgets('both lines rated: the per-line breakdown shows', (
      tester,
    ) async {
      await pump(
        tester,
        detail(
          businessAverage: 4.6,
          businessCount: 18,
          lines: LineRatings.fromFields(
            serviceAverage: 4.5,
            serviceCount: 12,
            rentAverage: 4.8,
            rentCount: 6,
          ),
        ),
      );

      expect(within('line-rating-Service', '4.5 (12)'), findsOneWidget);
      expect(within('line-rating-Rent', '4.8 (6)'), findsOneWidget);
    });

    testWidgets('one line rated: no breakdown', (tester) async {
      await pump(
        tester,
        detail(
          businessAverage: 4.5,
          businessCount: 12,
          lines: LineRatings.fromFields(serviceAverage: 4.5, serviceCount: 12),
        ),
      );

      expect(find.byKey(const ValueKey('business-line-ratings')), findsNothing);
      expect(find.byKey(const ValueKey('line-rating-Service')), findsNothing);
    });
  });

  group('Business detail', () {
    testWidgets('overall, per line, and each service its own', (tester) async {
      tester.view.physicalSize = const Size(900, 2000);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final business = BusinessDetail(
        id: 'bo-1',
        businessName: 'Kerala Painters',
        rating: const StarRating(average: 4.6, count: 18),
        lineRatings: LineRatings.fromFields(
          serviceAverage: 4.5,
          serviceCount: 12,
          rentAverage: 4.8,
          rentCount: 6,
        ),
        services: const [
          CustomerService(
            id: 's-1',
            serviceCategoryName: 'Home improvement',
            name: 'Painting',
            priceType: 'Fixed',
            price: 1200,
            rating: StarRating(average: 4.3, count: 9),
          ),
          CustomerService(
            id: 's-2',
            serviceCategoryName: 'Home improvement',
            name: 'Plumbing',
            priceType: 'Fixed',
            price: 800,
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessDetailProvider(
              'bo-1',
            ).overrideWith((ref) async => business),
          ],
          child: const MaterialApp(
            home: BusinessDetailScreen(businessId: 'bo-1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Finder within(String key, String text) => find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.text(text),
      );
      expect(within('business-rating', '4.6 (18)'), findsOneWidget);
      expect(within('line-rating-Service', '4.5 (12)'), findsOneWidget);
      expect(within('line-rating-Rent', '4.8 (6)'), findsOneWidget);
      expect(within('service-rating-s-1', '4.3 (9)'), findsOneWidget);
      expect(within('service-rating-s-2', 'New'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Owner profile header', () {
    Future<void> pumpProfile(WidgetTester tester, BusinessProfile p) async {
      tester.view.physicalSize = const Size(1080, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [businessProfileProvider.overrideWith(() => _Profile(p))],
          child: const MaterialApp(home: BusinessProfileScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('keeps the level and adds successful jobs and each line', (
      tester,
    ) async {
      await pumpProfile(
        tester,
        BusinessProfile(
          id: 'b1',
          businessName: 'Joy Events',
          verificationStatus: 'Verified',
          upiId: 'joy@okaxis',
          successfulJobs: 12,
          lineRatings: LineRatings.fromFields(
            serviceAverage: 4.5,
            serviceCount: 12,
            rentAverage: 4.8,
            rentCount: 6,
          ),
        ),
      );

      expect(find.text('New · Level 1'), findsOneWidget);
      expect(find.text('12 successful jobs'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('profile-line-ratings')),
          matching: find.text('4.8 (6)'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('one line rated: no per-line breakdown', (tester) async {
      await pumpProfile(
        tester,
        const BusinessProfile(
          id: 'b1',
          businessName: 'Joy Events',
          verificationStatus: 'Verified',
          upiId: 'joy@okaxis',
        ),
      );

      expect(find.text('0 successful jobs'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-line-ratings')), findsNothing);
    });
  });

  group('Server JSON', () {
    Map<String, dynamic> service([Map<String, dynamic> extra = const {}]) => {
      'id': 's-1',
      'serviceCategoryName': 'Home improvement',
      'name': 'Painting',
      'priceType': 'Fixed',
      'price': 1200,
      ...extra,
    };
    Map<String, dynamic> business([Map<String, dynamic> extra = const {}]) => {
      'id': 'bo-1',
      'businessName': 'Kerala Painters',
      'serviceCategoryNames': ['Home improvement'],
      ...extra,
    };

    test('service detail reads the service and per-line stars', () {
      final detail = ServiceDetailModel.fromJson({
        'service': service({'ratingAverage': 4.25, 'ratingCount': 8}),
        'business': business({
          'ratingAverage': 4.6,
          'reviewCount': 18,
          'serviceRatingAverage': 4.5,
          'serviceRatingCount': 12,
          'rentRatingAverage': null,
          'rentRatingCount': 2,
        }),
      }).toEntity();

      expect(detail.service.rating.average, 4.25);
      expect(detail.service.rating.count, 8);
      expect(detail.business.ratingAverage, 4.6);
      expect(detail.business.lineRatings.service.average, 4.5);
      expect(detail.business.lineRatings.service.count, 12);
      expect(detail.business.lineRatings.rent.average, isNull);
      expect(detail.business.lineRatings.rent.count, 2);
    });

    test('older JSON without the new fields reads as new', () {
      final detail = ServiceDetailModel.fromJson({
        'service': service(),
        'business': business(),
      }).toEntity();

      expect(detail.service.rating.average, isNull);
      expect(detail.service.rating.count, 0);
      expect(detail.business.lineRatings.isSplit, isFalse);
      expect(detail.business.lineRatings.rent.count, 0);
    });

    test('a listing keeps the business overall and the service own apart', () {
      Map<String, dynamic> listing([Map<String, dynamic> extra = const {}]) => {
        'id': 's-1',
        'name': 'Painting',
        'serviceCategoryName': 'Home improvement',
        'serviceCategoryId': 'c-1',
        'price': 1200,
        'priceType': 'Fixed',
        'businessOwnerProfileId': 'bo-1',
        'businessName': 'Kerala Painters',
        ...extra,
      };
      final card = ServiceListingModel.fromJson(
        listing({
          'ratingAverage': 4.9,
          'reviewCount': 80,
          'serviceRatingAverage': 4.2,
          'serviceRatingCount': 5,
        }),
      ).toEntity();
      expect(card.ratingAverage, 4.9);
      expect(card.serviceRating.average, 4.2);
      expect(card.serviceRating.count, 5);

      final old = ServiceListingModel.fromJson(listing()).toEntity();
      expect(old.serviceRating.average, isNull);
      expect(old.serviceRating.count, 0);
    });

    test('business detail reads its overall and per-line stars', () {
      final detail = BusinessDetailModel.fromJson({
        'id': 'bo-1',
        'businessName': 'Kerala Painters',
        'services': [service()],
        'ratingAverage': 4.6,
        'reviewCount': 18,
        'serviceRatingAverage': 4.5,
        'serviceRatingCount': 12,
        'rentRatingAverage': 4.8,
        'rentRatingCount': 6,
      }).toEntity();
      expect(detail.rating.average, 4.6);
      expect(detail.rating.count, 18);
      expect(detail.lineRatings.isSplit, isTrue);

      final old = BusinessDetailModel.fromJson({
        'id': 'bo-1',
        'businessName': 'Kerala Painters',
        'services': <Map<String, dynamic>>[],
      }).toEntity();
      expect(old.rating.average, isNull);
      expect(old.rating.count, 0);
      expect(old.lineRatings.isSplit, isFalse);
    });

    test('the owner profile reads successful jobs and per-line stars', () {
      Map<String, dynamic> profile([Map<String, dynamic> extra = const {}]) => {
        'id': 'bo-1',
        'businessName': 'Kerala Painters',
        'verificationStatus': 'Verified',
        ...extra,
      };
      final mine = BusinessProfileModel.fromJson(
        profile({
          'level': 2,
          'levelName': 'Trusted',
          'successfulJobs': 12,
          'serviceRatingAverage': 4.5,
          'serviceRatingCount': 10,
          'rentRatingAverage': 4.8,
          'rentRatingCount': 4,
        }),
      ).toEntity();
      expect(mine.successfulJobs, 12);
      expect(mine.successfulJobsLabel, '12 successful jobs');
      expect(mine.lineRatings.service.average, 4.5);
      expect(mine.lineRatings.rent.count, 4);

      final old = BusinessProfileModel.fromJson(profile()).toEntity();
      expect(old.successfulJobs, 0);
      expect(old.successfulJobsLabel, '0 successful jobs');
      expect(old.lineRatings.isSplit, isFalse);
    });

    test('one successful job is singular', () {
      final one = BusinessProfileModel.fromJson({
        'id': 'bo-1',
        'businessName': 'Kerala Painters',
        'verificationStatus': 'Verified',
        'successfulJobs': 1,
      }).toEntity();
      expect(one.successfulJobsLabel, '1 successful job');
    });
  });
}

class _Profile extends BusinessProfileNotifier {
  _Profile(this._profile);

  final BusinessProfile _profile;

  @override
  Future<BusinessProfile> build() async => _profile;
}
