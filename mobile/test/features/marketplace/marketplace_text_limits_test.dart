import 'package:flutter_test/flutter_test.dart';
import 'package:zuno/features/marketplace/data/models/marketplace_models.dart';
import 'package:zuno/features/marketplace/domain/entities/marketplace_post.dart';

void main() {
  test('the limits come from the server', () {
    final limits = marketplaceTextLimitsFromJson({
      'title': 80,
      'colour': 25,
      'contactPhoneMinDigits': 8,
      'contactPhoneMaxDigits': 12,
    });

    expect((limits.title, limits.colour), (80, 25));
    expect(limits.isContactPhone('12345678'), isTrue);
    expect(limits.isContactPhone('1234567'), isFalse);
    expect(limits.isContactPhone('+123456789012'), isTrue);
    expect(limits.isContactPhone('1234567890123'), isFalse);
  });

  test('a limit the server leaves out keeps the form own', () {
    final limits = marketplaceTextLimitsFromJson(const {});

    expect(limits.description, const MarketplaceTextLimits().description);
    expect(limits.isContactPhone('98765 43210'), isFalse);
    expect(limits.isContactPhone('+919876543210'), isTrue);
  });

  test('the options carry them', () {
    final options = MarketplaceOptionsModel.fromJson({
      'kinds': <Object>[],
      'statuses': <Object>[],
      'imageSlots': 5,
      'maxFoodOfferHours': 24,
      'maxAdDays': 30,
      'maxStartDaysAhead': 45,
      'textLimits': {'title': 90},
    }).toEntity();

    expect(options.maxStartDaysAhead, 45);
    expect(options.textLimits.title, 90);
  });
}
