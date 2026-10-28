import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/catalog/data/models/app_options_model.dart';
import 'package:zuno/features/catalog/domain/entities/app_options.dart';

void main() {
  group('AppOptionsModel', () {
    test('an empty reply keeps every shipped default', () {
      final options = AppOptionsModel.fromJson(const {}).toEntity();

      expect(options.hiringPostMaxDurationMinutes, 1440);
      expect(options.maxDaysAhead, 365);
      expect(options.customerBookingMaxDaysAhead, 90);
      expect(options.vacancyMaxOpenings, 999);
      expect(options.imageUploadQuality, 85);
    });

    test('values the server sends replace the defaults', () {
      final options = AppOptionsModel.fromJson(const {
        'hiringPostMinDurationMinutes': 30,
        'hiringPostMaxDurationMinutes': 600,
        'vacancyMaxOpenings': 50,
        'serviceImageSlots': 5,
        'maxDaysAhead': 60,
      }).toEntity();

      expect(options.hiringPostMinDurationMinutes, 30);
      expect(options.hiringPostMaxDurationMinutes, 600);
      expect(options.vacancyMaxOpenings, 50);
      expect(options.serviceImageSlots, 5);
      expect(options.maxDaysAhead, 60);
      // Not sent, so still the default.
      expect(options.vacancyMaxContractMonths, 60);
    });
  });

  group('AppOptions wording', () {
    test('the media hint and refusal say the configured limits', () {
      const options = AppOptions(
        serviceImageSlots: 4,
        serviceVideoMaxSeconds: 45,
        serviceVideoMaxBytes: 10 * 1024 * 1024,
      );

      expect(
        options.serviceMediaHint,
        'Up to 4 photos and one video (45 seconds, 10MB max).',
      );
      expect(
        options.serviceVideoTooLarge,
        'Video must be 45 seconds or shorter and under 10MB.',
      );
    });

    test('the last pickable date follows the configured days', () {
      final from = DateTime(2026, 1, 1);

      expect(
        const AppOptions(maxDaysAhead: 30).lastPickableDate(from),
        DateTime(2026, 1, 31),
      );
    });
  });
}
